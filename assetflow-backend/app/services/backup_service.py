"""
Generic backup/restore over every table registered on Base.metadata.

Export walks `Base.metadata.sorted_tables`, which SQLAlchemy already
orders so that a table never appears before the tables its foreign keys
point to -- restore reuses the same order for inserts, so parent rows
(business_units, accounts, etc.) always land before the child rows that
reference them, without hand-maintaining a table order.

Restore is idempotent: every table in this schema has a UUID `id` primary
key (via UUIDPKMixin), so a Postgres `ON CONFLICT (id) DO NOTHING` upsert
means re-running a restore never duplicates rows or errors on already-
present data.
"""
import json
import uuid
from datetime import date, datetime, time
from decimal import Decimal

from sqlalchemy import text
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.orm import Session

from app.core.database import Base


class _BackupJSONEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, (uuid.UUID,)):
            return str(obj)
        if isinstance(obj, (datetime, date, time)):
            return obj.isoformat()
        if isinstance(obj, Decimal):
            return float(obj)
        return super().default(obj)


def export_all(db: Session) -> dict:
    """Returns {table_name: [row_dict, ...]} for every table, FK-safe order preserved as dict insertion order."""
    data: dict[str, list[dict]] = {}
    for table in Base.metadata.sorted_tables:
        rows = db.execute(table.select()).mappings().all()
        data[table.name] = [dict(row) for row in rows]
    return data


def export_all_json_bytes(db: Session) -> bytes:
    payload = export_all(db)
    return json.dumps(payload, cls=_BackupJSONEncoder, indent=2).encode("utf-8")


def restore_all(db: Session, payload: dict) -> tuple[list[str], dict[str, int], list[str]]:
    """
    Restores from a payload produced by export_all(). Tables not present in
    the payload, or present but empty, are skipped (not truncated) --
    restore is additive/idempotent, never destructive, per Section 24
    ("financial data must be protected against accidental deletion").
    """
    restored_tables: list[str] = []
    row_counts: dict[str, int] = {}
    warnings: list[str] = []

    table_by_name = {t.name: t for t in Base.metadata.sorted_tables}

    for table in Base.metadata.sorted_tables:
        rows = payload.get(table.name)
        if not rows:
            continue
        if table.name not in table_by_name:
            warnings.append(f"Unknown table in backup: {table.name}, skipped.")
            continue

        inserted = 0
        for row in rows:
            # Re-hydrate UUID string columns back to uuid.UUID for the driver.
            clean_row = dict(row)
            stmt = pg_insert(table).values(**clean_row).on_conflict_do_nothing(index_elements=["id"])
            result = db.execute(stmt)
            inserted += result.rowcount or 0

        restored_tables.append(table.name)
        row_counts[table.name] = inserted

    db.commit()
    return restored_tables, row_counts, warnings


def table_row_counts(db: Session) -> dict[str, int]:
    counts = {}
    for table in Base.metadata.sorted_tables:
        count = db.execute(text(f'SELECT COUNT(*) FROM "{table.name}"')).scalar_one()
        counts[table.name] = count
    return counts
