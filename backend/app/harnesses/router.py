"""Harnesses router — CRUD for harness definitions."""

from fastapi import APIRouter

from app.database import get_db

router = APIRouter()


@router.get("/")
async def list_harnesses():
    """List all available harnesses."""
    db = await get_db()
    try:
        cursor = await db.execute("SELECT * FROM harnesses ORDER BY is_free DESC, name")
        rows = await cursor.fetchall()
        return [dict(row) for row in rows]
    finally:
        await db.close()


@router.get("/{harness_id}")
async def get_harness(harness_id: str):
    """Get a specific harness by ID."""
    db = await get_db()
    try:
        cursor = await db.execute("SELECT * FROM harnesses WHERE id = ?", (harness_id,))
        row = await cursor.fetchone()
        if not row:
            from fastapi import HTTPException
            raise HTTPException(status_code=404, detail="Harness not found")
        return dict(row)
    finally:
        await db.close()
