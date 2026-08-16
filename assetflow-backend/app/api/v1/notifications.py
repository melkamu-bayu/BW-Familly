import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_user, require_permission
from app.models.identity import User
from app.models.support import Notification
from app.schemas.notifications import NotificationOut, NotificationGenerateResult
from app.services.notification_rules import run_all_rules

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("", response_model=list[NotificationOut])
def list_notifications(
    unread_only: bool = False,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    stmt = select(Notification).where(Notification.user_id == current_user.id)
    if unread_only:
        stmt = stmt.where(Notification.is_read.is_(False))
    stmt = stmt.order_by(Notification.created_at.desc())
    return db.execute(stmt).scalars().all()


@router.patch("/{notification_id}/read", response_model=NotificationOut)
def mark_read(
    notification_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    notif = db.get(Notification, notification_id)
    if notif is None or notif.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Notification not found")
    notif.is_read = True
    db.commit()
    db.refresh(notif)
    return notif


@router.post("/generate", response_model=NotificationGenerateResult)
def generate_notifications(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_permission("reports", "read")),
):
    """
    Runs every notification rule now (rent due/overdue, vehicle maintenance
    and document expiry, low inventory, unusual expense activity, daily
    summary). In production this endpoint is meant to be called by an
    external scheduler (cron / Celery beat) rather than a person -- it's
    exposed here so the rule engine can be triggered and tested without
    standing up a task queue first.
    """
    created_count, rule_names = run_all_rules(db)
    return NotificationGenerateResult(created_count=created_count, types_checked=rule_names)
