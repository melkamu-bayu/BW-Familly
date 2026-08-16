import uuid
from datetime import date, datetime

from sqlalchemy import String, Numeric, ForeignKey, Date, DateTime, func, CheckConstraint, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.models.mixins import UUIDPKMixin, SoftDeleteMixin


class Account(Base, UUIDPKMixin):
    __tablename__ = "accounts"

    name: Mapped[str] = mapped_column(String(100), nullable=False)
    account_type: Mapped[str] = mapped_column(String(30), nullable=False)  # cash, bank, mobile_money, other
    account_number: Mapped[str | None] = mapped_column(String(60))
    opening_balance: Mapped[float] = mapped_column(Numeric(16, 2), default=0)
    current_balance: Mapped[float] = mapped_column(Numeric(16, 2), default=0)
    currency: Mapped[str] = mapped_column(String(10), default="ETB")
    status: Mapped[str] = mapped_column(String(20), default="active")


class RevenueTransaction(Base, UUIDPKMixin, SoftDeleteMixin):
    __tablename__ = "revenue_transactions"
    __table_args__ = (CheckConstraint("amount >= 0", name="ck_revenue_amount_nonneg"),)

    transaction_code: Mapped[str] = mapped_column(String(30), unique=True, nullable=False)  # REV-2026-000001
    business_unit_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("business_units.id"), nullable=False)
    account_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("accounts.id"), nullable=False)
    customer_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("customers.id"))
    category: Mapped[str] = mapped_column(String(60), nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    amount: Mapped[float] = mapped_column(Numeric(16, 2), nullable=False)
    currency: Mapped[str] = mapped_column(String(10), default="ETB")
    payment_method: Mapped[str | None] = mapped_column(String(30))
    payment_status: Mapped[str] = mapped_column(String(20), default="received")
    reference_number: Mapped[str | None] = mapped_column(String(60))
    txn_date: Mapped[date] = mapped_column(Date, nullable=False)
    idempotency_key: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), unique=True)
    created_by: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class ExpenseTransaction(Base, UUIDPKMixin, SoftDeleteMixin):
    __tablename__ = "expense_transactions"
    __table_args__ = (CheckConstraint("amount >= 0", name="ck_expense_amount_nonneg"),)

    transaction_code: Mapped[str] = mapped_column(String(30), unique=True, nullable=False)  # EXP-2026-000001
    business_unit_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("business_units.id"), nullable=False)
    account_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("accounts.id"), nullable=False)
    supplier_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("suppliers.id"))
    category: Mapped[str] = mapped_column(String(60), nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    amount: Mapped[float] = mapped_column(Numeric(16, 2), nullable=False)
    currency: Mapped[str] = mapped_column(String(10), default="ETB")
    payment_method: Mapped[str | None] = mapped_column(String(30))
    payment_status: Mapped[str] = mapped_column(String(20), default="paid")
    invoice_number: Mapped[str | None] = mapped_column(String(60))
    txn_date: Mapped[date] = mapped_column(Date, nullable=False)
    idempotency_key: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), unique=True)
    created_by: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Payment(Base, UUIDPKMixin):
    __tablename__ = "payments"

    transaction_code: Mapped[str] = mapped_column(String(30), unique=True, nullable=False)  # PAY-2026-000001
    account_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("accounts.id"), nullable=False)
    direction: Mapped[str] = mapped_column(String(10), nullable=False)  # in, out
    related_type: Mapped[str | None] = mapped_column(String(30))  # rent, sale, purchase, expense
    related_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True))
    amount: Mapped[float] = mapped_column(Numeric(16, 2), nullable=False)
    payment_date: Mapped[date] = mapped_column(Date, nullable=False)
    created_by: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class AccountTransfer(Base, UUIDPKMixin):
    __tablename__ = "account_transfers"

    from_account_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("accounts.id"), nullable=False)
    to_account_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("accounts.id"), nullable=False)
    amount: Mapped[float] = mapped_column(Numeric(16, 2), nullable=False)
    transfer_date: Mapped[date] = mapped_column(Date, nullable=False)
    created_by: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class RentalTransaction(Base, UUIDPKMixin):
    __tablename__ = "rental_transactions"

    property_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("properties.id"), nullable=False)
    tenant_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("tenants.id"))
    period_month: Mapped[date] = mapped_column(Date, nullable=False)
    amount_due: Mapped[float] = mapped_column(Numeric(14, 2), nullable=False)
    amount_paid: Mapped[float] = mapped_column(Numeric(14, 2), default=0)
    status: Mapped[str] = mapped_column(String(20), default="outstanding")  # paid, partial, outstanding, advance


class MaintenanceRecord(Base, UUIDPKMixin):
    __tablename__ = "maintenance_records"

    business_unit_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("business_units.id"), nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    cost: Mapped[float | None] = mapped_column(Numeric(14, 2))
    performed_at: Mapped[date | None] = mapped_column(Date)
    next_due: Mapped[date | None] = mapped_column(Date)


class ProjectTransaction(Base, UUIDPKMixin):
    __tablename__ = "project_transactions"

    project_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("projects.id"), nullable=False)
    txn_type: Mapped[str] = mapped_column(String(30), nullable=False)  # investment, expense, revenue
    category: Mapped[str | None] = mapped_column(String(60))
    amount: Mapped[float] = mapped_column(Numeric(16, 2), nullable=False)
    txn_date: Mapped[date] = mapped_column(Date, nullable=False)
    created_by: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"))
