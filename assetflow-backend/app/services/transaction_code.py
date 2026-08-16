from datetime import date

from sqlalchemy import func, select
from sqlalchemy.orm import Session

_PREFIX_MODEL_MAP = {
    "REV": "revenue_transactions",
    "EXP": "expense_transactions",
    "SALE": "sales",
    "PUR": "purchases",
    "PAY": "payments",
}


def generate_transaction_code(db: Session, prefix: str, table_name: str, code_column) -> str:
    """
    Generates codes like 'REV-2026-000001'.

    Uses a per-year sequential counter derived from the count of existing rows
    for that year+prefix, wrapped in the caller's DB transaction with a
    SELECT ... FOR UPDATE-style lock is avoided here for simplicity; for high
    concurrency, replace with a dedicated `sequence_counters` table using
    SELECT ... FOR UPDATE to prevent race conditions on the count.
    """
    year = date.today().year
    like_pattern = f"{prefix}-{year}-%"

    count = db.execute(
        select(func.count()).select_from(code_column.table).where(code_column.like(like_pattern))
    ).scalar_one()

    next_seq = count + 1
    return f"{prefix}-{year}-{next_seq:06d}"
