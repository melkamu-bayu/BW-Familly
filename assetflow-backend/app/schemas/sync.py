import uuid
from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, Field


class SyncRevenueItem(BaseModel):
    idempotency_key: uuid.UUID
    business_unit_id: uuid.UUID
    account_id: uuid.UUID
    customer_id: uuid.UUID | None = None
    category: str
    description: str | None = None
    amount: float = Field(gt=0)
    currency: str = "ETB"
    payment_method: str | None = None
    payment_status: str = "received"
    reference_number: str | None = None
    txn_date: date


class SyncExpenseItem(BaseModel):
    idempotency_key: uuid.UUID
    business_unit_id: uuid.UUID
    account_id: uuid.UUID
    supplier_id: uuid.UUID | None = None
    category: str
    description: str | None = None
    amount: float = Field(gt=0)
    currency: str = "ETB"
    payment_method: str | None = None
    payment_status: str = "paid"
    invoice_number: str | None = None
    txn_date: date


class SyncPushItem(BaseModel):
    """
    One outbox entry from the mobile client. `entity_type` selects which
    schema `payload` is validated against; `client_created_at` is informational
    only (server `created_at` remains authoritative for ordering).
    """
    entity_type: Literal["revenue", "expense"]
    client_created_at: datetime
    payload: SyncRevenueItem | SyncExpenseItem


class SyncPushRequest(BaseModel):
    items: list[SyncPushItem] = Field(min_length=1, max_length=200)


class SyncPushResult(BaseModel):
    idempotency_key: uuid.UUID
    entity_type: str
    status: Literal["applied", "duplicate", "rejected"]
    server_id: uuid.UUID | None = None
    transaction_code: str | None = None
    error: str | None = None


class SyncPushResponse(BaseModel):
    results: list[SyncPushResult]


class SyncPullResponse(BaseModel):
    server_time: datetime
    revenue: list[dict]
    expenses: list[dict]
