from datetime import date

from sqlalchemy import func, select, text
from sqlalchemy.orm import Session


def generate_transaction_code(db: Session, prefix: str, table_name: str, code_column) -> str:
    """
    Generates codes like 'REV-2026-000001'.

    The next number is derived from the highest existing code for that
    prefix+year (NOT the row count -- counting breaks as soon as any row has
    ever been removed, and then re-issues an existing code, which violates the
    UNIQUE constraint). A transaction-scoped advisory lock serializes
    concurrent writers for the same prefix+year so two requests can't both read
    the same maximum; it is released automatically on commit/rollback.
    """
    year = date.today().year
    stem = f"{prefix}-{year}-"

    db.execute(text("SELECT pg_advisory_xact_lock(hashtext(:k))"), {"k": f"txn-code:{stem}"})

    last_code = db.execute(
        select(func.max(code_column)).where(code_column.like(f"{stem}%"))
    ).scalar_one()

    last_seq = 0
    if last_code:
        try:
            last_seq = int(last_code.rsplit("-", 1)[1])
        except (IndexError, ValueError):
            last_seq = 0

    return f"{stem}{last_seq + 1:06d}"
