import uuid
from datetime import date

from pydantic import BaseModel, Field


class ProductCreate(BaseModel):
    name: str
    sku: str | None = None
    barcode: str | None = None
    category_id: uuid.UUID | None = None
    unit: str  # piece, bag, ton, kg, meter, cubic_meter, liter, box
    purchase_price: float = Field(ge=0)
    selling_price: float = Field(ge=0)
    min_stock_level: float = 0
    warehouse_location: str | None = None


class ProductUpdate(BaseModel):
    name: str | None = None
    category_id: uuid.UUID | None = None
    purchase_price: float | None = None
    selling_price: float | None = None
    min_stock_level: float | None = None
    warehouse_location: str | None = None


class ProductOut(BaseModel):
    id: uuid.UUID
    business_unit_id: uuid.UUID
    name: str
    sku: str | None
    barcode: str | None
    unit: str
    purchase_price: float | None
    selling_price: float | None
    current_quantity: float
    min_stock_level: float
    warehouse_location: str | None
    stock_value: float

    model_config = {"from_attributes": True}


class SupplierCreate(BaseModel):
    name: str
    phone: str | None = None
    email: str | None = None
    address: str | None = None


class SupplierOut(BaseModel):
    id: uuid.UUID
    name: str
    phone: str | None
    email: str | None
    outstanding_payable: float

    model_config = {"from_attributes": True}


class CustomerCreate(BaseModel):
    name: str
    phone: str | None = None
    email: str | None = None
    address: str | None = None
    credit_limit: float = 0


class CustomerOut(BaseModel):
    id: uuid.UUID
    name: str
    phone: str | None
    email: str | None
    credit_limit: float
    outstanding_balance: float

    model_config = {"from_attributes": True}


class PurchaseItemIn(BaseModel):
    product_id: uuid.UUID
    quantity: float = Field(gt=0)
    unit_price: float = Field(ge=0)


class PurchaseCreate(BaseModel):
    invoice_number: str
    supplier_id: uuid.UUID | None = None
    account_id: uuid.UUID  # account the purchase is paid from (if paid now)
    items: list[PurchaseItemIn] = Field(min_length=1)
    payment_status: str = "pending"  # paid, partial, pending
    purchase_date: date
    idempotency_key: uuid.UUID


class PurchaseOut(BaseModel):
    id: uuid.UUID
    invoice_number: str
    supplier_id: uuid.UUID | None
    total_cost: float
    payment_status: str
    purchase_date: date

    model_config = {"from_attributes": True}


class SaleItemIn(BaseModel):
    product_id: uuid.UUID
    quantity: float = Field(gt=0)
    unit_price: float = Field(ge=0)


class SaleCreate(BaseModel):
    invoice_number: str
    customer_id: uuid.UUID | None = None
    account_id: uuid.UUID  # account the sale proceeds land in
    items: list[SaleItemIn] = Field(min_length=1)
    discount: float = 0
    payment_method: str | None = None
    payment_status: str = "paid"
    sale_date: date
    idempotency_key: uuid.UUID


class SaleOut(BaseModel):
    id: uuid.UUID
    invoice_number: str
    customer_id: uuid.UUID | None
    total_amount: float
    discount: float
    payment_status: str
    sale_date: date

    model_config = {"from_attributes": True}


class ShopDashboard(BaseModel):
    revenue: float
    cost_of_goods_sold: float
    gross_profit: float
    operating_expenses: float
    net_profit: float
    low_stock_count: int
