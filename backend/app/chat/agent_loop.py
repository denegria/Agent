"""
Agent Loop — Python port of pi's agent-loop pattern.

A lightweight, event-streaming agent loop that runs per user session:
  prompt → LLM response → tool execution → loop back

No graph DSL, no framework overhead — just an async while-loop
with structured events and interruptibility.
"""

from __future__ import annotations

import asyncio
import json
import time
import uuid
from dataclasses import dataclass, field
from enum import Enum
from typing import Any, AsyncIterator, Callable, Awaitable

from app.chat.llm_proxy import proxy_llm_request


# ──────────────────────────────────────────────
# Event types (streamed to client via WebSocket)
# ──────────────────────────────────────────────

class EventType(str, Enum):
    AGENT_START = "agent_start"
    AGENT_END = "agent_end"
    TURN_START = "turn_start"
    TURN_END = "turn_end"
    MESSAGE_START = "message_start"
    MESSAGE_DELTA = "message_delta"
    MESSAGE_END = "message_end"
    TOOL_START = "tool_start"
    TOOL_UPDATE = "tool_update"
    TOOL_END = "tool_end"
    ERROR = "error"


@dataclass
class AgentEvent:
    type: EventType
    data: dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict:
        return {"type": self.type.value, **self.data}


# ──────────────────────────────────────────────
# Messages (internal representation)
# ──────────────────────────────────────────────

@dataclass
class AgentMessage:
    role: str  # "user" | "assistant" | "tool_result" | "system"
    content: str
    tool_calls: list[ToolCall] | None = None
    tool_call_id: str | None = None
    tool_name: str | None = None
    is_error: bool = False
    timestamp: float = field(default_factory=time.time)
    id: str = field(default_factory=lambda: str(uuid.uuid4()))


@dataclass
class ToolCall:
    id: str
    name: str
    arguments: dict[str, Any]


# ──────────────────────────────────────────────
# Tool definition (per harness)
# ──────────────────────────────────────────────

@dataclass
class AgentTool:
    """A tool that can be called by the agent."""
    name: str
    description: str
    parameters: dict[str, Any]  # JSON Schema
    execute: Callable[[str, dict[str, Any]], Awaitable[ToolResult]]


@dataclass
class ToolResult:
    content: str
    details: dict[str, Any] = field(default_factory=dict)
    is_error: bool = False


# ──────────────────────────────────────────────
# Agent context (per session)
# ──────────────────────────────────────────────

@dataclass
class AgentContext:
    """Everything the agent needs to run — one instance per user session."""
    system_prompt: str
    messages: list[AgentMessage] = field(default_factory=list)
    tools: list[AgentTool] = field(default_factory=list)
    provider: str = "anthropic"
    api_key: str = ""
    max_turns: int = 20  # Safety limit


# ──────────────────────────────────────────────
# Agent loop
# ──────────────────────────────────────────────

async def agent_loop(
    prompt: str,
    context: AgentContext,
    steering_queue: asyncio.Queue[str] | None = None,
) -> AsyncIterator[AgentEvent]:
    """
    Run an agent loop with a new user prompt.

    Yields AgentEvent objects that can be streamed to the client.
    The loop continues as long as the LLM returns tool calls.

    Args:
        prompt: The user's message text
        context: Agent context (system prompt, messages, tools, API key)
        steering_queue: Optional queue for user interruptions mid-tool

    Yields:
        AgentEvent objects for real-time streaming
    """
    # Add user message to context
    user_msg = AgentMessage(role="user", content=prompt)
    context.messages.append(user_msg)

    yield AgentEvent(EventType.AGENT_START)
    yield AgentEvent(EventType.MESSAGE_START, {
        "message": {"role": "user", "content": prompt, "id": user_msg.id}
    })
    yield AgentEvent(EventType.MESSAGE_END, {
        "message": {"role": "user", "content": prompt, "id": user_msg.id}
    })

    turn_count = 0

    while turn_count < context.max_turns:
        turn_count += 1
        yield AgentEvent(EventType.TURN_START, {"turn": turn_count})

        # ── Step 1: Check for steering messages (user interrupted) ──
        if steering_queue:
            while not steering_queue.empty():
                steering_text = steering_queue.get_nowait()
                steering_msg = AgentMessage(role="user", content=steering_text)
                context.messages.append(steering_msg)
                yield AgentEvent(EventType.MESSAGE_START, {
                    "message": {"role": "user", "content": steering_text, "id": steering_msg.id}
                })
                yield AgentEvent(EventType.MESSAGE_END, {
                    "message": {"role": "user", "content": steering_text, "id": steering_msg.id}
                })

        # ── Step 2: Stream assistant response from LLM ──
        assistant_msg, events = await _stream_assistant_response(context)
        for event in events:
            yield event

        context.messages.append(assistant_msg)

        # ── Step 3: Check for tool calls ──
        if not assistant_msg.tool_calls:
            # No tool calls — agent is done
            yield AgentEvent(EventType.TURN_END, {"turn": turn_count})
            break

        # ── Step 4: Execute tool calls ──
        tool_results = []
        interrupted = False

        for tool_call in assistant_msg.tool_calls:
            # Check if user interrupted
            if steering_queue and not steering_queue.empty():
                # Skip remaining tools
                skip_result = AgentMessage(
                    role="tool_result",
                    content="Skipped — user sent a new message.",
                    tool_call_id=tool_call.id,
                    tool_name=tool_call.name,
                    is_error=True,
                )
                context.messages.append(skip_result)
                tool_results.append(skip_result)
                interrupted = True
                continue

            yield AgentEvent(EventType.TOOL_START, {
                "tool_call_id": tool_call.id,
                "tool_name": tool_call.name,
                "arguments": tool_call.arguments,
            })

            # Execute the tool
            result_msg = await _execute_tool(context.tools, tool_call)
            context.messages.append(result_msg)
            tool_results.append(result_msg)

            yield AgentEvent(EventType.TOOL_END, {
                "tool_call_id": tool_call.id,
                "tool_name": tool_call.name,
                "result": result_msg.content,
                "is_error": result_msg.is_error,
            })

        yield AgentEvent(EventType.TURN_END, {
            "turn": turn_count,
            "tool_results_count": len(tool_results),
        })

        # If interrupted, the loop continues to process the steering message
        # next turn (it's already in the steering_queue)

    yield AgentEvent(EventType.AGENT_END, {
        "total_turns": turn_count,
        "message_count": len(context.messages),
    })


# ──────────────────────────────────────────────
# Internal: LLM call with streaming
# ──────────────────────────────────────────────

async def _stream_assistant_response(
    context: AgentContext,
) -> tuple[AgentMessage, list[AgentEvent]]:
    """
    Call the LLM and collect the streamed response.
    Returns the complete assistant message and streaming events.
    """
    events: list[AgentEvent] = []

    # Convert internal messages to LLM format
    llm_messages = _convert_to_llm_messages(context)

    # Build tool definitions for the LLM
    tools_for_llm = _build_tool_definitions(context.tools) if context.tools else None

    # Collect streamed response
    full_text = ""
    msg_id = str(uuid.uuid4())

    events.append(AgentEvent(EventType.MESSAGE_START, {
        "message": {"role": "assistant", "content": "", "id": msg_id}
    }))

    async for chunk in proxy_llm_request(
        provider=context.provider,
        api_key=context.api_key,
        system_prompt=context.system_prompt,
        messages=llm_messages,
        tools=tools_for_llm,
    ):
        if isinstance(chunk, str):
            full_text += chunk
            events.append(AgentEvent(EventType.MESSAGE_DELTA, {
                "content": chunk,
                "id": msg_id,
            }))
        elif isinstance(chunk, dict) and chunk.get("type") == "tool_calls":
            # LLM returned tool calls
            tool_calls = [
                ToolCall(
                    id=tc.get("id", str(uuid.uuid4())),
                    name=tc["name"],
                    arguments=tc.get("arguments", {}),
                )
                for tc in chunk.get("tool_calls", [])
            ]
            assistant_msg = AgentMessage(
                role="assistant",
                content=full_text,
                tool_calls=tool_calls,
                id=msg_id,
            )
            events.append(AgentEvent(EventType.MESSAGE_END, {
                "message": {
                    "role": "assistant",
                    "content": full_text,
                    "id": msg_id,
                    "tool_calls": [
                        {"id": tc.id, "name": tc.name, "arguments": tc.arguments}
                        for tc in tool_calls
                    ],
                }
            }))
            return assistant_msg, events

    # No tool calls — plain text response
    assistant_msg = AgentMessage(role="assistant", content=full_text, id=msg_id)
    events.append(AgentEvent(EventType.MESSAGE_END, {
        "message": {"role": "assistant", "content": full_text, "id": msg_id}
    }))
    return assistant_msg, events


# ──────────────────────────────────────────────
# Internal: Tool execution
# ──────────────────────────────────────────────

async def _execute_tool(
    tools: list[AgentTool],
    tool_call: ToolCall,
) -> AgentMessage:
    """Execute a single tool call and return a tool_result message."""
    tool = next((t for t in tools if t.name == tool_call.name), None)

    if not tool:
        return AgentMessage(
            role="tool_result",
            content=f"Error: Tool '{tool_call.name}' not found.",
            tool_call_id=tool_call.id,
            tool_name=tool_call.name,
            is_error=True,
        )

    try:
        result = await tool.execute(tool_call.id, tool_call.arguments)
        return AgentMessage(
            role="tool_result",
            content=result.content,
            tool_call_id=tool_call.id,
            tool_name=tool_call.name,
            is_error=result.is_error,
        )
    except Exception as e:
        return AgentMessage(
            role="tool_result",
            content=f"Tool execution error: {str(e)}",
            tool_call_id=tool_call.id,
            tool_name=tool_call.name,
            is_error=True,
        )


# ──────────────────────────────────────────────
# Internal: Message format conversion
# ──────────────────────────────────────────────

def _convert_to_llm_messages(context: AgentContext) -> list[dict]:
    """
    Convert internal AgentMessages to LLM-compatible format.
    This is the ONLY place where we touch LLM message format.
    """
    messages = []
    for msg in context.messages:
        if msg.role == "user":
            messages.append({"role": "user", "content": msg.content})
        elif msg.role == "assistant":
            messages.append({"role": "assistant", "content": msg.content})
        elif msg.role == "tool_result":
            messages.append({
                "role": "tool_result",
                "content": msg.content,
                "tool_call_id": msg.tool_call_id,
                "tool_name": msg.tool_name,
            })
        # system messages are handled via context.system_prompt
    return messages


def _build_tool_definitions(tools: list[AgentTool]) -> list[dict]:
    """Build tool definitions in the format expected by the LLM proxy."""
    return [
        {
            "name": tool.name,
            "description": tool.description,
            "parameters": tool.parameters,
        }
        for tool in tools
    ]


# ──────────────────────────────────────────────
# Serialization helpers (for SQLite persistence)
# ──────────────────────────────────────────────

def serialize_messages(messages: list[AgentMessage]) -> str:
    """Serialize messages to JSON for SQLite storage."""
    return json.dumps([
        {
            "id": m.id,
            "role": m.role,
            "content": m.content,
            "tool_calls": [
                {"id": tc.id, "name": tc.name, "arguments": tc.arguments}
                for tc in m.tool_calls
            ] if m.tool_calls else None,
            "tool_call_id": m.tool_call_id,
            "tool_name": m.tool_name,
            "is_error": m.is_error,
            "timestamp": m.timestamp,
        }
        for m in messages
    ])


def deserialize_messages(data: str) -> list[AgentMessage]:
    """Deserialize messages from JSON (SQLite)."""
    items = json.loads(data) if data else []
    messages = []
    for item in items:
        tool_calls = None
        if item.get("tool_calls"):
            tool_calls = [
                ToolCall(id=tc["id"], name=tc["name"], arguments=tc["arguments"])
                for tc in item["tool_calls"]
            ]
        messages.append(AgentMessage(
            id=item.get("id", str(uuid.uuid4())),
            role=item["role"],
            content=item["content"],
            tool_calls=tool_calls,
            tool_call_id=item.get("tool_call_id"),
            tool_name=item.get("tool_name"),
            is_error=item.get("is_error", False),
            timestamp=item.get("timestamp", time.time()),
        ))
    return messages
