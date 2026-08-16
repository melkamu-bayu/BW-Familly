import uuid
from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel, Field


class RevenueCreate(BaseModel):
    business_unit_id: uuid.UUID
    account_id: uuid.UUID
    customer_id: uuid.UUID | None = None
    category: str
    description: str | None = None
    amount: Decimal = Field(gt=0)
    currency: str = "ETB"
    payment_method: str | None = None
    payment_status: str = "received"
    reference_number: str | None = None
    txn_date: date
    idempotency_key: uuid.UUID


class RevenueOut(BaseModel):
    id: uuid.UUID
    transaction_code: str
    business_unit_id: uuid.UUID
    account_id: uuid.UUID
    customer_id: uuid.UUID | None
    category: str
    description: str | None
    amount: Decimal
    currency: str
    payment_status: str
    txn_date: date
    created_at: datetime

    model_config = {"from_attributes": True}


class ExpenseCreate(BaseModel):
    business_unit_id: uuid.UUID
    account_id: uuid.UUID
    supplier_id: uuid.UUID | None = None
    category: str
    description: str | None = None
    amount: Decimal = Field(gt=0)
    currency: str = "ETB"
    payment_method: str | None = None
    payment_status: str = "paid"
    invoice_number: str | None = None
    txn_date: date
    idempotency_key: uuid.UUID


class ExpenseOut(BaseModel):
    id: uuid.UUID
    transaction_code: str
    business_unit_id: uuid.UUID
    account_id: uuid.UUID
    supplier_id: uuid.UUID | None
    category: str
    description: str | None
    amount: Decimal
    currency: str
    payment_status: str
    txn_date: date
    created_at: datetime

    model_config = {"from_attributes": True}


class AccountTransferCreate(BaseModel):
    from_account_id: uuid.UUID
    to_account_id: uuid.UUID
    amount: Decimal = Field(gt=0)
    transfer_date: date
    idempotency_key: uuid.UUID


class AccountOut(BaseModel):
    id: uuid.UUID
    name: str
    account_type: str
    current_balance: Decimal
    currency: str
    status: str

    model_config = {"from_attributes": True}
