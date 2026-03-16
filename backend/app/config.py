"""Application configuration from environment variables."""

import os
from dataclasses import dataclass, field

from dotenv import load_dotenv

load_dotenv()


@dataclass
class Settings:
    # Database
    database_url: str = os.getenv("DATABASE_URL", "sqlite+aiosqlite:///./agent.db")
    
    # Auth
    jwt_secret: str = os.getenv("JWT_SECRET", "change-me-in-production")
    jwt_algorithm: str = "HS256"
    jwt_expiration_hours: int = 720  # 30 days
    
    # Apple
    apple_team_id: str = os.getenv("APPLE_TEAM_ID", "")
    apple_bundle_id: str = os.getenv("APPLE_BUNDLE_ID", "com.agent.app")
    
    # CORS
    cors_origins: list[str] = field(default_factory=lambda: ["*"])
    
    # Server
    host: str = os.getenv("HOST", "0.0.0.0")
    port: int = int(os.getenv("PORT", "8000"))


settings = Settings()
