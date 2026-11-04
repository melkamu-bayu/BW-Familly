import asyncio

from fastapi import Request, HTTPException
from sqlalchemy import create_engine
from sqlalchemy.engine import URL
from sqlalchemy.orm import sessionmaker, DeclarativeBase
from sqlalchemy.pool import NullPool

from app.core.config import settings


class Base(DeclarativeBase):
    pass


# Local database objects are initialized only when requested.
_local_engine = None
_local_session = None


def _get_local_engine():
    global _local_engine

    if _local_engine is None:
        _local_engine = create_engine(
            settings.DATABASE_URL,
            pool_pre_ping=True,
            future=True,
        )

    return _local_engine


class _LazyEngine:
    def __getattr__(self, name):
        return getattr(_get_local_engine(), name)


class _LazySessionLocal:
    def __call__(self, *args, **kwargs):
        global _local_session

        if _local_session is None:
            _local_session = sessionmaker(
                autocommit=False,
                autoflush=False,
                bind=_get_local_engine(),
                future=True,
            )

        return _local_session(*args, **kwargs)


engine = _LazyEngine()
SessionLocal = _LazySessionLocal()


# Serialize synchronous SQLAlchemy operations in Cloudflare Workers.
_hyperdrive_lock = asyncio.Lock()


async def get_db(request: Request):
    """Provide a local or Cloudflare Hyperdrive database session."""

    env = request.scope.get("env")

    # Local development and Docker.
    if env is None:
        db = SessionLocal()
        try:
            yield db
        finally:
            db.close()
        return

    # Cloudflare Workers.
    hyperdrive = getattr(env, "HYPERDRIVE", None)

    if hyperdrive is None:
        raise HTTPException(
            status_code=503,
            detail="Database binding unavailable.",
        )

    async with _hyperdrive_lock:
        worker_engine = None
        db = None

        try:
            database_url = URL.create(
                "postgresql+pg8000",
                username=hyperdrive.user,
                password=hyperdrive.password,
                host=hyperdrive.host,
                port=int(hyperdrive.port),
                database=hyperdrive.database,
            )

            worker_engine = create_engine(
                database_url,
                poolclass=NullPool,
                connect_args={"ssl_context": False},
                future=True,
            )

            WorkerSession = sessionmaker(
                autocommit=False,
                autoflush=False,
                bind=worker_engine,
                future=True,
            )

            db = WorkerSession()
            yield db

        finally:
            if db is not None:
                db.close()

            if worker_engine is not None:
                worker_engine.dispose()
