from collections import defaultdict
from datetime import date, timedelta

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import require_permission
from app.models.identity import User
from app.models.business import BusinessUnit
from app.models.financial import RevenueTransaction, ExpenseTransaction, RentalTransaction
from app.models.shop import Product
from app.schemas.reports import TrendReport, TrendPoint, Insight
from app.services.financial_calculator import total_revenue, total_expense, shop_gross_profit

router = APIRouter(prefix="/analytics", tags=["analytics"])


@router.get("/trends", response_model=TrendReport)
def revenue_expense_trend(
    date_from: date,
    date_to: date,
    group_by: str = Query("month", pattern="^(day|week|month)$"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("reports", "read")),
):
    def bucket_key(d: date) -> str:
        if group_by == "day":
            return d.isoformat()
        if group_by == "week":
            iso = d.isocalendar()
            return f"{iso.year}-W{iso.week:02d}"
        return d.strftime("%Y-%m")

    revenue_by_bucket: dict[str, float] = defaultdict(float)
    expense_by_bucket: dict[str, float] = defaultdict(float)

    for txn_date, amount in db.execute(
        select(RevenueTransaction.txn_date, RevenueTransaction.amount).where(
            RevenueTransaction.deleted_at.is_(None),
            RevenueTransaction.txn_date >= date_from,
            RevenueTransaction.txn_date <= date_to,
        )
    ).all():
        revenue_by_bucket[bucket_key(txn_date)] += float(amount)

    for txn_date, amount in db.execute(
        select(ExpenseTransaction.txn_date, ExpenseTransaction.amount).where(
            ExpenseTransaction.deleted_at.is_(None),
            ExpenseTransaction.txn_date >= date_from,
            ExpenseTransaction.txn_date <= date_to,
        )
    ).all():
        expense_by_bucket[bucket_key(txn_date)] += float(amount)

    all_keys = sorted(set(revenue_by_bucket) | set(expense_by_bucket))
    points = [
        TrendPoint(
            period_label=k,
            revenue=revenue_by_bucket.get(k, 0.0),
            expense=expense_by_bucket.get(k, 0.0),
            profit=revenue_by_bucket.get(k, 0.0) - expense_by_bucket.get(k, 0.0),
        )
        for k in all_keys
    ]
    return TrendReport(metric_group_by=group_by, points=points)


@router.get("/insights", response_model=list[Insight])
def insights(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("reports", "read")),
):
    """
    Rule-based insights generated directly from stored data (Section 16/33).
    Every figure quoted here is computed live from the database -- nothing
    is inferred or invented, satisfying "AI must never invent financial figures."
    """
    out: list[Insight] = []
    today = date.today()
    this_month_start = today.replace(day=1)
    last_month_end = this_month_start - timedelta(days=1)
    last_month_start = last_month_end.replace(day=1)

    # --- Vehicles: highest revenue / highest profit / highest expenses this month ---
    vehicle_units = db.execute(
        select(BusinessUnit).where(BusinessUnit.unit_type == "vehicle", BusinessUnit.deleted_at.is_(None))
    ).scalars().all()

    if vehicle_units:
        stats = []
        for unit in vehicle_units:
            rev = total_revenue(db, business_unit_id=unit.id, date_from=this_month_start, date_to=today)
            exp = total_expense(db, business_unit_id=unit.id, date_from=this_month_start, date_to=today)
            stats.append((unit.name, rev, exp, rev - exp))

        if any(rev for _, rev, _, _ in stats):
            top_revenue = max(stats, key=lambda s: s[1])
            if top_revenue[1] > 0:
                out.append(Insight(
                    text=f"{top_revenue[0]} generated the highest vehicle revenue this month (ETB {top_revenue[1]:,.2f}).",
                    category="vehicles",
                ))

        if any(profit for _, _, _, profit in stats):
            top_profit = max(stats, key=lambda s: s[3])
            if top_profit[3] > 0:
                out.append(Insight(
                    text=f"{top_profit[0]} generated the highest vehicle profit this month (ETB {top_profit[3]:,.2f}).",
                    category="vehicles",
                ))

        if any(exp for _, _, exp, _ in stats):
            top_expense = max(stats, key=lambda s: s[2])
            if top_expense[2] > 0:
                out.append(Insight(
                    text=f"{top_expense[0]} has the highest vehicle expenses this month (ETB {top_expense[2]:,.2f}).",
                    category="vehicles",
                ))

        # Fuel expense trend: this month vs last month, across all vehicles
        fuel_this_month = sum(
            total_expense(db, business_unit_id=u.id, date_from=this_month_start, date_to=today) for u in vehicle_units
        )
        fuel_last_month = sum(
            total_expense(db, business_unit_id=u.id, date_from=last_month_start, date_to=last_month_end) for u in vehicle_units
        )
        if fuel_last_month > 0 and fuel_this_month > fuel_last_month:
            pct = (fuel_this_month - fuel_last_month) / fuel_last_month * 100
            out.append(Insight(
                text=f"Vehicle expenses increased {pct:.1f}% compared with last month.",
                category="vehicles",
                severity="warning",
            ))

    # --- Rental Houses: outstanding rent ---
    property_units = db.execute(
        select(BusinessUnit).where(BusinessUnit.unit_type == "property", BusinessUnit.deleted_at.is_(None))
    ).scalars().all()
    from app.models.business import Property as PropertyModel

    for unit in property_units:
        prop = db.execute(select(PropertyModel).where(PropertyModel.business_unit_id == unit.id)).scalar_one_or_none()
        if prop is None:
            continue
        outstanding = db.execute(
            select(RentalTransaction).where(
                RentalTransaction.property_id == prop.id, RentalTransaction.status.in_(["outstanding", "partial"])
            )
        ).scalars().all()
        total_outstanding = sum(float(rt.amount_due) - float(rt.amount_paid) for rt in outstanding)
        if total_outstanding > 0:
            out.append(Insight(
                text=f"{unit.name} has outstanding rent of ETB {total_outstanding:,.2f}.",
                category="properties",
                severity="warning",
            ))

    # --- Shop: gross profit standing (only one shop unit exists, but written generically) ---
    shop_units = db.execute(
        select(BusinessUnit).where(BusinessUnit.unit_type == "shop", BusinessUnit.deleted_at.is_(None))
    ).scalars().all()
    if shop_units:
        best_shop = max(
            ((u, shop_gross_profit(db, u.id, this_month_start, today)) for u in shop_units),
            key=lambda pair: pair[1],
        )
        if best_shop[1] > 0:
            out.append(Insight(
                text=f"{best_shop[0].name} generated a gross profit of ETB {best_shop[1]:,.2f} this month.",
                category="shop",
            ))

    # --- Shop: low stock ---
    low_stock_products = db.execute(select(Product).where(Product.deleted_at.is_(None))).scalars().all()
    low_stock = [p for p in low_stock_products if float(p.current_quantity) <= float(p.min_stock_level)]
    if low_stock:
        names = ", ".join(p.name for p in low_stock[:5])
        more = f" and {len(low_stock) - 5} more" if len(low_stock) > 5 else ""
        out.append(Insight(
            text=f"{len(low_stock)} product(s) are at or below minimum stock level: {names}{more}.",
            category="shop",
            severity="warning",
        ))

    if not out:
        out.append(Insight(text="Not enough transaction history yet to generate insights.", category="general"))

    return out
