import io
from collections import defaultdict
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import StreamingResponse
from sqlalchemy import select, func
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import require_permission
from app.models.identity import User
from app.models.business import BusinessUnit, BusinessCategory
from app.models.financial import RevenueTransaction, ExpenseTransaction
from app.models.shop import Customer, Supplier
from app.schemas.reports import (
    ProfitLossReport,
    ProfitLossLine,
    CashFlowReport,
    CashFlowPoint,
    ReceivableLine,
    PayableLine,
)
from app.services.financial_calculator import total_revenue, total_expense
from app.services.export_service import to_csv_bytes, to_xlsx_bytes, to_pdf_bytes, CONTENT_TYPES

router = APIRouter(prefix="/reports", tags=["reports"])


# ---------- Profit & Loss ----------

@router.get("/profit-loss", response_model=ProfitLossReport)
def profit_loss(
    date_from: date | None = None,
    date_to: date | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("reports", "read")),
):
    """Consolidated P&L plus a breakdown by business category (Section 14)."""
    consolidated_revenue = total_revenue(db, date_from=date_from, date_to=date_to)
    consolidated_expense = total_expense(db, date_from=date_from, date_to=date_to)

    categories = db.execute(select(BusinessCategory)).scalars().all()
    by_category = []
    for category in categories:
        unit_ids = [
            u.id for u in db.execute(select(BusinessUnit).where(BusinessUnit.category_id == category.id)).scalars().all()
        ]
        rev = sum(total_revenue(db, business_unit_id=uid, date_from=date_from, date_to=date_to) for uid in unit_ids)
        exp = sum(total_expense(db, business_unit_id=uid, date_from=date_from, date_to=date_to) for uid in unit_ids)
        by_category.append(ProfitLossLine(label=category.name, revenue=rev, expenses=exp, profit=rev - exp))

    return ProfitLossReport(
        period_from=date_from,
        period_to=date_to,
        consolidated=ProfitLossLine(
            label="Consolidated",
            revenue=consolidated_revenue,
            expenses=consolidated_expense,
            profit=consolidated_revenue - consolidated_expense,
        ),
        by_category=by_category,
    )


@router.get("/profit-loss/by-asset", response_model=list[ProfitLossLine])
def profit_loss_by_asset(
    date_from: date | None = None,
    date_to: date | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("reports", "read")),
):
    """P&L for every individual asset -- the six vehicles, two houses, the shop,
    and the Gold-Mining Project (Section 14 'By Asset')."""
    units = db.execute(select(BusinessUnit).where(BusinessUnit.deleted_at.is_(None))).scalars().all()
    lines = []
    for unit in units:
        rev = total_revenue(db, business_unit_id=unit.id, date_from=date_from, date_to=date_to)
        exp = total_expense(db, business_unit_id=unit.id, date_from=date_from, date_to=date_to)
        lines.append(ProfitLossLine(label=unit.name, revenue=rev, expenses=exp, profit=rev - exp))
    return lines


# ---------- Cash Flow ----------

@router.get("/cash-flow", response_model=CashFlowReport)
def cash_flow(
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

    inflows: dict[str, float] = defaultdict(float)
    outflows: dict[str, float] = defaultdict(float)

    revenue_rows = db.execute(
        select(RevenueTransaction.txn_date, RevenueTransaction.amount).where(
            RevenueTransaction.deleted_at.is_(None),
            RevenueTransaction.txn_date >= date_from,
            RevenueTransaction.txn_date <= date_to,
        )
    ).all()
    for txn_date, amount in revenue_rows:
        inflows[bucket_key(txn_date)] += float(amount)

    expense_rows = db.execute(
        select(ExpenseTransaction.txn_date, ExpenseTransaction.amount).where(
            ExpenseTransaction.deleted_at.is_(None),
            ExpenseTransaction.txn_date >= date_from,
            ExpenseTransaction.txn_date <= date_to,
        )
    ).all()
    for txn_date, amount in expense_rows:
        outflows[bucket_key(txn_date)] += float(amount)

    all_keys = sorted(set(inflows) | set(outflows))
    points = [
        CashFlowPoint(period_label=k, inflow=inflows.get(k, 0.0), outflow=outflows.get(k, 0.0),
                       net=inflows.get(k, 0.0) - outflows.get(k, 0.0))
        for k in all_keys
    ]
    total_in = sum(p.inflow for p in points)
    total_out = sum(p.outflow for p in points)

    return CashFlowReport(
        period_from=date_from, period_to=date_to, group_by=group_by, points=points,
        total_inflow=total_in, total_outflow=total_out, net_cash_flow=total_in - total_out,
    )


# ---------- Receivables / Payables ----------

@router.get("/receivables", response_model=list[ReceivableLine])
def receivables(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("reports", "read")),
):
    customers = db.execute(select(Customer).where(Customer.outstanding_balance > 0)).scalars().all()
    return [
        ReceivableLine(customer_id=c.id, customer_name=c.name, outstanding_balance=float(c.outstanding_balance))
        for c in customers
    ]


@router.get("/payables", response_model=list[PayableLine])
def payables(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("reports", "read")),
):
    suppliers = db.execute(select(Supplier).where(Supplier.outstanding_payable > 0)).scalars().all()
    return [
        PayableLine(supplier_id=s.id, supplier_name=s.name, outstanding_payable=float(s.outstanding_payable))
        for s in suppliers
    ]


# ---------- Export ----------

@router.get("/export")
def export_report(
    report: str = Query(..., pattern="^(revenue|expense|profit-loss)$"),
    format: str = Query(..., pattern="^(csv|xlsx|pdf)$"),
    date_from: date | None = None,
    date_to: date | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("reports", "read")),
):
    """
    Exports the requested report as CSV, Excel, or PDF (Section 15).
    `report=revenue|expense` exports the raw transaction list; `report=profit-loss`
    exports the by-category P&L breakdown.
    """
    if report in ("revenue", "expense"):
        model = RevenueTransaction if report == "revenue" else ExpenseTransaction
        stmt = select(model).where(model.deleted_at.is_(None))
        if date_from:
            stmt = stmt.where(model.txn_date >= date_from)
        if date_to:
            stmt = stmt.where(model.txn_date <= date_to)
        stmt = stmt.order_by(model.txn_date.desc())
        rows_db = db.execute(stmt).scalars().all()

        headers = ["Transaction Code", "Date", "Category", "Description", "Amount", "Currency", "Payment Status"]
        rows = [
            [r.transaction_code, r.txn_date.isoformat(), r.category, r.description or "", float(r.amount), r.currency, r.payment_status]
            for r in rows_db
        ]
        title = f"{report.capitalize()} Report"
    else:
        plr = profit_loss(date_from=date_from, date_to=date_to, db=db, current_user=current_user)
        headers = ["Category", "Revenue", "Expenses", "Profit"]
        rows = [[line.label, line.revenue, line.expenses, line.profit] for line in plr.by_category]
        rows.append(["TOTAL", plr.consolidated.revenue, plr.consolidated.expenses, plr.consolidated.profit])
        title = "Profit & Loss Report"

    if format == "csv":
        content = to_csv_bytes(headers, rows)
    elif format == "xlsx":
        content = to_xlsx_bytes(headers, rows, sheet_title=title)
    else:
        subtitle = f"{date_from or 'inception'} to {date_to or 'today'}"
        content = to_pdf_bytes(title, headers, rows, subtitle=subtitle)

    filename = f"{report}-report.{format}"
    return StreamingResponse(
        io.BytesIO(content),
        media_type=CONTENT_TYPES[format],
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )
