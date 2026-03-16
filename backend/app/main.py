"""Agent Backend — FastAPI Application Entry Point"""

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.database import init_db
from app.auth.router import router as auth_router
from app.chat.router import router as chat_router
from app.harnesses.router import router as harnesses_router
from app.iap.router import router as iap_router
from app.users.router import router as users_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup and shutdown logic."""
    await init_db()
    yield


app = FastAPI(
    title="Agent API",
    description="Backend for Agent — Your Personal AI Harness",
    version="0.1.0",
    lifespan=lifespan,
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Routers
app.include_router(auth_router, prefix="/api/v1/auth", tags=["auth"])
app.include_router(chat_router, prefix="/api/v1/chat", tags=["chat"])
app.include_router(harnesses_router, prefix="/api/v1/harnesses", tags=["harnesses"])
app.include_router(iap_router, prefix="/api/v1/iap", tags=["iap"])
app.include_router(users_router, prefix="/api/v1/users", tags=["users"])


@app.get("/health")
async def health_check():
    return {"status": "healthy", "version": "0.1.0"}
