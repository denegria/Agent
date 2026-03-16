"""LLM Proxy — Routes chat requests to user's chosen LLM provider using their API key.

All providers now use real streaming (SSE). Yields chunks as they arrive from the provider
so the agent loop can forward them to the client in real time.

Supports tool calling for providers that support it (Anthropic, OpenAI, Gemini, xAI).
Yields either str chunks (text response) or dict (tool_calls signal) for the agent loop.
"""

from __future__ import annotations

import json
from typing import AsyncIterator

import httpx


async def proxy_llm_request(
    provider: str,
    api_key: str,
    system_prompt: str,
    messages: list[dict],
    tools: list[dict] | None = None,
) -> AsyncIterator[str | dict]:
    """
    Stream LLM response using the user's API key.

    Yields:
        str: Text content chunks (streamed in real time)
        dict: {"type": "tool_calls", "tool_calls": [...]} when the LLM wants to call tools
    """
    if provider == "anthropic":
        async for chunk in _stream_anthropic(api_key, system_prompt, messages, tools):
            yield chunk
    elif provider == "openai":
        async for chunk in _stream_openai(api_key, system_prompt, messages, tools):
            yield chunk
    elif provider == "gemini":
        async for chunk in _stream_gemini(api_key, system_prompt, messages, tools):
            yield chunk
    elif provider == "xai":
        async for chunk in _stream_xai(api_key, system_prompt, messages, tools):
            yield chunk
    else:
        yield f"Error: Unknown provider '{provider}'. Supported: anthropic, openai, gemini, xai"


# ──────────────────────────────────────────────
# Anthropic (Claude) — Streaming
# ──────────────────────────────────────────────

async def _stream_anthropic(
    api_key: str, system_prompt: str, messages: list[dict], tools: list[dict] | None
) -> AsyncIterator[str | dict]:
    """Stream from Anthropic Claude API using SSE."""

    api_messages = []
    for m in messages:
        if m["role"] == "user":
            api_messages.append({"role": "user", "content": m["content"]})
        elif m["role"] == "assistant":
            api_messages.append({"role": "assistant", "content": m["content"]})
        elif m["role"] == "tool_result":
            api_messages.append({
                "role": "user",
                "content": [{
                    "type": "tool_result",
                    "tool_use_id": m.get("tool_call_id", ""),
                    "content": m["content"],
                    "is_error": m.get("is_error", False),
                }],
            })

    anthropic_tools = None
    if tools:
        anthropic_tools = [
            {"name": t["name"], "description": t["description"], "input_schema": t["parameters"]}
            for t in tools
        ]

    body: dict = {
        "model": "claude-sonnet-4-20250514",
        "max_tokens": 4096,
        "system": system_prompt,
        "messages": api_messages,
        "stream": True,
    }
    if anthropic_tools:
        body["tools"] = anthropic_tools

    tool_calls: list[dict] = []
    current_tool: dict = {}

    async with httpx.AsyncClient() as client:
        async with client.stream(
            "POST",
            "https://api.anthropic.com/v1/messages",
            headers={
                "x-api-key": api_key,
                "anthropic-version": "2023-06-01",
                "content-type": "application/json",
            },
            json=body,
            timeout=120.0,
        ) as response:
            if response.status_code != 200:
                error_body = await response.aread()
                yield f"Error from Anthropic (HTTP {response.status_code}): {error_body.decode()[:300]}"
                return

            async for line in response.aiter_lines():
                if not line.startswith("data: "):
                    continue
                data_str = line[6:]
                if data_str.strip() == "[DONE]":
                    break

                try:
                    event = json.loads(data_str)
                except json.JSONDecodeError:
                    continue

                event_type = event.get("type", "")

                if event_type == "content_block_start":
                    block = event.get("content_block", {})
                    if block.get("type") == "tool_use":
                        current_tool = {
                            "id": block.get("id", ""),
                            "name": block.get("name", ""),
                            "arguments_json": "",
                        }

                elif event_type == "content_block_delta":
                    delta = event.get("delta", {})
                    if delta.get("type") == "text_delta":
                        yield delta.get("text", "")
                    elif delta.get("type") == "input_json_delta":
                        if current_tool:
                            current_tool["arguments_json"] += delta.get("partial_json", "")

                elif event_type == "content_block_stop":
                    if current_tool:
                        try:
                            args = json.loads(current_tool["arguments_json"]) if current_tool["arguments_json"] else {}
                        except json.JSONDecodeError:
                            args = {}
                        tool_calls.append({
                            "id": current_tool["id"],
                            "name": current_tool["name"],
                            "arguments": args,
                        })
                        current_tool = {}

    if tool_calls:
        yield {"type": "tool_calls", "tool_calls": tool_calls}


# ──────────────────────────────────────────────
# OpenAI (GPT-4o) — Streaming
# ──────────────────────────────────────────────

async def _stream_openai(
    api_key: str, system_prompt: str, messages: list[dict], tools: list[dict] | None
) -> AsyncIterator[str | dict]:
    """Stream from OpenAI API using SSE."""

    all_messages = [{"role": "system", "content": system_prompt}]
    for m in messages:
        if m["role"] in ("user", "assistant"):
            all_messages.append({"role": m["role"], "content": m["content"]})
        elif m["role"] == "tool_result":
            all_messages.append({
                "role": "tool",
                "tool_call_id": m.get("tool_call_id", ""),
                "content": m["content"],
            })

    openai_tools = None
    if tools:
        openai_tools = [
            {"type": "function", "function": {"name": t["name"], "description": t["description"], "parameters": t["parameters"]}}
            for t in tools
        ]

    body: dict = {
        "model": "gpt-4o",
        "messages": all_messages,
        "max_tokens": 4096,
        "stream": True,
    }
    if openai_tools:
        body["tools"] = openai_tools

    tool_calls_map: dict[int, dict] = {}

    async with httpx.AsyncClient() as client:
        async with client.stream(
            "POST",
            "https://api.openai.com/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
            },
            json=body,
            timeout=120.0,
        ) as response:
            if response.status_code != 200:
                error_body = await response.aread()
                yield f"Error from OpenAI (HTTP {response.status_code}): {error_body.decode()[:300]}"
                return

            async for line in response.aiter_lines():
                if not line.startswith("data: "):
                    continue
                data_str = line[6:]
                if data_str.strip() == "[DONE]":
                    break

                try:
                    event = json.loads(data_str)
                except json.JSONDecodeError:
                    continue

                choices = event.get("choices", [])
                if not choices:
                    continue

                delta = choices[0].get("delta", {})

                # Text content
                if delta.get("content"):
                    yield delta["content"]

                # Tool calls (streamed incrementally)
                if delta.get("tool_calls"):
                    for tc_delta in delta["tool_calls"]:
                        idx = tc_delta.get("index", 0)
                        if idx not in tool_calls_map:
                            tool_calls_map[idx] = {
                                "id": tc_delta.get("id", ""),
                                "name": "",
                                "arguments_json": "",
                            }
                        if tc_delta.get("id"):
                            tool_calls_map[idx]["id"] = tc_delta["id"]
                        func = tc_delta.get("function", {})
                        if func.get("name"):
                            tool_calls_map[idx]["name"] = func["name"]
                        if func.get("arguments"):
                            tool_calls_map[idx]["arguments_json"] += func["arguments"]

    if tool_calls_map:
        tool_calls = []
        for tc in tool_calls_map.values():
            try:
                args = json.loads(tc["arguments_json"]) if tc["arguments_json"] else {}
            except json.JSONDecodeError:
                args = {}
            tool_calls.append({"id": tc["id"], "name": tc["name"], "arguments": args})
        yield {"type": "tool_calls", "tool_calls": tool_calls}


# ──────────────────────────────────────────────
# Google Gemini — Streaming
# ──────────────────────────────────────────────

async def _stream_gemini(
    api_key: str, system_prompt: str, messages: list[dict], tools: list[dict] | None
) -> AsyncIterator[str | dict]:
    """Stream from Google Gemini API."""

    contents = []
    for m in messages:
        if m["role"] in ("user", "assistant"):
            role = "user" if m["role"] == "user" else "model"
            contents.append({"role": role, "parts": [{"text": m["content"]}]})

    body: dict = {
        "system_instruction": {"parts": [{"text": system_prompt}]},
        "contents": contents,
    }

    if tools:
        body["tools"] = [{"function_declarations": [
            {"name": t["name"], "description": t["description"], "parameters": t["parameters"]}
            for t in tools
        ]}]

    # Gemini uses alt=sse for streaming
    async with httpx.AsyncClient() as client:
        async with client.stream(
            "POST",
            f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:streamGenerateContent?alt=sse&key={api_key}",
            headers={"Content-Type": "application/json"},
            json=body,
            timeout=120.0,
        ) as response:
            if response.status_code != 200:
                error_body = await response.aread()
                yield f"Error from Gemini (HTTP {response.status_code}): {error_body.decode()[:300]}"
                return

            tool_calls = []

            async for line in response.aiter_lines():
                if not line.startswith("data: "):
                    continue
                data_str = line[6:]

                try:
                    event = json.loads(data_str)
                except json.JSONDecodeError:
                    continue

                candidates = event.get("candidates", [])
                if not candidates:
                    continue

                parts = candidates[0].get("content", {}).get("parts", [])
                for part in parts:
                    if "text" in part:
                        yield part["text"]
                    elif "functionCall" in part:
                        fc = part["functionCall"]
                        tool_calls.append({
                            "id": f"gemini_{fc['name']}",
                            "name": fc["name"],
                            "arguments": fc.get("args", {}),
                        })

    if tool_calls:
        yield {"type": "tool_calls", "tool_calls": tool_calls}


# ──────────────────────────────────────────────
# xAI (Grok) — Streaming (OpenAI-compatible)
# ──────────────────────────────────────────────

async def _stream_xai(
    api_key: str, system_prompt: str, messages: list[dict], tools: list[dict] | None
) -> AsyncIterator[str | dict]:
    """Stream from xAI/Grok API (OpenAI-compatible)."""

    all_messages = [{"role": "system", "content": system_prompt}]
    for m in messages:
        if m["role"] in ("user", "assistant"):
            all_messages.append({"role": m["role"], "content": m["content"]})
        elif m["role"] == "tool_result":
            all_messages.append({
                "role": "tool",
                "tool_call_id": m.get("tool_call_id", ""),
                "content": m["content"],
            })

    openai_tools = None
    if tools:
        openai_tools = [
            {"type": "function", "function": {"name": t["name"], "description": t["description"], "parameters": t["parameters"]}}
            for t in tools
        ]

    body: dict = {
        "model": "grok-3",
        "messages": all_messages,
        "max_tokens": 4096,
        "stream": True,
    }
    if openai_tools:
        body["tools"] = openai_tools

    tool_calls_map: dict[int, dict] = {}

    async with httpx.AsyncClient() as client:
        async with client.stream(
            "POST",
            "https://api.x.ai/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
            },
            json=body,
            timeout=120.0,
        ) as response:
            if response.status_code != 200:
                error_body = await response.aread()
                yield f"Error from xAI (HTTP {response.status_code}): {error_body.decode()[:300]}"
                return

            async for line in response.aiter_lines():
                if not line.startswith("data: "):
                    continue
                data_str = line[6:]
                if data_str.strip() == "[DONE]":
                    break

                try:
                    event = json.loads(data_str)
                except json.JSONDecodeError:
                    continue

                choices = event.get("choices", [])
                if not choices:
                    continue

                delta = choices[0].get("delta", {})

                if delta.get("content"):
                    yield delta["content"]

                if delta.get("tool_calls"):
                    for tc_delta in delta["tool_calls"]:
                        idx = tc_delta.get("index", 0)
                        if idx not in tool_calls_map:
                            tool_calls_map[idx] = {"id": "", "name": "", "arguments_json": ""}
                        if tc_delta.get("id"):
                            tool_calls_map[idx]["id"] = tc_delta["id"]
                        func = tc_delta.get("function", {})
                        if func.get("name"):
                            tool_calls_map[idx]["name"] = func["name"]
                        if func.get("arguments"):
                            tool_calls_map[idx]["arguments_json"] += func["arguments"]

    if tool_calls_map:
        tool_calls = []
        for tc in tool_calls_map.values():
            try:
                args = json.loads(tc["arguments_json"]) if tc["arguments_json"] else {}
            except json.JSONDecodeError:
                args = {}
            tool_calls.append({"id": tc["id"], "name": tc["name"], "arguments": args})
        yield {"type": "tool_calls", "tool_calls": tool_calls}
