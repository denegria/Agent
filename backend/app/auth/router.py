"""Authentication router — Apple Sign In + JWT + auth middleware."""

import uuid
from datetime import datetime, timedelta, timezone

import jwt
from fastapi import APIRouter, Depends, HTTPException, Request, WebSocket, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel

from app.config import settings
from app.database import get_db

router = APIRouter()
security = HTTPBearer(auto_error=False)


# ──────────────────────────────────────────────
# Request/Response models
# ──────────────────────────────────────────────

class AppleSignInRequest(BaseModel):
    identity_token: str
    full_name: str | None = None


class AuthResponse(BaseModel):
    token: str
    user: dict


# ──────────────────────────────────────────────
# Endpoints
# ──────────────────────────────────────────────

@router.post("/apple", response_model=AuthResponse)
async def sign_in_with_apple(request: AppleSignInRequest):
    """Sign in with Apple identity token."""
    try:
        # In production: verify with Apple's public keys
        payload = jwt.decode(
            request.identity_token,
            options={"verify_signature": False},
            algorithms=["RS256"],
        )
        apple_id = payload.get("sub", "")
        email = payload.get("email", "")
    except jwt.exceptions.DecodeError:
        # Development fallback — generate a dev user
        apple_id = f"dev_{uuid.uuid4().hex[:8]}"
        email = ""

    db = await get_db()
    try:
        cursor = await db.execute("SELECT * FROM users WHERE apple_id = ?", (apple_id,))
        user_row = await cursor.fetchone()

        if user_row:
            user = dict(user_row)
        else:
            user_id = str(uuid.uuid4())
            await db.execute(
                "INSERT INTO users (id, apple_id, email, display_name) VALUES (?, ?, ?, ?)",
                (user_id, apple_id, email or None, request.full_name),
            )
            await db.commit()
            user = {
                "id": user_id,
                "apple_id": apple_id,
                "email": email,
                "display_name": request.full_name,
                "active_harness_id": "default",
                "tier": "free",
            }

        token = create_jwt(user["id"])
        return AuthResponse(token=token, user=user)
    finally:
        await db.close()


# ──────────────────────────────────────────────
# JWT creation & verification
# ──────────────────────────────────────────────

def create_jwt(user_id: str) -> str:
    """Create a JWT token for a user."""
    payload = {
        "sub": user_id,
        "iat": datetime.now(timezone.utc),
        "exp": datetime.now(timezone.utc) + timedelta(hours=settings.jwt_expiration_hours),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def verify_jwt(token: str) -> str:
    """Verify a JWT and return the user ID. Raises HTTPException on failure."""
    try:
        payload = jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
        return payload["sub"]
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")


# ──────────────────────────────────────────────
# Auth dependencies (use in routers)
# ──────────────────────────────────────────────

async def get_current_user_id(
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
) -> str:
    """
    FastAPI dependency — extracts user_id from Bearer token.
    Usage: user_id: str = Depends(get_current_user_id)
    """
    if not credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing authorization header",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return verify_jwt(credentials.credentials)


async def get_current_user(user_id: str = Depends(get_current_user_id)) -> dict:
    """
    FastAPI dependency — returns the full user dict from DB.
    Usage: user: dict = Depends(get_current_user)
    """
    db = await get_db()
    try:
        cursor = await db.execute("SELECT * FROM users WHERE id = ?", (user_id,))
        row = await cursor.fetchone()
        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
        return dict(row)
    finally:
        await db.close()


def get_ws_user_id(websocket: WebSocket) -> str | None:
    """
    Extract user_id from WebSocket query params or headers.
    WebSockets can't use standard Bearer — pass token as query param.
    Returns None if no valid token (allow anonymous for dev).
    """
    # Try query param first (ws://host/chat/session?token=...)
    token = websocket.query_params.get("token", "")

    # Try Authorization header
    if not token:
        auth_header = websocket.headers.get("authorization", "")
        if auth_header.startswith("Bearer "):
            token = auth_header[7:]

    if not token:
        return None

    try:
        payload = jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
        return payload["sub"]
    except (jwt.ExpiredSignatureError, jwt.InvalidTokenError):
        return None
