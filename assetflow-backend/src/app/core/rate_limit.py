"""
Rate limiting for AssetFlow.

Cloudflare Workers: Cloudflare Rate Limiting binding.
Local/Docker: Redis fixed-window counter.

Fails open on temporary rate-limiter errors to preserve API availability.
"""
import time

from fastapi import Request
from jose import JWTError
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse

from app.core.config import settings
from app.core.security import decode_token


_redis_client = None
_redis_initialized = False


def client_identity(request: Request) -> str:
    """Use verified JWT subject, otherwise fall back to client IP."""
    is_cloudflare = request.scope.get("env") is not None
    cloudflare_ip = request.headers.get("cf-connecting-ip") if is_cloudflare else None
    ip = cloudflare_ip or (request.client.host if request.client else "unknown")

    auth_header = request.headers.get("authorization", "")
    if auth_header.startswith("Bearer "):
        try:
            sub = decode_token(auth_header[7:], request=request).get("sub")
        except JWTError:
            sub = None

        if sub:
            return f"user:{sub}"

    return f"ip:{ip}"


def _get_redis_client():
    """Load Redis only when running outside Cloudflare Workers."""
    global _redis_client, _redis_initialized

    if not _redis_initialized:
        _redis_initialized = True
        try:
            import redis

            _redis_client = redis.from_url(
                settings.REDIS_URL,
                socket_connect_timeout=0.5,
                socket_timeout=0.5,
            )
        except Exception:
            _redis_client = None

    return _redis_client


def _rate_limit_response():
    return JSONResponse(
        status_code=429,
        content={
            "success": False,
            "error": "Rate limit exceeded. Try again shortly.",
        },
        headers={"Retry-After": "60"},
    )


class RateLimitMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        identity = client_identity(request)

        # Cloudflare Workers
        env = request.scope.get("env")

        if env is not None:
            limiter = getattr(env, "ASSETFLOW_RATE_LIMITER", None)

            if limiter is None:
                return JSONResponse(
                    status_code=503,
                    content={"success": False, "error": "Rate limiter binding unavailable."},
                )

            try:
                from js import Object
                from pyodide.ffi import to_js

                options = to_js(
                    {"key": identity},
                    dict_converter=Object.fromEntries,
                )
                result = await limiter.limit(options)

                if not result.success:
                    return _rate_limit_response()

            except Exception:
                # Preserve API availability if the rate-limit service has a temporary error.
                pass

            return await call_next(request)

        # Local development / Docker: Redis
        redis_client = _get_redis_client()

        if redis_client is None:
            return await call_next(request)

        window = int(time.time() // 60)
        key = f"ratelimit:{identity}:{window}"

        try:
            current = redis_client.incr(key)
            if current == 1:
                redis_client.expire(key, 60)
        except Exception:
            return await call_next(request)

        if current > settings.RATE_LIMIT_PER_MINUTE:
            return _rate_limit_response()

        return await call_next(request)
