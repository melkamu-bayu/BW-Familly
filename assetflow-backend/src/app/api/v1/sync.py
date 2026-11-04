from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import require_permission
from app.models.identity import User
from app.models.financial import RevenueTransaction, ExpenseTransaction
from app.schemas.sync import (
    SyncPushRequest,
    SyncPushResponse,
    SyncPushResult,
    SyncPullResponse,
)
from app.services.transaction_code import generate_transaction_code
from app.services.audit_service import log_action
from app.services.financial_calculator import recompute_account_balance

router = APIRouter(prefix="/sync", tags=["sync"])


@router.post("/push", response_model=SyncPushResponse)
def sync_push(
    payload: SyncPushRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("revenue", "create")),
):
    """
    Applies a batch of offline-queued revenue/expense records.

    Each item is applied inside its own SAVEPOINT (nested transaction) so a
    single malformed or conflicting item is rejected without discarding the
    rest of the batch -- required by Section 18 ("never lose a transaction
    because of temporary network failure") combined with Section 9's need
    to not lose an entire sync batch over one bad row.

    Idempotency: if `idempotency_key` was already applied (e.g. this is a
    retried push after a dropped response), the existing record is returned
    as `duplicate` rather than reapplied.
    """
    results: list[SyncPushResult] = []

    for item in payload.items:
        savepoint = db.begin_nested()
        try:
            if item.entity_type == "revenue":
                p = item.payload
                existing = db.execute(
                    select(RevenueTransaction).where(RevenueTransaction.idempotency_key == p.idempotency_key)
                ).scalar_one_or_none()
                if existing is not None:
                    savepoint.rollback()
                    results.append(SyncPushResult(
                        idempotency_key=p.idempotency_key, entity_type="revenue", status="duplicate",
                        server_id=existing.id, transaction_code=existing.transaction_code,
                    ))
                    continue

                code = generate_transaction_code(db, prefix="REV", table_name="revenue_transactions",
                                                  code_column=RevenueTransaction.transaction_code)
                txn = RevenueTransaction(
                    transaction_code=code,
                    business_unit_id=p.business_unit_id,
                    account_id=p.account_id,
                    customer_id=p.customer_id,
                    category=p.category,
                    description=p.description,
                    amount=p.amount,
                    currency=p.currency,
                    payment_method=p.payment_method,
                    payment_status=p.payment_status,
                    reference_number=p.reference_number,
                    txn_date=p.txn_date,
                    idempotency_key=p.idempotency_key,
                    created_by=current_user.id,
                )
                db.add(txn)
                db.flush()
                log_action(db, user_id=current_user.id, entity_type="revenue_transaction", entity_id=txn.id,
                           action="create", new_value={"amount": str(p.amount), "source": "offline_sync"})
                recompute_account_balance(db, p.account_id)
                savepoint.commit()
                results.append(SyncPushResult(
                    idempotency_key=p.idempotency_key, entity_type="revenue", status="applied",
                    server_id=txn.id, transaction_code=txn.transaction_code,
                ))

            else:  # expense
                p = item.payload
                existing = db.execute(
                    select(ExpenseTransaction).where(ExpenseTransaction.idempotency_key == p.idempotency_key)
                ).scalar_one_or_none()
                if existing is not None:
                    savepoint.rollback()
                    results.append(SyncPushResult(
                        idempotency_key=p.idempotency_key, entity_type="expense", status="duplicate",
                        server_id=existing.id, transaction_code=existing.transaction_code,
                    ))
                    continue

                code = generate_transaction_code(db, prefix="EXP", table_name="expense_transactions",
                                                  code_column=ExpenseTransaction.transaction_code)
                txn = ExpenseTransaction(
                    transaction_code=code,
                    business_unit_id=p.business_unit_id,
                    account_id=p.account_id,
                    supplier_id=p.supplier_id,
                    category=p.category,
                    description=p.description,
                    amount=p.amount,
                    currency=p.currency,
                    payment_method=p.payment_method,
                    payment_status=p.payment_status,
                    invoice_number=p.invoice_number,
                    txn_date=p.txn_date,
                    idempotency_key=p.idempotency_key,
                    created_by=current_user.id,
                )
                db.add(txn)
                db.flush()
                log_action(db, user_id=current_user.id, entity_type="expense_transaction", entity_id=txn.id,
                           action="create", new_value={"amount": str(p.amount), "source": "offline_sync"})
                recompute_account_balance(db, p.account_id)
                savepoint.commit()
                results.append(SyncPushResult(
                    idempotency_key=p.idempotency_key, entity_type="expense", status="applied",
                    server_id=txn.id, transaction_code=txn.transaction_code,
                ))

        except Exception as exc:  # noqa: BLE001 -- deliberately broad: one bad item must not sink the batch
            savepoint.rollback()
            key = item.payload.idempotency_key
            results.append(SyncPushResult(
                idempotency_key=key, entity_type=item.entity_type, status="rejected", error=str(exc),
            ))

    db.commit()
    return SyncPushResponse(results=results)


@router.get("/pull", response_model=SyncPullResponse)
def sync_pull(
    since: datetime = Query(..., description="ISO timestamp; returns records created after this point"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("revenue", "read")),
):
    """
    Server-authoritative delta feed. The mobile client stores `server_time`
    from the response as its new watermark for the next pull, rather than
    using its own clock, to avoid drift between device and server time.
    """
    revenue_rows = db.execute(
        select(RevenueTransaction).where(
            RevenueTransaction.created_at > since, RevenueTransaction.deleted_at.is_(None)
        )
    ).scalars().all()
    expense_rows = db.execute(
        select(ExpenseTransaction).where(
            ExpenseTransaction.created_at > since, ExpenseTransaction.deleted_at.is_(None)
        )
    ).scalars().all()

    def revenue_dict(r: RevenueTransaction) -> dict:
        return {
            "id": str(r.id),
            "transaction_code": r.transaction_code,
            "business_unit_id": str(r.business_unit_id),
            "account_id": str(r.account_id),
            "category": r.category,
            "amount": float(r.amount),
            "txn_date": r.txn_date.isoformat(),
            "created_at": r.created_at.isoformat(),
        }

    def expense_dict(e: ExpenseTransaction) -> dict:
        return {
            "id": str(e.id),
            "transaction_code": e.transaction_code,
            "business_unit_id": str(e.business_unit_id),
            "account_id": str(e.account_id),
            "category": e.category,
            "amount": float(e.amount),
            "txn_date": e.txn_date.isoformat(),
            "created_at": e.created_at.isoformat(),
        }

    return SyncPullResponse(
        server_time=datetime.now(timezone.utc),
        revenue=[revenue_dict(r) for r in revenue_rows],
        expenses=[expense_dict(e) for e in expense_rows],
    )
