import uuid
from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import require_permission
from app.models.identity import User
from app.models.business import BusinessUnit, Property, Tenant, BusinessCategory
from app.models.financial import RentalTransaction
from app.schemas.property import (
    PropertyCreate,
    PropertyUpdate,
    PropertyOut,
    TenantCreate,
    TenantOut,
    RentCollectionCreate,
    RentalTransactionOut,
    PropertyDashboard,
)
from app.services.audit_service import log_action
from app.services.financial_calculator import total_expense, outstanding_rent

router = APIRouter(prefix="/properties", tags=["properties"])


def _to_out(unit: BusinessUnit, prop: Property) -> PropertyOut:
    return PropertyOut(
        id=prop.id,
        business_unit_id=unit.id,
        name=unit.name,
        address=prop.address,
        property_type=prop.property_type,
        rooms=prop.rooms,
        monthly_rent=float(prop.monthly_rent),
        security_deposit=float(prop.security_deposit) if prop.security_deposit is not None else None,
        payment_frequency=prop.payment_frequency,
        status=prop.status,
    )


@router.get("", response_model=list[PropertyOut])
def list_properties(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("properties", "read")),
):
    rows = db.execute(
        select(Property, BusinessUnit).join(BusinessUnit, BusinessUnit.id == Property.business_unit_id)
    ).all()
    return [_to_out(unit, prop) for prop, unit in rows]


@router.post("", response_model=PropertyOut, status_code=201)
def create_property(
    payload: PropertyCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("properties", "create")),
):
    category = db.execute(select(BusinessCategory).where(BusinessCategory.code == "RENTAL_HOUSES")).scalar_one_or_none()
    if category is None:
        raise HTTPException(status_code=500, detail="RENTAL_HOUSES business category not seeded")

    unit = BusinessUnit(category_id=category.id, unit_type="property", name=payload.name)
    db.add(unit)
    db.flush()

    prop = Property(
        business_unit_id=unit.id,
        address=payload.address,
        property_type=payload.property_type,
        rooms=payload.rooms,
        monthly_rent=payload.monthly_rent,
        security_deposit=payload.security_deposit,
        payment_frequency=payload.payment_frequency,
    )
    db.add(prop)
    db.flush()

    log_action(db, user_id=current_user.id, entity_type="property", entity_id=prop.id, action="create",
               new_value={"name": payload.name, "monthly_rent": str(payload.monthly_rent)})
    db.commit()
    db.refresh(prop)
    return _to_out(unit, prop)


@router.get("/{property_id}", response_model=PropertyOut)
def get_property(
    property_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("properties", "read")),
):
    prop = db.get(Property, property_id)
    if prop is None:
        raise HTTPException(status_code=404, detail="Property not found")
    unit = db.get(BusinessUnit, prop.business_unit_id)
    return _to_out(unit, prop)


@router.patch("/{property_id}", response_model=PropertyOut)
def update_property(
    property_id: uuid.UUID,
    payload: PropertyUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("properties", "update")),
):
    prop = db.get(Property, property_id)
    if prop is None:
        raise HTTPException(status_code=404, detail="Property not found")

    previous = {"status": prop.status, "monthly_rent": str(prop.monthly_rent)}
    updates = payload.model_dump(exclude_unset=True)
    for field, value in updates.items():
        setattr(prop, field, value)

    log_action(db, user_id=current_user.id, entity_type="property", entity_id=prop.id, action="update",
               previous_value=previous, new_value={k: str(v) for k, v in updates.items()})
    db.commit()
    db.refresh(prop)
    unit = db.get(BusinessUnit, prop.business_unit_id)
    return _to_out(unit, prop)


@router.post("/{property_id}/tenants", response_model=TenantOut, status_code=201)
def add_tenant(
    property_id: uuid.UUID,
    payload: TenantCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("properties", "update")),
):
    prop = db.get(Property, property_id)
    if prop is None:
        raise HTTPException(status_code=404, detail="Property not found")

    tenant = Tenant(
        property_id=property_id,
        name=payload.name,
        phone=payload.phone,
        contract_start=payload.contract_start,
        contract_end=payload.contract_end,
    )
    db.add(tenant)
    prop.status = "occupied"
    db.flush()

    log_action(db, user_id=current_user.id, entity_type="tenant", entity_id=tenant.id, action="create",
               new_value={"name": payload.name, "property_id": str(property_id)})
    db.commit()
    db.refresh(tenant)
    return tenant


@router.get("/{property_id}/tenants", response_model=list[TenantOut])
def list_tenants(
    property_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("properties", "read")),
):
    stmt = select(Tenant).where(Tenant.property_id == property_id).order_by(Tenant.contract_start.desc())
    return db.execute(stmt).scalars().all()


@router.post("/{property_id}/rent", response_model=RentalTransactionOut, status_code=201)
def collect_rent(
    property_id: uuid.UUID,
    payload: RentCollectionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("properties", "update")),
):
    """
    Records a rent payment for a billing period. Supports full, partial, and
    advance payment (amount_paid > amount_due). The underlying revenue is
    also posted as a revenue_transaction against the account so it flows
    into the account balance and consolidated P&L automatically (Section 13).
    """
    prop = db.get(Property, property_id)
    if prop is None:
        raise HTTPException(status_code=404, detail="Property not found")

    existing_rt = db.execute(
        select(RentalTransaction).where(
            RentalTransaction.property_id == property_id,
            RentalTransaction.period_month == payload.period_month.replace(day=1),
        )
    ).scalar_one_or_none()

    if existing_rt is None:
        rt = RentalTransaction(
            property_id=property_id,
            tenant_id=payload.tenant_id,
            period_month=payload.period_month.replace(day=1),
            amount_due=payload.amount_due,
            amount_paid=payload.amount_paid,
        )
        db.add(rt)
    else:
        rt = existing_rt
        rt.amount_paid = float(rt.amount_paid) + payload.amount_paid

    if float(rt.amount_paid) >= float(rt.amount_due):
        rt.status = "advance" if float(rt.amount_paid) > float(rt.amount_due) else "paid"
    elif float(rt.amount_paid) > 0:
        rt.status = "partial"
    else:
        rt.status = "outstanding"

    db.flush()

    # Post as revenue so it flows through the shared financial pipeline (account balance, P&L).
    from app.models.financial import RevenueTransaction
    from app.services.transaction_code import generate_transaction_code
    from app.services.financial_calculator import recompute_account_balance

    code = generate_transaction_code(db, prefix="REV", table_name="revenue_transactions",
                                      code_column=RevenueTransaction.transaction_code)
    revenue_txn = RevenueTransaction(
        transaction_code=code,
        business_unit_id=prop.business_unit_id,
        account_id=payload.account_id,
        category="monthly_rent",
        description=f"Rent for {payload.period_month.strftime('%Y-%m')}",
        amount=payload.amount_paid,
        txn_date=date.today(),
        idempotency_key=payload.idempotency_key,
        created_by=current_user.id,
    )
    existing = db.execute(
        select(RevenueTransaction).where(RevenueTransaction.idempotency_key == payload.idempotency_key)
    ).scalar_one_or_none()
    if existing is None:
        db.add(revenue_txn)
        db.flush()
        recompute_account_balance(db, payload.account_id)

    log_action(db, user_id=current_user.id, entity_type="rental_transaction", entity_id=rt.id, action="create",
               new_value={"amount_paid": str(payload.amount_paid), "status": rt.status})
    db.commit()
    db.refresh(rt)
    return rt


@router.get("/{property_id}/rent-history", response_model=list[RentalTransactionOut])
def rent_history(
    property_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("properties", "read")),
):
    stmt = select(RentalTransaction).where(RentalTransaction.property_id == property_id).order_by(
        RentalTransaction.period_month.desc()
    )
    return db.execute(stmt).scalars().all()


@router.get("/{property_id}/dashboard", response_model=PropertyDashboard)
def property_dashboard(
    property_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("properties", "read")),
):
    prop = db.get(Property, property_id)
    if prop is None:
        raise HTTPException(status_code=404, detail="Property not found")
    unit = db.get(BusinessUnit, prop.business_unit_id)

    from sqlalchemy import func as sa_func

    collected = float(
        db.execute(
            select(sa_func.coalesce(sa_func.sum(RentalTransaction.amount_paid), 0)).where(
                RentalTransaction.property_id == property_id
            )
        ).scalar_one()
    )
    expenses = total_expense(db, business_unit_id=unit.id)
    outstanding = outstanding_rent(db, property_id=property_id)

    return PropertyDashboard(
        property_id=prop.id,
        name=unit.name,
        monthly_rent=float(prop.monthly_rent),
        annual_rent=float(prop.monthly_rent) * 12,
        collected_rent=collected,
        outstanding_rent=outstanding,
        property_expenses=expenses,
        net_rental_profit=collected - expenses,
        occupancy_status=prop.status,
    )
