from pydantic import BaseModel, Field


class PinSetRequest(BaseModel):
    pin: str = Field(min_length=4, max_length=8, pattern=r"^\d+$")


class PinVerifyRequest(BaseModel):
    pin: str


class BiometricEnableRequest(BaseModel):
    enabled: bool


class SessionUnlockResponse(BaseModel):
    unlocked: bool
    message: str
