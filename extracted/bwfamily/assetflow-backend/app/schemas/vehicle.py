import uuid
from datetime import date

from pydantic import BaseModel, Field


class VehicleCreate(BaseModel):
    name: str  # becomes the business_unit name
    plate_number: str | None = None
    vehicle_type: str | None = None
    manufacturer: str | None = None
    model: str | None = None
    year: int | None = None
    purchase_date: date | None = None
    purchase_price: float | None = None
    current_value: float | None = None
    driver_name: str | None = None
    mileage: float = 0
    operating_hours: float | None = None
    status: str = "active"
    insurance_expiry: date | None = None
    registration_expiry: date | None = None


class VehicleUpdate(BaseModel):
    plate_number: str | None = None
    vehicle_type: str | None = None
    manufacturer: str | None = None
    model: str | None = None
    year: int | None = None
    driver_name: str | None = None
    mileage: float | None = None
    operating_hours: float | None = None
    status: str | None = None
    insurance_expiry: date | None = None
    registration_expiry: date | None = None
    current_value: float | None = None


class VehicleOut(BaseModel):
    id: uuid.UUID
    business_unit_id: uuid.UUID
    name: str
    plate_number: str | None
    vehicle_type: str | None
    manufacturer: str | None
    model: str | None
    year: int | None
    driver_name: str | None
    mileage: float
    operating_hours: float | None
    status: str
    insurance_expiry: date | None
    registration_expiry: date | None
    purchase_price: float | None
    current_value: float | None


class VehicleProfitability(BaseModel):
    vehicle_id: uuid.UUID
    name: str
    period_from: date | None
    period_to: date | None
    revenue: float
    expenses: float
    profit: float
    mileage: float
    cost_per_km: float | None
    profit_per_km: float | None
    cost_per_operating_hour: float | None


class MaintenanceRecordCreate(BaseModel):
    description: str | None = None
    cost: float = Field(ge=0, default=0)
    performed_at: date | None = None
    next_due: date | None = None


class MaintenanceRecordOut(BaseModel):
    id: uuid.UUID
    business_unit_id: uuid.UUID
    description: str | None
    cost: float | None
    performed_at: date | None
    next_due: date | None

    model_config = {"from_attributes": True}
