import uuid
from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, func
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import require_permission
from app.models.identity import User
from app.models.business import BusinessUnit
from app.models.shop import (
    Product,
    ProductCategory,
    Supplier,
    Customer,
    Purchase,
    PurchaseItem,
    Sale,
    SaleItem,
    InventoryTransaction,
)
from app.models.financial import ExpenseTransaction, RevenueTransaction
from app.schemas.shop import (
    ProductCreate,
    ProductUpdate,
    ProductOut,
    SupplierCreate,
    SupplierOut,
    CustomerCreate,
    CustomerOut,
    PurchaseCreate,
    PurchaseOut,
    SaleCreate,
    SaleOut,
    ShopDashboard,
)
from app.services.audit_service import log_action
from app.services.transaction_code import generate_transaction_code
from app.services.financial_calculator import (
    stock_value,
    shop_gross_profit,
    shop_net_profit,
    total_expense,
    recompute_account_balance,
)

router = APIRouter(prefix="/shop", tags=["shop"])


def _get_shop_unit(db: Session) -> BusinessUnit:
    unit = db.execute(select(BusinessUnit).where(BusinessUnit.unit_type == "shop")).scalar_one_or_none()
    if unit is None:
        raise HTTPException(status_code=500, detail="Construction Materials Shop business unit not seeded")
    return unit


def _product_out(product: Product) -> ProductOut:
    return ProductOut(
        id=product.id,
        business_unit_id=product.business_unit_id,
        name=product.name,
        sku=product.sku,
        barcode=product.barcode,
        unit=product.unit,
        purchase_price=float(product.purchase_price) if product.purchase_price is not None else None,
        selling_price=float(product.selling_price) if product.selling_price is not None else None,
        current_quantity=float(product.current_quantity),
        min_stock_level=float(product.min_stock_level),
        warehouse_location=product.warehouse_location,
        stock_value=stock_value(product),
    )


# ---------- Products ----------

@router.get("/products", response_model=list[ProductOut])
def list_products(
    low_stock_only: bool = False,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("shop", "read")),
):
    stmt = select(Product).where(Product.deleted_at.is_(None))
    products = db.execute(stmt).scalars().all()
    if low_stock_only:
        products = [p for p in products if float(p.current_quantity) <= float(p.min_stock_level)]
    return [_product_out(p) for p in products]


@router.post("/products", response_model=ProductOut, status_code=201)
def create_product(
    payload: ProductCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("shop", "create")),
):
    shop_unit = _get_shop_unit(db)
    product = Product(
        business_unit_id=shop_unit.id,
        name=payload.name,
        sku=payload.sku,
        barcode=payload.barcode,
        category_id=payload.category_id,
        unit=payload.unit,
        purchase_price=payload.purchase_price,
        selling_price=payload.selling_price,
        min_stock_level=payload.min_stock_level,
        warehouse_location=payload.warehouse_location,
    )
    db.add(product)
    db.flush()
    log_action(db, user_id=current_user.id, entity_type="product", entity_id=product.id, action="create",
               new_value={"name": payload.name})
    db.commit()
    db.refresh(product)
    return _product_out(product)


@router.patch("/products/{product_id}", response_model=ProductOut)
def update_product(
    product_id: uuid.UUID,
    payload: ProductUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("shop", "update")),
):
    product = db.get(Product, product_id)
    if product is None or product.deleted_at is not None:
        raise HTTPException(status_code=404, detail="Product not found")
    updates = payload.model_dump(exclude_unset=True)
    for field, value in updates.items():
        setattr(product, field, value)
    log_action(db, user_id=current_user.id, entity_type="product", entity_id=product.id, action="update",
               new_value={k: str(v) for k, v in updates.items()})
    db.commit()
    db.refresh(product)
    return _product_out(product)


# ---------- Suppliers & Customers ----------

@router.get("/suppliers", response_model=list[SupplierOut])
def list_suppliers(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("shop", "read")),
):
    return db.execute(select(Supplier)).scalars().all()


@router.post("/suppliers", response_model=SupplierOut, status_code=201)
def create_supplier(
    payload: SupplierCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("shop", "create")),
):
    supplier = Supplier(**payload.model_dump())
    db.add(supplier)
    db.commit()
    db.refresh(supplier)
    return supplier


@router.get("/customers", response_model=list[CustomerOut])
def list_customers(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("shop", "read")),
):
    return db.execute(select(Customer)).scalars().all()


@router.post("/customers", response_model=CustomerOut, status_code=201)
def create_customer(
    payload: CustomerCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("shop", "create")),
):
    customer = Customer(**payload.model_dump())
    db.add(customer)
    db.commit()
    db.refresh(customer)
    return customer


# ---------- Purchases (increase stock) ----------

@router.post("/purchases", response_model=PurchaseOut, status_code=201)
def create_purchase(
    payload: PurchaseCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("shop", "create")),
):
    existing = db.execute(
        select(Purchase).where(Purchase.invoice_number == payload.invoice_number)
    ).scalar_one_or_none()
    if existing is not None:
        return existing

    shop_unit = _get_shop_unit(db)
    total_cost = sum(item.quantity * item.unit_price for item in payload.items)

    purchase = Purchase(
        invoice_number=payload.invoice_number,
        supplier_id=payload.supplier_id,
        business_unit_id=shop_unit.id,
        total_cost=total_cost,
        payment_status=payload.payment_status,
        purchase_date=payload.purchase_date,
        created_by=current_user.id,
    )
    db.add(purchase)
    db.flush()

    for item in payload.items:
        product = db.get(Product, item.product_id)
        if product is None:
            raise HTTPException(status_code=404, detail=f"Product {item.product_id} not found")

        line_total = item.quantity * item.unit_price
        db.add(PurchaseItem(
            purchase_id=purchase.id, product_id=item.product_id,
            quantity=item.quantity, unit_price=item.unit_price, line_total=line_total,
        ))

        new_qty = float(product.current_quantity) + item.quantity
        product.current_quantity = new_qty
        db.add(InventoryTransaction(
            product_id=product.id, txn_type="purchase", reference_id=purchase.id,
            quantity_change=item.quantity, resulting_quantity=new_qty,
        ))

    # If paid now, record it as a shop expense so it flows through the shared financial pipeline.
    if payload.payment_status == "paid":
        code = generate_transaction_code(db, prefix="EXP", table_name="expense_transactions",
                                          code_column=ExpenseTransaction.transaction_code)
        db.add(ExpenseTransaction(
            transaction_code=code,
            business_unit_id=shop_unit.id,
            account_id=payload.account_id,
            supplier_id=payload.supplier_id,
            category="inventory_purchase",
            description=f"Purchase invoice {payload.invoice_number}",
            amount=total_cost,
            txn_date=payload.purchase_date,
            idempotency_key=payload.idempotency_key,
            created_by=current_user.id,
        ))
        db.flush()
        recompute_account_balance(db, payload.account_id)
    elif payload.supplier_id:
        supplier = db.get(Supplier, payload.supplier_id)
        if supplier:
            supplier.outstanding_payable = float(supplier.outstanding_payable) + total_cost

    log_action(db, user_id=current_user.id, entity_type="purchase", entity_id=purchase.id, action="create",
               new_value={"invoice_number": payload.invoice_number, "total_cost": str(total_cost)})
    db.commit()
    db.refresh(purchase)
    return purchase


# ---------- Sales (decrease stock) ----------

@router.post("/sales", response_model=SaleOut, status_code=201)
def create_sale(
    payload: SaleCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("shop", "create")),
):
    existing = db.execute(
        select(Sale).where(Sale.invoice_number == payload.invoice_number)
    ).scalar_one_or_none()
    if existing is not None:
        return existing

    shop_unit = _get_shop_unit(db)

    # Validate stock availability before committing any writes.
    products_by_id = {}
    for item in payload.items:
        product = db.get(Product, item.product_id)
        if product is None:
            raise HTTPException(status_code=404, detail=f"Product {item.product_id} not found")
        if float(product.current_quantity) < item.quantity:
            raise HTTPException(
                status_code=400,
                detail=f"Insufficient stock for '{product.name}': have {product.current_quantity}, need {item.quantity}",
            )
        products_by_id[item.product_id] = product

    subtotal = sum(item.quantity * item.unit_price for item in payload.items)
    total_amount = subtotal - payload.discount

    sale = Sale(
        invoice_number=payload.invoice_number,
        customer_id=payload.customer_id,
        business_unit_id=shop_unit.id,
        total_amount=total_amount,
        discount=payload.discount,
        payment_method=payload.payment_method,
        payment_status=payload.payment_status,
        sale_date=payload.sale_date,
        created_by=current_user.id,
    )
    db.add(sale)
    db.flush()

    for item in payload.items:
        product = products_by_id[item.product_id]
        line_total = item.quantity * item.unit_price
        db.add(SaleItem(
            sale_id=sale.id, product_id=item.product_id,
            quantity=item.quantity, unit_price=item.unit_price, line_total=line_total,
        ))
        new_qty = float(product.current_quantity) - item.quantity
        product.current_quantity = new_qty
        db.add(InventoryTransaction(
            product_id=product.id, txn_type="sale", reference_id=sale.id,
            quantity_change=-item.quantity, resulting_quantity=new_qty,
        ))

    if payload.payment_status == "paid":
        code = generate_transaction_code(db, prefix="REV", table_name="revenue_transactions",
                                          code_column=RevenueTransaction.transaction_code)
        db.add(RevenueTransaction(
            transaction_code=code,
            business_unit_id=shop_unit.id,
            account_id=payload.account_id,
            customer_id=payload.customer_id,
            category="product_sales",
            description=f"Sale invoice {payload.invoice_number}",
            amount=total_amount,
            payment_method=payload.payment_method,
            txn_date=payload.sale_date,
            idempotency_key=payload.idempotency_key,
            created_by=current_user.id,
        ))
        db.flush()
        recompute_account_balance(db, payload.account_id)
    elif payload.customer_id:
        customer = db.get(Customer, payload.customer_id)
        if customer:
            customer.outstanding_balance = float(customer.outstanding_balance) + total_amount

    log_action(db, user_id=current_user.id, entity_type="sale", entity_id=sale.id, action="create",
               new_value={"invoice_number": payload.invoice_number, "total_amount": str(total_amount)})
    db.commit()
    db.refresh(sale)
    return sale


# ---------- Dashboard ----------

@router.get("/dashboard", response_model=ShopDashboard)
def shop_dashboard(
    date_from: date | None = None,
    date_to: date | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("shop", "read")),
):
    shop_unit = _get_shop_unit(db)
    gross = shop_gross_profit(db, shop_unit.id, date_from, date_to)
    opex = total_expense(db, business_unit_id=shop_unit.id, date_from=date_from, date_to=date_to)
    net = gross - opex

    # revenue and COGS individually, for display
    revenue_stmt = select(func.coalesce(func.sum(Sale.total_amount), 0)).where(Sale.business_unit_id == shop_unit.id)
    if date_from:
        revenue_stmt = revenue_stmt.where(Sale.sale_date >= date_from)
    if date_to:
        revenue_stmt = revenue_stmt.where(Sale.sale_date <= date_to)
    revenue = float(db.execute(revenue_stmt).scalar_one())
    cogs = revenue - gross

    low_stock_count = len([
        p for p in db.execute(select(Product).where(Product.deleted_at.is_(None))).scalars().all()
        if float(p.current_quantity) <= float(p.min_stock_level)
    ])

    return ShopDashboard(
        revenue=revenue,
        cost_of_goods_sold=cogs,
        gross_profit=gross,
        operating_expenses=opex,
        net_profit=net,
        low_stock_count=low_stock_count,
    )
