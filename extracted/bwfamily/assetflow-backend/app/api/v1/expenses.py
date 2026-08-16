import uuid
from datetime import date, datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import require_permission
from app.models.identity import User
from app.models.financial import ExpenseTransaction
from app.schemas.financial import ExpenseCreate, ExpenseOut
from app.services.transaction_code import generate_transaction_code
from app.services.audit_service import log_action
from app.services.financial_calculator import recompute_account_balance

router = APIRouter(prefix="/expenses", tags=["expenses"])


@router.post("", response_model=ExpenseOut, status_code=201)
def create_expense(
    payload: ExpenseCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("expense", "create")),
):
    existing = db.execute(
        select(ExpenseTransaction).where(ExpenseTransaction.idempotency_key == payload.idempotency_key)
    ).scalar_one_or_none()
    if existing is not None:
        return existing

    code = generate_transaction_code(
        db, prefix="EXP", table_name="expense_transactions", code_column=ExpenseTransaction.transaction_code
    )

    txn = ExpenseTransaction(
        transaction_code=code,
        business_unit_id=payload.business_unit_id,
        account_id=payload.account_id,
        supplier_id=payload.supplier_id,
        category=payload.category,
        description=payload.description,
        amount=payload.amount,
        currency=payload.currency,
        payment_method=payload.payment_method,
        payment_status=payload.payment_status,
        invoice_number=payload.invoice_number,
        txn_date=payload.txn_date,
        idempotency_key=payload.idempotency_key,
        created_by=current_user.id,
    )
    db.add(txn)
    db.flush()

    log_action(
        db,
        user_id=current_user.id,
        entity_type="expense_transaction",
        entity_id=txn.id,
        action="create",
        new_value={"amount": str(payload.amount), "category": payload.category, "business_unit_id": str(payload.business_unit_id)},
    )
    recompute_account_balance(db, payload.account_id)

    db.commit()
    db.refresh(txn)
    return txn


@router.get("", response_model=list[ExpenseOut])
def list_expenses(
    business_unit_id: uuid.UUID | None = None,
    category: str | None = None,
    payment_status: str | None = None,
    date_from: date | None = None,
    date_to: date | None = None,
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("expense", "read")),
):
    stmt = select(ExpenseTransaction).where(ExpenseTransaction.deleted_at.is_(None))
    if business_unit_id:
        stmt = stmt.where(ExpenseTransaction.business_unit_id == business_unit_id)
    if category:
        stmt = stmt.where(ExpenseTransaction.category == category)
    if payment_status:
        stmt = stmt.where(ExpenseTransaction.payment_status == payment_status)
    if date_from:
        stmt = stmt.where(ExpenseTransaction.txn_date >= date_from)
    if date_to:
        stmt = stmt.where(ExpenseTransaction.txn_date <= date_to)

    stmt = stmt.order_by(ExpenseTransaction.txn_date.desc()).offset((page - 1) * per_page).limit(per_page)
    return db.execute(stmt).scalars().all()


@router.get("/{expense_id}", response_model=ExpenseOut)
def get_expense(
    expense_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("expense", "read")),
):
    txn = db.get(ExpenseTransaction, expense_id)
    if txn is None or txn.deleted_at is not None:
        raise HTTPException(status_code=404, detail="Expense transaction not found")
    return txn


@router.delete("/{expense_id}", status_code=204)
def delete_expense(
    expense_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("expense", "delete")),
):
    txn = db.get(ExpenseTransaction, expense_id)
    if txn is None or txn.deleted_at is not None:
        raise HTTPException(status_code=404, detail="Expense transaction not found")

    previous = {"amount": str(txn.amount), "deleted_at": None}
    txn.deleted_at = datetime.now(timezone.utc)
    log_action(
        db,
        user_id=current_user.id,
        entity_type="expense_transaction",
        entity_id=txn.id,
        action="delete",
        previous_value=previous,
        new_value={"deleted_at": txn.deleted_at.isoformat()},
    )
    recompute_account_balance(db, txn.account_id)
    db.commit()
