"""User routes — profile, preferences, active harness."""

from fastapi import APIRouter, Depends

from app.auth.router import get_current_user_id, get_current_user
from app.database import get_db

router = APIRouter()


@router.get("/me")
async def get_profile(user: dict = Depends(get_current_user)):
    """Get the authenticated user's profile."""
    return {
        "id": user["id"],
        "email": user.get("email"),
        "display_name": user.get("display_name"),
        "active_harness_id": user.get("active_harness_id", "default"),
        "tier": user.get("tier", "free"),
    }


@router.patch("/me/harness")
async def set_active_harness(
    harness_id: str,
    user_id: str = Depends(get_current_user_id),
):
    """Update the user's active harness."""
    db = await get_db()
    try:
        # Verify harness exists
        cursor = await db.execute("SELECT id FROM harnesses WHERE id = ?", (harness_id,))
        if not await cursor.fetchone():
            return {"error": "Harness not found"}, 404

        await db.execute(
            "UPDATE users SET active_harness_id = ? WHERE id = ?",
            (harness_id, user_id),
        )
        await db.commit()
        return {"active_harness_id": harness_id}
    finally:
        await db.close()


@router.get("/me/memories")
async def list_memories(user_id: str = Depends(get_current_user_id)):
    """List all saved memories for the user."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT key, value, updated_at FROM memories WHERE user_id = ? ORDER BY updated_at DESC",
            (user_id,),
        )
        rows = await cursor.fetchall()
        return {"memories": [dict(r) for r in rows]}
    finally:
        await db.close()


@router.delete("/me/memories/{key}")
async def delete_memory(key: str, user_id: str = Depends(get_current_user_id)):
    """Delete a specific memory."""
    db = await get_db()
    try:
        await db.execute(
            "DELETE FROM memories WHERE user_id = ? AND key = ?",
            (user_id, key),
        )
        await db.commit()
        return {"deleted": key}
    finally:
        await db.close()


@router.get("/me/sessions")
async def list_sessions(user_id: str = Depends(get_current_user_id)):
    """List user's chat sessions (for history)."""
    db = await get_db()
    try:
        cursor = await db.execute(
            "SELECT id, harness_id, created_at, updated_at FROM sessions WHERE user_id = ? ORDER BY updated_at DESC LIMIT 50",
            (user_id,),
        )
        rows = await cursor.fetchall()
        return {"sessions": [dict(r) for r in rows]}
    finally:
        await db.close()
