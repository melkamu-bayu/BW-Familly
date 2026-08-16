"""
Centralized financial calculation engine.

Per Section 28 of the architecture plan, NO domain service (vehicles,
properties, shop, projects) computes profit/balances/ROI independently.
They all call into this module, so a formula change happens in exactly
one place and every module stays consistent.
"""
import uuid
from datetime import date

from sqlalchemy import select, func
from sqlalchemy.orm import Session

from app.models.financial import (
    Account,
    RevenueTransaction,
    ExpenseTransaction,
    RentalTransaction,
)
from app.models.shop import Sale, Purchase, Product


def _sum_amount(db: Session, model, column, business_unit_id: uuid.UUID | None = None,
                 date_from: date | None = None, date_to: date | None = None) -> float:
    stmt = select(func.coalesce(func.sum(column), 0))
    if hasattr(model, "deleted_at"):
        stmt = stmt.where(model.deleted_at.is_(None))
    if business_unit_id is not None and hasattr(model, "business_unit_id"):
        stmt = stmt.where(model.business_unit_id == business_unit_id)
    if date_from is not None and hasattr(model, "txn_date"):
        stmt = stmt.where(model.txn_date >= date_from)
    if date_to is not None and hasattr(model, "txn_date"):
        stmt = stmt.where(model.txn_date <= date_to)
    return float(db.execute(stmt).scalar_one())


def total_revenue(db: Session, business_unit_id: uuid.UUID | None = None,
                   date_from: date | None = None, date_to: date | None = None) -> float:
    return _sum_amount(db, RevenueTransaction, RevenueTransaction.amount, business_unit_id, date_from, date_to)


def total_expense(db: Session, business_unit_id: uuid.UUID | None = None,
                   date_from: date | None = None, date_to: date | None = None) -> float:
    return _sum_amount(db, ExpenseTransaction, ExpenseTransaction.amount, business_unit_id, date_from, date_to)


def net_profit(db: Session, business_unit_id: uuid.UUID | None = None,
                date_from: date | None = None, date_to: date | None = None) -> float:
    """Vehicle Profit / Net Rental Profit / Net Project Profit all reduce to this formula."""
    return total_revenue(db, business_unit_id, date_from, date_to) - total_expense(db, business_unit_id, date_from, date_to)


def cost_per_kilometer(db: Session, business_unit_id: uuid.UUID, total_mileage: float,
                        date_from: date | None = None, date_to: date | None = None) -> float | None:
    if not total_mileage:
        return None
    return total_expense(db, business_unit_id, date_from, date_to) / total_mileage


def profit_per_kilometer(db: Session, business_unit_id: uuid.UUID, total_mileage: float,
                          date_from: date | None = None, date_to: date | None = None) -> float | None:
    if not total_mileage:
        return None
    return net_profit(db, business_unit_id, date_from, date_to) / total_mileage


def outstanding_rent(db: Session, property_id: uuid.UUID | None = None) -> float:
    stmt = select(
        func.coalesce(func.sum(RentalTransaction.amount_due - RentalTransaction.amount_paid), 0)
    )
    if property_id is not None:
        stmt = stmt.where(RentalTransaction.property_id == property_id)
    return float(db.execute(stmt).scalar_one())


def stock_value(product: Product) -> float:
    """Stock Value = Current Quantity x Purchase (Cost) Price."""
    price = product.purchase_price or 0
    return float(product.current_quantity) * float(price)


def shop_gross_profit(db: Session, business_unit_id: uuid.UUID,
                       date_from: date | None = None, date_to: date | None = None) -> float:
    """Gross Profit = Sales Revenue - Cost of Goods Sold.
    COGS is approximated from sale_items x product purchase_price at time of query;
    for full accuracy, capture unit_cost on SaleItem at sale time in a future iteration."""
    sales_stmt = select(func.coalesce(func.sum(Sale.total_amount - Sale.discount), 0)).where(
        Sale.business_unit_id == business_unit_id
    )
    if date_from is not None:
        sales_stmt = sales_stmt.where(Sale.sale_date >= date_from)
    if date_to is not None:
        sales_stmt = sales_stmt.where(Sale.sale_date <= date_to)
    revenue = float(db.execute(sales_stmt).scalar_one())

    from app.models.shop import SaleItem  # local import avoids circular import at module load

    cogs_stmt = (
        select(func.coalesce(func.sum(SaleItem.quantity * Product.purchase_price), 0))
        .join(Product, Product.id == SaleItem.product_id)
        .join(Sale, Sale.id == SaleItem.sale_id)
        .where(Sale.business_unit_id == business_unit_id)
    )
    if date_from is not None:
        cogs_stmt = cogs_stmt.where(Sale.sale_date >= date_from)
    if date_to is not None:
        cogs_stmt = cogs_stmt.where(Sale.sale_date <= date_to)
    cogs = float(db.execute(cogs_stmt).scalar_one())

    return revenue - cogs


def shop_net_profit(db: Session, business_unit_id: uuid.UUID,
                     date_from: date | None = None, date_to: date | None = None) -> float:
    """Net Profit (Shop) = Gross Profit - Operating Expenses."""
    gross = shop_gross_profit(db, business_unit_id, date_from, date_to)
    opex = total_expense(db, business_unit_id, date_from, date_to)
    return gross - opex


def project_roi(initial_investment: float, additional_investment: float, project_net_profit: float) -> float | None:
    """ROI = (Net Profit / Total Investment) x 100"""
    total_investment = (initial_investment or 0) + (additional_investment or 0)
    if not total_investment:
        return None
    return (project_net_profit / total_investment) * 100


def recompute_account_balance(db: Session, account_id: uuid.UUID) -> float:
    """
    Current Balance = Opening Balance + Income - Expenses + Transfers In - Transfers Out.
    Called after every revenue/expense/payment/transfer write touching this account.
    """
    from app.models.financial import AccountTransfer

    account = db.get(Account, account_id)
    if account is None:
        raise ValueError(f"Account {account_id} not found")

    income = _sum_amount(db, RevenueTransaction, RevenueTransaction.amount) if False else float(
        db.execute(
            select(func.coalesce(func.sum(RevenueTransaction.amount), 0)).where(
                RevenueTransaction.account_id == account_id, RevenueTransaction.deleted_at.is_(None)
            )
        ).scalar_one()
    )
    expenses = float(
        db.execute(
            select(func.coalesce(func.sum(ExpenseTransaction.amount), 0)).where(
                ExpenseTransaction.account_id == account_id, ExpenseTransaction.deleted_at.is_(None)
            )
        ).scalar_one()
    )
    transfers_in = float(
        db.execute(
            select(func.coalesce(func.sum(AccountTransfer.amount), 0)).where(
                AccountTransfer.to_account_id == account_id
            )
        ).scalar_one()
    )
    transfers_out = float(
        db.execute(
            select(func.coalesce(func.sum(AccountTransfer.amount), 0)).where(
                AccountTransfer.from_account_id == account_id
            )
        ).scalar_one()
    )

    new_balance = float(account.opening_balance) + income - expenses + transfers_in - transfers_out
    account.current_balance = new_balance
    db.add(account)
    return new_balance
