from datetime import date

from fastapi import APIRouter, Depends
from sqlalchemy import select, func
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import require_permission
from app.models.identity import User
from app.models.financial import Account
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
    (Vehicles, Rental Houses, Construction Materials Shop, Gold-Mining Project)."""
    categories = db.execute(select(BusinessCategory)).scalars().all()
    overall_profit = net_profit(db) or 1  # avoid div-by-zero; guarded below

    results = []
    for category in categories:
        unit_ids = [
            u.id for u in db.execute(
                select(BusinessUnit).where(BusinessUnit.category_id == category.id)
            ).scalars().all()
        ]
        cat_revenue = sum(total_revenue(db, business_unit_id=uid) for uid in unit_ids)
        cat_expense = sum(total_expense(db, business_unit_id=uid) for uid in unit_ids)
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
