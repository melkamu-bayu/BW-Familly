import io
import json

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user
from app.models.identity import User, Role
from app.schemas.backup import BackupManifest, RestoreResult
from app.services.backup_service import export_all_json_bytes, restore_all, table_row_counts

router = APIRouter(prefix="/backup", tags=["backup"])


def _require_super_admin(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> User:
    role = db.get(Role, current_user.role_id)
    if role is None or role.name != "super_admin":
        raise HTTPException(status_code=403, detail="Only super_admin may access backup/restore")
    return current_user


@router.get("/manifest", response_model=BackupManifest)
def backup_manifest(
    db: Session = Depends(get_db),
    current_user: User = Depends(_require_super_admin),
):
    """Row counts per table, without downloading the full export -- useful for
    a quick 'does a backup make sense right now' sanity check."""
    from datetime import datetime, timezone

    counts = table_row_counts(db)
    return BackupManifest(generated_at=datetime.now(timezone.utc), tables=list(counts.keys()), row_counts=counts)


@router.get("/export")
def backup_export(
    db: Session = Depends(get_db),
    current_user: User = Depends(_require_super_admin),
):
    """Manual full-database export as JSON (Section 24). For automatic backups,
    schedule `pg_dump` against the database directly -- this endpoint is the
    in-app 'download a backup now' path, not a replacement for real DB-level backups."""
    content = export_all_json_bytes(db)
    return StreamingResponse(
        io.BytesIO(content),
        media_type="application/json",
        headers={"Content-Disposition": 'attachment; filename="assetflow-backup.json"'},
    )


@router.post("/restore", response_model=RestoreResult)
def backup_restore(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(_require_super_admin),
):
    """
    Restores from a JSON export produced by /backup/export. Additive only --
    existing rows are never overwritten or deleted (ON CONFLICT DO NOTHING),
    so restoring a backup can never destroy data created since that backup.
    """
    try:
        payload = json.loads(file.file.read())
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=400, detail=f"Invalid backup file: {exc}")

    if not isinstance(payload, dict):
        raise HTTPException(status_code=400, detail="Backup file must be a JSON object of {table_name: [rows]}")

    restored_tables, row_counts, warnings = restore_all(db, payload)
    return RestoreResult(restored_tables=restored_tables, row_counts=row_counts, warnings=warnings)
