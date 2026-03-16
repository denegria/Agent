"""IAP router — Apple In-App Purchase verification."""

import uuid

from fastapi import APIRouter
from pydantic import BaseModel

from app.database import get_db

router = APIRouter()


class PurchaseVerifyRequest(BaseModel):
    transaction_id: str
    product_id: str


class PurchaseVerifyResponse(BaseModel):
    verified: bool
    product_id: str


@router.post("/verify", response_model=PurchaseVerifyResponse)
async def verify_purchase(request: PurchaseVerifyRequest):
    """Verify an Apple IAP transaction and provision access."""
    # TODO: Verify with Apple's App Store Server API
    # For now, trust the client and record the purchase
    
    db = await get_db()
    try:
        # Check for duplicate
        cursor = await db.execute(
            "SELECT id FROM purchases WHERE transaction_id = ?",
            (request.transaction_id,),
        )
        existing = await cursor.fetchone()
        
        if not existing:
            purchase_id = str(uuid.uuid4())
            await db.execute(
                "INSERT INTO purchases (id, user_id, product_id, transaction_id) VALUES (?, ?, ?, ?)",
                (purchase_id, "anonymous", request.product_id, request.transaction_id),
            )
            await db.commit()
        
        return PurchaseVerifyResponse(verified=True, product_id=request.product_id)
    finally:
        await db.close()
