import uuid

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import decode_token
from app.models.identity import User, Permission, Role

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")


def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> User:
    credentials_error = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = decode_token(token)
        if payload.get("type") != "access":
            raise credentials_error
        user_id = payload.get("sub")
        if user_id is None:
            raise credentials_error
    except JWTError:
        raise credentials_error

    user = db.get(User, uuid.UUID(user_id))
    if user is None or not user.active or user.deleted_at is not None:
        raise credentials_error
    return user


def require_permission(resource: str, action: str):
    """
    Usage: Depends(require_permission("revenue", "create"))
    Enforced server-side against the permissions table -- never trusts
    role claims embedded in the JWT alone, since permissions can change
    after a token was issued.
    """

    def _checker(
        current_user: User = Depends(get_current_user),
        db: Session = Depends(get_db),
    ) -> User:
        # super_admin bypasses granular checks
        role = db.get(Role, current_user.role_id)
        if role and role.name == "super_admin":
            return current_user

        stmt = select(Permission).where(
            Permission.role_id == current_user.role_id,
            Permission.resource == resource,
            Permission.action == action,
        )
        permission = db.execute(stmt).scalar_one_or_none()
        if permission is None:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Not permitted: {action} on {resource}",
            )
        return current_user

    return _checker
