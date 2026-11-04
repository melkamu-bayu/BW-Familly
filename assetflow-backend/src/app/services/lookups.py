"""Small existence checks that turn dangling foreign keys into clean 404s
(instead of a database IntegrityError / ValueError surfacing as a 500)."""
import uuid

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.business import BusinessUnit
from app.models.financial import Account


def require_account(db: Session, account_id: uuid.UUID) -> Account:
    account = db.get(Account, account_id)
    if account is None:
        raise HTTPException(status_code=404, detail="Account not found")
    return account


def require_business_unit(db: Session, business_unit_id: uuid.UUID) -> BusinessUnit:
    unit = db.get(BusinessUnit, business_unit_id)
    if unit is None or unit.deleted_at is not None:
        raise HTTPException(status_code=404, detail="Business unit not found")
    return unit
