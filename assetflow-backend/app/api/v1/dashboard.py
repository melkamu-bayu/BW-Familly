from datetime import date

from fastapi import APIRouter, Depends
from sqlalchemy import select, func
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import require_permission
from app.models.identity import User
from app.models.financial import Account, RevenueTransaction, ExpenseTransaction
from app.models.business import BusinessUnit, BusinessCategory
from app.services.financial_calculator import total_revenue, total_expense, net_profit

router = APIRouter(prefix="/dashboard", tags=["dashboard"])


@router.get("/summary")
def financial_summary(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("reports", "read")),
):
    today = date.today()
    month_start = today.replace(day=1)

    cash_bank_total = float(
        db.execute(select(func.coalesce(func.sum(Account.current_balance), 0))).scalar_one()
    )

    return {
        "today": {
            "revenue": total_revenue(db, date_from=today, date_to=today),
            "expense": total_expense(db, date_from=today, date_to=today),
            "net_profit": net_profit(db, date_from=today, date_to=today),
        },
        "this_month": {
            "revenue": total_revenue(db, date_from=month_start, date_to=today),
            "expense": total_expense(db, date_from=month_start, date_to=today),
            "net_profit": net_profit(db, date_from=month_start, date_to=today),
        },
        "all_time": {
            "revenue": total_revenue(db),
            "expense": total_expense(db),
            "net_profit": net_profit(db),
        },
        "cash_and_bank_balance": cash_bank_total,
        "currency": "ETB",
    }


@router.get("/business-performance")
def business_performance(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("reports", "read")),
):
    """Revenue/expense/profit/% contribution per top-level business category
    (Vehicles, Rental Houses, Construction Materials Shop, Gold-Mining Project).

    Two aggregated GROUP BY queries instead of the previous per-business-unit
    loop -- the old version fired one total_revenue()/total_expense() call
    PER business unit (roughly 27 separate SQL round-trips for a typical
    10-unit deployment across 4 categories). This version fires 2, regardless
    of how many vehicles/properties/products exist. LEFT OUTER JOIN + COALESCE
    ensures a category with units but zero transactions yet still comes back
    as revenue=0 rather than being silently dropped from the result.
    """
    overall_profit = net_profit(db) or 1  # avoid div-by-zero; guarded below

    revenue_by_category = dict(
        db.execute(
            select(BusinessCategory.id, func.coalesce(func.sum(RevenueTransaction.amount), 0))
            .select_from(BusinessCategory)
            .join(BusinessUnit, BusinessUnit.category_id == BusinessCategory.id)
            .outerjoin(
                RevenueTransaction,
                (RevenueTransaction.business_unit_id == BusinessUnit.id)
                & (RevenueTransaction.deleted_at.is_(None)),
            )
            .group_by(BusinessCategory.id)
        ).all()
    )
    expense_by_category = dict(
        db.execute(
            select(BusinessCategory.id, func.coalesce(func.sum(ExpenseTransaction.amount), 0))
            .select_from(BusinessCategory)
            .join(BusinessUnit, BusinessUnit.category_id == BusinessCategory.id)
            .outerjoin(
                ExpenseTransaction,
                (ExpenseTransaction.business_unit_id == BusinessUnit.id)
                & (ExpenseTransaction.deleted_at.is_(None)),
            )
            .group_by(BusinessCategory.id)
        ).all()
    )

    categories = db.execute(select(BusinessCategory)).scalars().all()
    results = []
    for category in categories:
        cat_revenue = float(revenue_by_category.get(category.id, 0))
        cat_expense = float(expense_by_category.get(category.id, 0))
        cat_profit = cat_revenue - cat_expense
        contribution_pct = (cat_profit / overall_profit * 100) if overall_profit else 0

        results.append(
            {
                "category": category.name,
                "code": category.code,
                "revenue": cat_revenue,
                "expense": cat_expense,
                "profit": cat_profit,
                "percentage_contribution": round(contribution_pct, 2),
            }
        )
    return results
