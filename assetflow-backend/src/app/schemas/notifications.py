import uuid
from datetime import datetime

from pydantic import BaseModel


class NotificationOut(BaseModel):
    id: uuid.UUID
    type: str
    title: str | None
    body: str | None
    is_read: bool
    created_at: datetime

    model_config = {"from_attributes": True}


class NotificationGenerateResult(BaseModel):
    created_count: int
    types_checked: list[str]
