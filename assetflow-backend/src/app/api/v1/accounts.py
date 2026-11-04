import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import require_permission
from app.models.identity import User
from app.models.financial import Account, AccountTransfer
from app.schemas.financial import AccountOut, AccountTransferCreate
from app.services.audit_service import log_action
from app.services.financial_calculator import recompute_account_balance

router = APIRouter(prefix="/accounts", tags=["accounts"])


@router.get("", response_model=list[AccountOut])
def list_accounts(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("accounts", "read")),
):
    return db.execute(select(Account)).scalars().all()


@router.get("/{account_id}", response_model=AccountOut)
def get_account(
    account_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("accounts", "read")),
):
    account = db.get(Account, account_id)
    if account is None:
        raise HTTPException(status_code=404, detail="Account not found")
    return account


@router.post("/transfer", status_code=201)
def transfer_between_accounts(
    payload: AccountTransferCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("accounts", "update")),
):
    if payload.from_account_id == payload.to_account_id:
        raise HTTPException(status_code=400, detail="Cannot transfer to the same account")

    existing = db.execute(
        select(AccountTransfer).where(AccountTransfer.id == payload.idempotency_key)
    ).scalar_one_or_none()
    if existing is not None:
        return {"id": str(existing.id), "status": "already_applied"}

    from_account = db.get(Account, payload.from_account_id)
    to_account = db.get(Account, payload.to_account_id)
    if from_account is None or to_account is None:
        raise HTTPException(status_code=404, detail="Account not found")

    transfer = AccountTransfer(
        id=payload.idempotency_key,  # client-supplied UUID doubles as PK for natural idempotency
        from_account_id=payload.from_account_id,
        to_account_id=payload.to_account_id,
        amount=payload.amount,
        transfer_date=payload.transfer_date,
        created_by=current_user.id,
    )
    db.add(transfer)
    db.flush()

    log_action(
        db,
        user_id=current_user.id,
        entity_type="account_transfer",
        entity_id=transfer.id,
        action="create",
        new_value={"amount": str(payload.amount), "from": str(payload.from_account_id), "to": str(payload.to_account_id)},
    )

    recompute_account_balance(db, payload.from_account_id)
    recompute_account_balance(db, payload.to_account_id)

    db.commit()
    return {"id": str(transfer.id), "status": "applied"}
