from datetime import datetime, timedelta, timezone
from typing import Any
from functools import lru_cache

from jose import jwt
from fastapi import Request

from app.core.config import settings



# Initialize Passlib only when password operations are requested.
@lru_cache(maxsize=1)
def _get_pwd_context():
    from passlib.context import CryptContext
    return CryptContext(schemes=["argon2"], deprecated="auto")

def hash_password(plain_password: str) -> str:
    return _get_pwd_context().hash(plain_password)


def verify_password(plain_password: str, password_hash: str) -> bool:
    return _get_pwd_context().verify(plain_password, password_hash)


def _jwt_secret(request: Request | None = None) -> str:
    env = request.scope.get("env") if request is not None else None
    if env is not None:
        secret = getattr(env, "JWT_SECRET_KEY", None)
        if not secret:
            raise RuntimeError("Cloudflare JWT_SECRET_KEY binding is unavailable.")
        return secret
    return settings.JWT_SECRET_KEY


def create_access_token(
    subject: str,
    role: str,
    extra_claims: dict[str, Any] | None = None,
    request: Request | None = None,
) -> str:
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    payload = {"sub": subject, "role": role, "type": "access", "exp": expire}
    if extra_claims:
        payload.update(extra_claims)
    return jwt.encode(payload, _jwt_secret(request), algorithm=settings.JWT_ALGORITHM)


def create_refresh_token(subject: str, jti: str, request: Request | None = None) -> str:
    expire = datetime.now(timezone.utc) + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    payload = {"sub": subject, "type": "refresh", "jti": jti, "exp": expire}
    return jwt.encode(payload, _jwt_secret(request), algorithm=settings.JWT_ALGORITHM)


def decode_token(token: str, request: Request | None = None) -> dict[str, Any]:
    """Raises jose.JWTError if invalid/expired -- caller converts to HTTP 401."""
    return jwt.decode(token, _jwt_secret(request), algorithms=[settings.JWT_ALGORITHM])
