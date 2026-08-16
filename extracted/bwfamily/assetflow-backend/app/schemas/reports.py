import uuid
from datetime import date

from pydantic import BaseModel


class ProfitLossLine(BaseModel):
    label: str
    revenue: float
    expenses: float
    profit: float


class ProfitLossReport(BaseModel):
    period_from: date | None
    period_to: date | None
    consolidated: ProfitLossLine
    by_category: list[ProfitLossLine]


class CashFlowPoint(BaseModel):
    period_label: str
    inflow: float
    outflow: float
    net: float


class CashFlowReport(BaseModel):
    period_from: date | None
    period_to: date | None
    group_by: str
    points: list[CashFlowPoint]
    total_inflow: float
    total_outflow: float
    net_cash_flow: float


class ReceivableLine(BaseModel):
    customer_id: uuid.UUID
    customer_name: str
    outstanding_balance: float


class PayableLine(BaseModel):
    supplier_id: uuid.UUID
    supplier_name: str
    outstanding_payable: float


class TrendPoint(BaseModel):
    period_label: str
    revenue: float
    expense: float
    profit: float


class TrendReport(BaseModel):
    metric_group_by: str
    points: list[TrendPoint]


class Insight(BaseModel):
    text: str
    category: str  # vehicles, properties, shop, projects, general
    severity: str = "info"  # info, warning
