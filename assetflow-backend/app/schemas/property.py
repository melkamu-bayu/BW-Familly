import uuid
from datetime import date


from pydantic import BaseModel, Field


class PropertyCreate(BaseModel):
    name: str
    address: str | None = None
    property_type: str | None = None
    rooms: int | None = None
    monthly_rent: float = Field(gt=0)
    security_deposit: float | None = None
    payment_frequency: str | None = "monthly"


class PropertyUpdate(BaseModel):
    address: str | None = None
    property_type: str | None = None
    rooms: int | None = None
    monthly_rent: float | None = None
    security_deposit: float | None = None
    payment_frequency: str | None = None
    status: str | None = None


class PropertyOut(BaseModel):
    id: uuid.UUID
    business_unit_id: uuid.UUID
    name: str
    address: str | None
    property_type: str | None
    rooms: int | None
    monthly_rent: float
    security_deposit: float | None
    payment_frequency: str | None
    status: str


class TenantCreate(BaseModel):
    name: str
    phone: str | None = None
    contract_start: date | None = None
    contract_end: date | None = None


class TenantOut(BaseModel):
    id: uuid.UUID
    property_id: uuid.UUID
    name: str
    phone: str | None
    contract_start: date | None
    contract_end: date | None
    active: bool

    model_config = {"from_attributes": True}


class RentCollectionCreate(BaseModel):
    """Records a rent payment. amount_paid may be full, partial, or an advance
    (amount_paid > amount_due for the given period)."""
    tenant_id: uuid.UUID | None = None
    period_month: date  # any day within the billing month; normalized to 1st internally
    amount_due: float = Field(gt=0)
    amount_paid: float = Field(ge=0)
    account_id: uuid.UUID  # cash/bank account the rent lands in
    idempotency_key: uuid.UUID


class RentalTransactionOut(BaseModel):
    id: uuid.UUID
    property_id: uuid.UUID
    tenant_id: uuid.UUID | None
    period_month: date
    amount_due: float
    amount_paid: float
    status: str

    model_config = {"from_attributes": True}


class PropertyDashboard(BaseModel):
    property_id: uuid.UUID
    name: str
    monthly_rent: float
    annual_rent: float
    collected_rent: float
    outstanding_rent: float
    property_expenses: float
    net_rental_profit: float
    occupancy_status: str
