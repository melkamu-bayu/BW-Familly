import uuid
from datetime import date

from pydantic import BaseModel, Field


class ProjectTransactionCreate(BaseModel):
    txn_type: str = Field(pattern="^(investment|expense|revenue)$")
    category: str | None = None  # equipment, fuel, labor, transportation, materials, licensing, security, gold_sale, other
    amount: float = Field(gt=0)
    txn_date: date
    account_id: uuid.UUID | None = None  # if the txn moves cash, the account it moves through
    idempotency_key: uuid.UUID


class ProjectTransactionOut(BaseModel):
    id: uuid.UUID
    project_id: uuid.UUID
    txn_type: str
    category: str | None
    amount: float
    txn_date: date

    model_config = {"from_attributes": True}


class ProjectStatusUpdate(BaseModel):
    status: str = Field(pattern="^(planning|active|suspended|completed|closed)$")


class ProjectDashboard(BaseModel):
    project_id: uuid.UUID
    name: str
    status: str
    total_investment: float
    total_expenses: float
    total_revenue: float
    net_profit: float
    cash_used: float
    roi: float | None
