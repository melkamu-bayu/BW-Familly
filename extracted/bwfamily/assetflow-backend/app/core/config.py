from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """
    Central application configuration.
    All values are overridable via environment variables (.env in dev,
    real env vars / secrets manager in production).
    """

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    APP_NAME: str = "AssetFlow API"
    API_V1_PREFIX: str = "/api/v1"
    ENVIRONMENT: str = "development"

    # --- Database ---
    DATABASE_URL: str = "postgresql+psycopg2://assetflow:assetflow@localhost:5432/assetflow"

    # --- Auth / JWT ---
    JWT_SECRET_KEY: str = "CHANGE_ME_IN_PRODUCTION"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # --- Rate limiting ---
    REDIS_URL: str = "redis://localhost:6379/0"
    RATE_LIMIT_PER_MINUTE: int = 100

    # --- Currency ---
    DEFAULT_CURRENCY: str = "ETB"

    # --- CORS ---
    CORS_ORIGINS: list[str] = ["*"]


settings = Settings()
