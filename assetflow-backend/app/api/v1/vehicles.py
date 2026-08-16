import uuid
from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import require_permission
from app.models.identity import User
from app.models.business import BusinessUnit, Vehicle, BusinessCategory
from app.models.financial import MaintenanceRecord
from app.schemas.vehicle import (
    VehicleCreate,
    VehicleUpdate,
    VehicleOut,
    VehicleProfitability,
    MaintenanceRecordCreate,
    MaintenanceRecordOut,
)
from app.services.audit_service import log_action
from app.services.financial_calculator import total_revenue, total_expense, net_profit

router = APIRouter(prefix="/vehicles", tags=["vehicles"])


def _to_out(unit: BusinessUnit, vehicle: Vehicle) -> VehicleOut:
    return VehicleOut(
        id=vehicle.id,
        business_unit_id=unit.id,
        name=unit.name,
        plate_number=vehicle.plate_number,
        vehicle_type=vehicle.vehicle_type,
        manufacturer=vehicle.manufacturer,
        model=vehicle.model,
        year=vehicle.year,
        driver_name=vehicle.driver_name,
        mileage=float(vehicle.mileage or 0),
        operating_hours=float(vehicle.operating_hours) if vehicle.operating_hours is not None else None,
        status=vehicle.status,
        insurance_expiry=vehicle.insurance_expiry,
        registration_expiry=vehicle.registration_expiry,
        purchase_price=float(vehicle.purchase_price) if vehicle.purchase_price is not None else None,
        current_value=float(vehicle.current_value) if vehicle.current_value is not None else None,
    )


@router.get("", response_model=list[VehicleOut])
def list_vehicles(
    status: str | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("vehicles", "read")),
):
    stmt = select(Vehicle, BusinessUnit).join(BusinessUnit, BusinessUnit.id == Vehicle.business_unit_id).where(
        BusinessUnit.deleted_at.is_(None)
    )
    if status:
        stmt = stmt.where(Vehicle.status == status)
    rows = db.execute(stmt).all()
    return [_to_out(unit, vehicle) for vehicle, unit in rows]


@router.post("", response_model=VehicleOut, status_code=201)
def create_vehicle(
    payload: VehicleCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("vehicles", "create")),
):
    category = db.execute(select(BusinessCategory).where(BusinessCategory.code == "VEHICLES")).scalar_one_or_none()
    if category is None:
        raise HTTPException(status_code=500, detail="VEHICLES business category not seeded")

    unit = BusinessUnit(category_id=category.id, unit_type="vehicle", name=payload.name)
    db.add(unit)
    db.flush()

    vehicle = Vehicle(
        business_unit_id=unit.id,
        plate_number=payload.plate_number,
        vehicle_type=payload.vehicle_type,
        manufacturer=payload.manufacturer,
        model=payload.model,
        year=payload.year,
        purchase_date=payload.purchase_date,
        purchase_price=payload.purchase_price,
        current_value=payload.current_value,
        driver_name=payload.driver_name,
        mileage=payload.mileage,
        operating_hours=payload.operating_hours,
        status=payload.status,
        insurance_expiry=payload.insurance_expiry,
        registration_expiry=payload.registration_expiry,
    )
    db.add(vehicle)
    db.flush()

    log_action(db, user_id=current_user.id, entity_type="vehicle", entity_id=vehicle.id, action="create",
               new_value={"name": payload.name})
    db.commit()
    db.refresh(vehicle)
    return _to_out(unit, vehicle)


@router.get("/{vehicle_id}", response_model=VehicleOut)
def get_vehicle(
    vehicle_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("vehicles", "read")),
):
    vehicle = db.get(Vehicle, vehicle_id)
    if vehicle is None:
        raise HTTPException(status_code=404, detail="Vehicle not found")
    unit = db.get(BusinessUnit, vehicle.business_unit_id)
    return _to_out(unit, vehicle)


@router.patch("/{vehicle_id}", response_model=VehicleOut)
def update_vehicle(
    vehicle_id: uuid.UUID,
    payload: VehicleUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("vehicles", "update")),
):
    vehicle = db.get(Vehicle, vehicle_id)
    if vehicle is None:
        raise HTTPException(status_code=404, detail="Vehicle not found")

    previous = {"status": vehicle.status, "mileage": str(vehicle.mileage), "driver_name": vehicle.driver_name}
    updates = payload.model_dump(exclude_unset=True)
    for field, value in updates.items():
        setattr(vehicle, field, value)

    log_action(db, user_id=current_user.id, entity_type="vehicle", entity_id=vehicle.id, action="update",
               previous_value=previous, new_value=updates)
    db.commit()
    db.refresh(vehicle)
    unit = db.get(BusinessUnit, vehicle.business_unit_id)
    return _to_out(unit, vehicle)


@router.get("/{vehicle_id}/profitability", response_model=VehicleProfitability)
def vehicle_profitability(
    vehicle_id: uuid.UUID,
    date_from: date | None = None,
    date_to: date | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("vehicles", "read")),
):
    """
    Vehicle Profit = Vehicle Revenue - Vehicle Expenses (Section 4/8).
    Cost/Profit per km and cost per operating hour are computed from the
    vehicle's current cumulative mileage/operating_hours, since the schema
    doesn't track per-period mileage deltas -- for period-scoped rates,
    add a mileage log table in a future iteration.
    """
    vehicle = db.get(Vehicle, vehicle_id)
    if vehicle is None:
        raise HTTPException(status_code=404, detail="Vehicle not found")
    unit = db.get(BusinessUnit, vehicle.business_unit_id)

    revenue = total_revenue(db, business_unit_id=unit.id, date_from=date_from, date_to=date_to)
    expense = total_expense(db, business_unit_id=unit.id, date_from=date_from, date_to=date_to)
    profit = revenue - expense
    mileage = float(vehicle.mileage or 0)

    return VehicleProfitability(
        vehicle_id=vehicle.id,
        name=unit.name,
        period_from=date_from,
        period_to=date_to,
        revenue=revenue,
        expenses=expense,
        profit=profit,
        mileage=mileage,
        cost_per_km=(expense / mileage) if mileage else None,
        profit_per_km=(profit / mileage) if mileage else None,
        cost_per_operating_hour=(expense / float(vehicle.operating_hours)) if vehicle.operating_hours else None,
    )


@router.post("/{vehicle_id}/maintenance", response_model=MaintenanceRecordOut, status_code=201)
def add_maintenance_record(
    vehicle_id: uuid.UUID,
    payload: MaintenanceRecordCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("vehicles", "update")),
):
    vehicle = db.get(Vehicle, vehicle_id)
    if vehicle is None:
        raise HTTPException(status_code=404, detail="Vehicle not found")

    record = MaintenanceRecord(
        business_unit_id=vehicle.business_unit_id,
        description=payload.description,
        cost=payload.cost,
        performed_at=payload.performed_at,
        next_due=payload.next_due,
    )
    db.add(record)
    db.flush()
    log_action(db, user_id=current_user.id, entity_type="maintenance_record", entity_id=record.id, action="create",
               new_value={"cost": str(payload.cost)})
    db.commit()
    db.refresh(record)
    return record


@router.get("/{vehicle_id}/maintenance", response_model=list[MaintenanceRecordOut])
def list_maintenance_records(
    vehicle_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("vehicles", "read")),
):
    vehicle = db.get(Vehicle, vehicle_id)
    if vehicle is None:
        raise HTTPException(status_code=404, detail="Vehicle not found")
    stmt = select(MaintenanceRecord).where(MaintenanceRecord.business_unit_id == vehicle.business_unit_id).order_by(
        MaintenanceRecord.performed_at.desc()
    )
    return db.execute(stmt).scalars().all()
