import uuid
from datetime import datetime, timedelta, timezone

from fastapi.security import OAuth2PasswordRequestForm
from fastapi import APIRouter, Depends, HTTPException, status
from jose import JWTError
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.database import get_db
from app.core.security import (
    verify_password,
    create_access_token,
    create_refresh_token,
    decode_token,
)
from app.core.dependencies import get_current_user
from app.models.identity import User, Role, RefreshToken
from app.schemas.auth import LoginRequest, TokenResponse, RefreshRequest, CurrentUser
from app.schemas.security import (
    PinSetRequest,
    PinVerifyRequest,
    BiometricEnableRequest,
    SessionUnlockResponse,
)

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=TokenResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    user = db.execute(select(User).where(User.email == payload.email)).scalar_one_or_none()
    if user is None or user.deleted_at is not None or not user.active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    if not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")

    role = db.get(Role, user.role_id)
    access_token = create_access_token(subject=str(user.id), role=role.name if role else "")

    jti = str(uuid.uuid4())
    refresh_token = create_refresh_token(subject=str(user.id), jti=jti)
    db.add(
        RefreshToken(
            user_id=user.id,
            jti=jti,
            expires_at=datetime.now(timezone.utc) + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
        )
    )
    user.last_login_at = datetime.now(timezone.utc)
    db.commit()

    return TokenResponse(access_token=access_token, refresh_token=refresh_token)


@router.post("/refresh", response_model=TokenResponse)
def refresh(payload: RefreshRequest, db: Session = Depends(get_db)):
    """
    Rotating refresh: the presented refresh token is revoked and a new one
    issued. If a revoked token is reused (replay/theft), we revoke the
    entire chain for that user as a precaution.
    """
    try:
        decoded = decode_token(payload.refresh_token)
        if decoded.get("type") != "refresh":
            raise HTTPException(status_code=401, detail="Invalid token type")
        user_id = decoded["sub"]
        jti = decoded["jti"]
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid or expired refresh token")

    stored = db.execute(select(RefreshToken).where(RefreshToken.jti == jti)).scalar_one_or_none()
    if stored is None or stored.revoked:
        # Possible replay of an already-rotated token: revoke the whole chain for this user.
        if stored is not None:
            db.query(RefreshToken).filter(RefreshToken.user_id == stored.user_id).update({"revoked": True})
            db.commit()
        raise HTTPException(status_code=401, detail="Refresh token revoked or invalid")

    user = db.get(User, uuid.UUID(user_id))
    if user is None or not user.active or user.deleted_at is not None:
        raise HTTPException(status_code=401, detail="User not found or inactive")

    stored.revoked = True
    new_jti = str(uuid.uuid4())
    stored.replaced_by_jti = new_jti
    db.add(
        RefreshToken(
            user_id=user.id,
            jti=new_jti,
            expires_at=datetime.now(timezone.utc) + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
        )
    )
    role = db.get(Role, user.role_id)
    access_token = create_access_token(subject=str(user.id), role=role.name if role else "")
    new_refresh_token = create_refresh_token(subject=str(user.id), jti=new_jti)
    db.commit()

    return TokenResponse(access_token=access_token, refresh_token=new_refresh_token)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(payload: RefreshRequest, db: Session = Depends(get_db)):
    try:
        decoded = decode_token(payload.refresh_token)
        jti = decoded.get("jti")
    except JWTError:
        return
    if jti:
        db.query(RefreshToken).filter(RefreshToken.jti == jti).update({"revoked": True})
        db.commit()


@router.get("/me", response_model=CurrentUser)
def me(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    role = db.get(Role, current_user.role_id)
    return CurrentUser(
        id=current_user.id,
        email=current_user.email,
        full_name=current_user.full_name,
        role=role.name if role else "",
        biometric_enabled=current_user.biometric_enabled,
        pin_is_set=current_user.pin_hash is not None,
    )


@router.post("/pin/set", status_code=status.HTTP_204_NO_CONTENT)
def set_pin(
    payload: PinSetRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Sets/replaces the device unlock PIN (Section 20). This PIN unlocks the
    *local* app session on a device that's already holding a valid token --
    it is never itself a substitute for the password/JWT login flow.
    """
    from app.core.security import hash_password as _hash  # reuse the same argon2 context

    current_user.pin_hash = _hash(payload.pin)
    db.commit()


@router.post("/pin/verify", response_model=SessionUnlockResponse)
def verify_pin(
    payload: PinVerifyRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if not current_user.pin_hash:
        raise HTTPException(status_code=400, detail="No PIN has been set for this account")
    if not verify_password(payload.pin, current_user.pin_hash):
        raise HTTPException(status_code=401, detail="Incorrect PIN")
    return SessionUnlockResponse(unlocked=True, message="Session unlocked")


@router.post("/biometric", response_model=CurrentUser)
def set_biometric_enabled(
    payload: BiometricEnableRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Toggles whether this account accepts biometric unlock on-device. Like the
    PIN, biometric unlock only re-opens a local session backed by an
    already-valid token -- it never bypasses server-side authentication.
    """
    current_user.biometric_enabled = payload.enabled
    db.commit()
    role = db.get(Role, current_user.role_id)
    return CurrentUser(
        id=current_user.id, email=current_user.email, full_name=current_user.full_name,
        role=role.name if role else "",
        biometric_enabled=current_user.biometric_enabled,
        pin_is_set=current_user.pin_hash is not None,
    )


@router.post("/token", response_model=TokenResponse)
def token(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db),
):
    login_data = LoginRequest(
        email=form_data.username,
        password=form_data.password,
    )

    return login(login_data, db)
