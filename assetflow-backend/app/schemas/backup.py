from datetime import datetime

from pydantic import BaseModel


class BackupManifest(BaseModel):
    generated_at: datetime
    tables: list[str]
    row_counts: dict[str, int]


class RestoreResult(BaseModel):
    restored_tables: list[str]
    row_counts: dict[str, int]
    warnings: list[str]
