import uuid
from datetime import date, datetime

from sqlalchemy import String, Numeric, ForeignKey, Date, DateTime, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.models.mixins import UUIDPKMixin, SoftDeleteMixin


class ProductCategory(Base, UUIDPKMixin):
    __tablename__ = "product_categories"

    name: Mapped[str] = mapped_column(String(100), unique=True, nullable=False)


class Product(Base, UUIDPKMixin, SoftDeleteMixin):
    __tablename__ = "products"

    business_unit_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("business_units.id"), nullable=False)
    name: Mapped[str] = mapped_column(String(150), nullable=False)
    sku: Mapped[str | None] = mapped_column(String(60), unique=True)
    barcode: Mapped[str | None] = mapped_column(String(60))
    category_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("product_categories.id"))
    unit: Mapped[str] = mapped_column(String(20), nullable=False)  # piece, bag, ton, kg, meter, cubic_meter, liter, box
    purchase_price: Mapped[float | None] = mapped_column(Numeric(14, 2))
    selling_price: Mapped[float | None] = mapped_column(Numeric(14, 2))
    current_quantity: Mapped[float] = mapped_column(Numeric(14, 3), default=0)
    min_stock_level: Mapped[float] = mapped_column(Numeric(14, 3), default=0)
    warehouse_location: Mapped[str | None] = mapped_column(String(100))


class Supplier(Base, UUIDPKMixin):
    __tablename__ = "suppliers"

    name: Mapped[str] = mapped_column(String(150), nullable=False)
    phone: Mapped[str | None] = mapped_column(String(30))
    email: Mapped[str | None] = mapped_column(String(150))
    address: Mapped[str | None] = mapped_column(String)
    outstanding_payable: Mapped[float] = mapped_column(Numeric(14, 2), default=0)


class Customer(Base, UUIDPKMixin):
    __tablename__ = "customers"

    name: Mapped[str] = mapped_column(String(150), nullable=False)
    phone: Mapped[str | None] = mapped_column(String(30))
    email: Mapped[str | None] = mapped_column(String(150))
    address: Mapped[str | None] = mapped_column(String)
    credit_limit: Mapped[float] = mapped_column(Numeric(14, 2), default=0)
    outstanding_balance: Mapped[float] = mapped_column(Numeric(14, 2), default=0)


class Purchase(Base, UUIDPKMixin):
    __tablename__ = "purchases"

    invoice_number: Mapped[str] = mapped_column(String(60), unique=True, nullable=False)
    supplier_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("suppliers.id"))
    business_unit_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("business_units.id"))
    total_cost: Mapped[float] = mapped_column(Numeric(16, 2), nullable=False)
    payment_status: Mapped[str] = mapped_column(String(20), default="pending")
    purchase_date: Mapped[date] = mapped_column(Date, nullable=False)
    created_by: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    items: Mapped[list["PurchaseItem"]] = relationship(back_populates="purchase", cascade="all, delete-orphan")


class PurchaseItem(Base, UUIDPKMixin):
    __tablename__ = "purchase_items"

    purchase_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("purchases.id", ondelete="CASCADE"))
    product_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("products.id"), nullable=False)
    quantity: Mapped[float] = mapped_column(Numeric(14, 3), nullable=False)
    unit_price: Mapped[float] = mapped_column(Numeric(14, 2), nullable=False)
    line_total: Mapped[float] = mapped_column(Numeric(16, 2), nullable=False)

    purchase: Mapped["Purchase"] = relationship(back_populates="items")


class Sale(Base, UUIDPKMixin):
    __tablename__ = "sales"

    invoice_number: Mapped[str] = mapped_column(String(60), unique=True, nullable=False)
    customer_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("customers.id"))
    business_unit_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("business_units.id"))
    total_amount: Mapped[float] = mapped_column(Numeric(16, 2), nullable=False)
    discount: Mapped[float] = mapped_column(Numeric(14, 2), default=0)
    payment_method: Mapped[str | None] = mapped_column(String(30))
    payment_status: Mapped[str] = mapped_column(String(20), default="paid")
    sale_date: Mapped[date] = mapped_column(Date, nullable=False)
    created_by: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    items: Mapped[list["SaleItem"]] = relationship(back_populates="sale", cascade="all, delete-orphan")


class SaleItem(Base, UUIDPKMixin):
    __tablename__ = "sale_items"

    sale_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("sales.id", ondelete="CASCADE"))
    product_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("products.id"), nullable=False)
    quantity: Mapped[float] = mapped_column(Numeric(14, 3), nullable=False)
    unit_price: Mapped[float] = mapped_column(Numeric(14, 2), nullable=False)
    line_total: Mapped[float] = mapped_column(Numeric(16, 2), nullable=False)

    sale: Mapped["Sale"] = relationship(back_populates="items")


class InventoryTransaction(Base, UUIDPKMixin):
    """Append-only stock ledger. current_quantity on Product is a cached
    projection of this ledger and must only ever be mutated alongside a new row here."""
    __tablename__ = "inventory_transactions"

    product_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("products.id"), nullable=False)
    txn_type: Mapped[str] = mapped_column(String(20), nullable=False)  # purchase, sale, adjustment
    reference_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True))
    quantity_change: Mapped[float] = mapped_column(Numeric(14, 3), nullable=False)  # signed
    resulting_quantity: Mapped[float] = mapped_column(Numeric(14, 3), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
