import uuid

from pydantic import BaseModel, EmailStr


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class RefreshRequest(BaseModel):
    refresh_token: str


class CurrentUser(BaseModel):
    id: uuid.UUID
    email: EmailStr
    full_name: str
    role: str
    biometric_enabled: bool = False
    pin_is_set: bool = False

    model_config = {"from_attributes": True}
