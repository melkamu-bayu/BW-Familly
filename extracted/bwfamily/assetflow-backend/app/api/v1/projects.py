import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select

from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import require_permission
from app.models.identity import User
from app.models.business import BusinessUnit, Project
from app.models.financial import ProjectTransaction, ExpenseTransaction, RevenueTransaction
from app.schemas.project import (
    ProjectTransactionCreate,
    ProjectTransactionOut,
    ProjectStatusUpdate,
    ProjectDashboard,
)
from app.services.audit_service import log_action
from app.services.transaction_code import generate_transaction_code
from app.services.financial_calculator import recompute_account_balance, project_roi

router = APIRouter(prefix="/projects", tags=["projects"])


def _get_project(db: Session) -> Project:
    """
    Section 31 seeds exactly one project (Gold-Mining Project). This helper
    resolves it directly; if/when multiple projects are supported, swap this
    for a /projects/{project_id} path parameter -- the underlying data model
    already supports many projects per business_units/projects tables.
    """
    project = db.execute(select(Project)).scalars().first()
    if project is None:
        raise HTTPException(status_code=500, detail="Gold-Mining Project not seeded")
    return project


@router.get("/gold-mining")
def get_gold_mining_project(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("projects", "read")),
):
    project = _get_project(db)
    unit = db.get(BusinessUnit, project.business_unit_id)
    return {
        "id": str(project.id),
        "business_unit_id": str(project.business_unit_id),
        "name": unit.name,
        "status": project.status,
        "initial_investment": float(project.initial_investment),
        "additional_investment": float(project.additional_investment),
    }


@router.patch("/gold-mining/status")
def update_project_status(
    payload: ProjectStatusUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("projects", "update")),
):
    project = _get_project(db)
    previous_status = project.status
    project.status = payload.status
    log_action(db, user_id=current_user.id, entity_type="project", entity_id=project.id, action="update",
               previous_value={"status": previous_status}, new_value={"status": payload.status})
    db.commit()
    return {"id": str(project.id), "status": project.status}


@router.post("/gold-mining/transactions", response_model=ProjectTransactionOut, status_code=201)
def add_project_transaction(
    payload: ProjectTransactionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("projects", "create")),
):
    """
    Records an investment, expense, or revenue entry against the project.
    - 'investment' increases the project's tracked investment total directly.
    - 'expense'/'revenue' additionally post to the shared expense/revenue
      pipeline (when account_id is given) so account balances and the
      consolidated P&L stay in sync automatically (Section 13).
    """
    project = _get_project(db)

    txn = ProjectTransaction(
        project_id=project.id,
        txn_type=payload.txn_type,
        category=payload.category,
        amount=payload.amount,
        txn_date=payload.txn_date,
        created_by=current_user.id,
    )
    db.add(txn)
    db.flush()

    if payload.txn_type == "investment":
        project.additional_investment = float(project.additional_investment) + payload.amount

    elif payload.txn_type == "expense" and payload.account_id:
        existing = db.execute(
            select(ExpenseTransaction).where(ExpenseTransaction.idempotency_key == payload.idempotency_key)
        ).scalar_one_or_none()
        if existing is None:
            code = generate_transaction_code(db, prefix="EXP", table_name="expense_transactions",
                                              code_column=ExpenseTransaction.transaction_code)
            db.add(ExpenseTransaction(
                transaction_code=code,
                business_unit_id=project.business_unit_id,
                account_id=payload.account_id,
                category=payload.category or "project_expense",
                description=f"Gold-Mining Project expense: {payload.category or 'other'}",
                amount=payload.amount,
                txn_date=payload.txn_date,
                idempotency_key=payload.idempotency_key,
                created_by=current_user.id,
            ))
            db.flush()
            recompute_account_balance(db, payload.account_id)

    elif payload.txn_type == "revenue" and payload.account_id:
        existing = db.execute(
            select(RevenueTransaction).where(RevenueTransaction.idempotency_key == payload.idempotency_key)
        ).scalar_one_or_none()
        if existing is None:
            code = generate_transaction_code(db, prefix="REV", table_name="revenue_transactions",
                                              code_column=RevenueTransaction.transaction_code)
            db.add(RevenueTransaction(
                transaction_code=code,
                business_unit_id=project.business_unit_id,
                account_id=payload.account_id,
                category=payload.category or "gold_sales",
                description=f"Gold-Mining Project revenue: {payload.category or 'other'}",
                amount=payload.amount,
                txn_date=payload.txn_date,
                idempotency_key=payload.idempotency_key,
                created_by=current_user.id,
            ))
            db.flush()
            recompute_account_balance(db, payload.account_id)

    log_action(db, user_id=current_user.id, entity_type="project_transaction", entity_id=txn.id, action="create",
               new_value={"txn_type": payload.txn_type, "amount": str(payload.amount)})
    db.commit()
    db.refresh(txn)
    return txn


@router.get("/gold-mining/transactions", response_model=list[ProjectTransactionOut])
def list_project_transactions(
    txn_type: str | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("projects", "read")),
):
    project = _get_project(db)
    stmt = select(ProjectTransaction).where(ProjectTransaction.project_id == project.id)
    if txn_type:
        stmt = stmt.where(ProjectTransaction.txn_type == txn_type)
    stmt = stmt.order_by(ProjectTransaction.txn_date.desc())
    return db.execute(stmt).scalars().all()


@router.get("/gold-mining/dashboard", response_model=ProjectDashboard)
def project_dashboard(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("projects", "read")),
):
    from sqlalchemy import func as sa_func

    project = _get_project(db)
    unit = db.get(BusinessUnit, project.business_unit_id)

    def _sum(txn_type: str) -> float:
        return float(
            db.execute(
                select(sa_func.coalesce(sa_func.sum(ProjectTransaction.amount), 0)).where(
                    ProjectTransaction.project_id == project.id, ProjectTransaction.txn_type == txn_type
                )
            ).scalar_one()
        )

    total_expenses = _sum("expense")
    total_revenue = _sum("revenue")
    net = total_revenue - total_expenses
    total_investment = float(project.initial_investment) + float(project.additional_investment)

    return ProjectDashboard(
        project_id=project.id,
        name=unit.name,
        status=project.status,
        total_investment=total_investment,
        total_expenses=total_expenses,
        total_revenue=total_revenue,
        net_profit=net,
        cash_used=total_expenses,
        roi=project_roi(float(project.initial_investment), float(project.additional_investment), net),
    )
