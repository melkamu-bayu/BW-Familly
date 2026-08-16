import uuid
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import require_permission
from app.models.identity import User
from app.models.financial import RevenueTransaction
from app.schemas.financial import RevenueCreate, RevenueOut
from app.services.transaction_code import generate_transaction_code
from app.services.audit_service import log_action
from app.services.financial_calculator import recompute_account_balance

router = APIRouter(prefix="/revenue", tags=["revenue"])


@router.post("", response_model=RevenueOut, status_code=201)
def create_revenue(
    payload: RevenueCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("revenue", "create")),
):
    # Idempotency: if this key was already processed (e.g. retried offline-sync push),
    # return the existing record rather than creating a duplicate.
    existing = db.execute(
        select(RevenueTransaction).where(RevenueTransaction.idempotency_key == payload.idempotency_key)
    ).scalar_one_or_none()
    if existing is not None:
        return existing

    code = generate_transaction_code(
        db, prefix="REV", table_name="revenue_transactions", code_column=RevenueTransaction.transaction_code
    )

    txn = RevenueTransaction(
        transaction_code=code,
        business_unit_id=payload.business_unit_id,
        account_id=payload.account_id,
        customer_id=payload.customer_id,
        category=payload.category,
        description=payload.description,
        amount=payload.amount,
        currency=payload.currency,
        payment_method=payload.payment_method,
        payment_status=payload.payment_status,
        reference_number=payload.reference_number,
        txn_date=payload.txn_date,
        idempotency_key=payload.idempotency_key,
        created_by=current_user.id,
    )
    db.add(txn)
    db.flush()  # get txn.id without committing yet

    log_action(
        db,
        user_id=current_user.id,
        entity_type="revenue_transaction",
        entity_id=txn.id,
        action="create",
        new_value={"amount": str(payload.amount), "category": payload.category, "business_unit_id": str(payload.business_unit_id)},
    )

    # Recompute the account balance in the SAME transaction, so revenue,
    # balance update, and audit log either all commit or all roll back together.
    recompute_account_balance(db, payload.account_id)

    db.commit()
    db.refresh(txn)
    return txn


@router.get("", response_model=list[RevenueOut])
def list_revenue(
    business_unit_id: uuid.UUID | None = None,
    category: str | None = None,
    payment_status: str | None = None,
    date_from: date | None = None,
    date_to: date | None = None,
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("revenue", "read")),
):
    stmt = select(RevenueTransaction).where(RevenueTransaction.deleted_at.is_(None))
    if business_unit_id:
        stmt = stmt.where(RevenueTransaction.business_unit_id == business_unit_id)
    if category:
        stmt = stmt.where(RevenueTransaction.category == category)
    if payment_status:
        stmt = stmt.where(RevenueTransaction.payment_status == payment_status)
    if date_from:
        stmt = stmt.where(RevenueTransaction.txn_date >= date_from)
    if date_to:
        stmt = stmt.where(RevenueTransaction.txn_date <= date_to)

    stmt = stmt.order_by(RevenueTransaction.txn_date.desc()).offset((page - 1) * per_page).limit(per_page)
    return db.execute(stmt).scalars().all()


@router.get("/{revenue_id}", response_model=RevenueOut)
def get_revenue(
    revenue_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("revenue", "read")),
):
    txn = db.get(RevenueTransaction, revenue_id)
    if txn is None or txn.deleted_at is not None:
        raise HTTPException(status_code=404, detail="Revenue transaction not found")
    return txn


@router.delete("/{revenue_id}", status_code=204)
def delete_revenue(
    revenue_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("revenue", "delete")),
):
    """Soft delete only -- financial records are never hard-deleted (Section 21)."""
    from datetime import datetime, timezone

    txn = db.get(RevenueTransaction, revenue_id)
    if txn is None or txn.deleted_at is not None:
        raise HTTPException(status_code=404, detail="Revenue transaction not found")

    previous = {"amount": str(txn.amount), "deleted_at": None}
    txn.deleted_at = datetime.now(timezone.utc)
    log_action(
        db,
        user_id=current_user.id,
        entity_type="revenue_transaction",
        entity_id=txn.id,
        action="delete",
        previous_value=previous,
        new_value={"deleted_at": txn.deleted_at.isoformat()},
    )
    recompute_account_balance(db, txn.account_id)
    db.commit()
