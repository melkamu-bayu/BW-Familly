import uuid

from sqlalchemy.orm import Session

from app.models.support import AuditLog


def log_action(
    db: Session,
    *,
    user_id: uuid.UUID | None,
    entity_type: str,
    entity_id: uuid.UUID,
    action: str,
    previous_value: dict | None = None,
    new_value: dict | None = None,
) -> AuditLog:
    """
    Adds an AuditLog row to the current session WITHOUT committing.
    Callers must commit as part of the same transaction as the actual
    mutation, so a change can never exist without its audit trail.
    """
    entry = AuditLog(
        user_id=user_id,
        entity_type=entity_type,
        entity_id=entity_id,
        action=action,
        previous_value=previous_value,
        new_value=new_value,
    )
    db.add(entry)
    return entry
