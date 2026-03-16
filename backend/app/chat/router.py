"""Chat router — WebSocket endpoint using the pi-style agent loop."""

import asyncio
import json

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.auth.router import get_ws_user_id
from app.database import get_db
from app.chat.agent_loop import (
    AgentContext,
    agent_loop,
    serialize_messages,
    deserialize_messages,
)
from app.chat.tools import get_tools_for_harness

router = APIRouter()


@router.websocket("/{session_id}")
async def chat_websocket(websocket: WebSocket, session_id: str):
    """
    WebSocket endpoint for real-time chat with an agent.

    Connect: ws://host/api/v1/chat/{session_id}?token=JWT&harness_id=default

    Protocol (client → server):
        {"type": "message", "content": "...", "api_key": "...", "provider": "anthropic"}
        {"type": "steering", "content": "..."}  (interrupt mid-tool)
        {"type": "switch_harness", "harness_id": "..."}
        {"type": "load_history"}

    Protocol (server → client):
        AgentEvent objects streamed as JSON (see agent_loop.py EventType)
        {"type": "history", "messages": [...]}
        {"type": "harness_switched", "harness_id": "..."}
        {"type": "error", "message": "..."}
    """
    await websocket.accept()

    # Auth — extract user from token (allow anonymous for dev)
    user_id = get_ws_user_id(websocket)
    if not user_id:
        user_id = "anonymous"

    # Get harness
    harness_id = websocket.query_params.get("harness_id", "default")

    db = await get_db()
    try:
        cursor = await db.execute("SELECT * FROM harnesses WHERE id = ?", (harness_id,))
        harness = await cursor.fetchone()
        if not harness:
            await websocket.send_json({"type": "error", "message": f"Harness '{harness_id}' not found"})
            await websocket.close()
            return
        harness = dict(harness)
    finally:
        await db.close()

    # Load or create session
    messages = []
    db = await get_db()
    try:
        cursor = await db.execute("SELECT * FROM sessions WHERE id = ?", (session_id,))
        session = await cursor.fetchone()
        if session:
            session_data = dict(session)
            messages = deserialize_messages(session_data.get("messages", "[]"))
        else:
            await db.execute(
                "INSERT INTO sessions (id, user_id, harness_id) VALUES (?, ?, ?)",
                (session_id, user_id, harness_id),
            )
            await db.commit()
    finally:
        await db.close()

    # Steering queue for user interruptions
    steering_queue: asyncio.Queue[str] = asyncio.Queue()

    try:
        while True:
            data = await websocket.receive_json()
            msg_type = data.get("type", "")

            if msg_type == "message":
                user_text = data.get("content", "").strip()
                api_key = data.get("api_key", "")
                provider = data.get("provider", "anthropic")

                if not user_text:
                    await websocket.send_json({"type": "error", "message": "Empty message"})
                    continue

                if not api_key:
                    await websocket.send_json({
                        "type": "error",
                        "message": "No API key provided. Add your API key in Settings."
                    })
                    continue

                # Build agent context
                tools = get_tools_for_harness(harness.get("tools_config"))
                context = AgentContext(
                    system_prompt=harness["system_prompt"],
                    messages=messages.copy(),
                    tools=tools,
                    provider=provider,
                    api_key=api_key,
                )

                # Run agent loop, stream events to client
                try:
                    async for event in agent_loop(
                        prompt=user_text,
                        context=context,
                        steering_queue=steering_queue,
                    ):
                        await websocket.send_json(event.to_dict())
                except Exception as e:
                    await websocket.send_json({
                        "type": "error",
                        "message": f"Agent error: {str(e)}",
                    })

                # Update messages from completed context
                messages = context.messages

                # Persist to SQLite
                db = await get_db()
                try:
                    await db.execute(
                        "UPDATE sessions SET messages = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
                        (serialize_messages(messages), session_id),
                    )
                    await db.commit()
                finally:
                    await db.close()

            elif msg_type == "steering":
                steering_text = data.get("content", "").strip()
                if steering_text:
                    await steering_queue.put(steering_text)

            elif msg_type == "load_history":
                # Send current message history to client
                history = [
                    {"role": m.role, "content": m.content, "id": m.id, "timestamp": m.timestamp}
                    for m in messages
                ]
                await websocket.send_json({"type": "history", "messages": history})

            elif msg_type == "switch_harness":
                new_harness_id = data.get("harness_id", "default")
                db = await get_db()
                try:
                    cursor = await db.execute("SELECT * FROM harnesses WHERE id = ?", (new_harness_id,))
                    new_harness = await cursor.fetchone()
                    if new_harness:
                        harness = dict(new_harness)
                        harness_id = new_harness_id
                        messages = []  # Fresh context for new harness
                        await websocket.send_json({
                            "type": "harness_switched",
                            "harness_id": new_harness_id,
                            "harness_name": harness["name"],
                        })
                    else:
                        await websocket.send_json({
                            "type": "error",
                            "message": f"Harness '{new_harness_id}' not found",
                        })
                finally:
                    await db.close()

    except WebSocketDisconnect:
        pass
    except Exception as e:
        try:
            await websocket.send_json({"type": "error", "message": f"Connection error: {str(e)}"})
        except Exception:
            pass
