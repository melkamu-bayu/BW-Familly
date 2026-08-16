import uuid

from sqlalchemy import String, Boolean, ForeignKey, UniqueConstraint, DateTime, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.models.mixins import UUIDPKMixin, TimestampMixin, SoftDeleteMixin


class Role(Base, UUIDPKMixin):
    __tablename__ = "roles"

    name: Mapped[str] = mapped_column(String(50), unique=True, nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)

    permissions: Mapped[list["Permission"]] = relationship(back_populates="role")
    users: Mapped[list["User"]] = relationship(back_populates="role")


class Permission(Base, UUIDPKMixin):
    __tablename__ = "permissions"
    __table_args__ = (UniqueConstraint("role_id", "resource", "action", name="uq_role_resource_action"),)

    role_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("roles.id"))
    resource: Mapped[str] = mapped_column(String(100), nullable=False)  # e.g. "revenue"
    action: Mapped[str] = mapped_column(String(20), nullable=False)     # create/read/update/delete/approve

    role: Mapped["Role"] = relationship(back_populates="permissions")


class User(Base, UUIDPKMixin, TimestampMixin, SoftDeleteMixin):
    __tablename__ = "users"

    full_name: Mapped[str] = mapped_column(String(150), nullable=False)
    email: Mapped[str] = mapped_column(String(150), unique=True, nullable=False, index=True)
    phone: Mapped[str | None] = mapped_column(String(30), nullable=True)
    password_hash: Mapped[str] = mapped_column(Text, nullable=False)
    role_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("roles.id"), nullable=False)
    biometric_enabled: Mapped[bool] = mapped_column(Boolean, default=False)
    pin_hash: Mapped[str | None] = mapped_column(Text, nullable=True)
    active: Mapped[bool] = mapped_column(Boolean, default=True)
    last_login_at: Mapped[DateTime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    role: Mapped["Role"] = relationship(back_populates="users")


class RefreshToken(Base, UUIDPKMixin, TimestampMixin):
    """
    Stores hashed refresh tokens so they can be revoked/rotated server-side.
    A refresh call always issues a new row and invalidates the old one (rotation),
    which lets us detect stolen-token replay (old jti reused -> revoke whole chain).
    """
    __tablename__ = "refresh_tokens"

    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    jti: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)
    revoked: Mapped[bool] = mapped_column(Boolean, default=False)
    replaced_by_jti: Mapped[str | None] = mapped_column(String(64), nullable=True)
    expires_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), nullable=False)
