"""
Harness tools — tool definitions loaded per harness.

Default harness tools (safe, read-only, high-utility):
  - web_search    → Search the web (Brave API)
  - web_fetch     → Read & summarize a URL
  - calculator    → Safe math evaluation
  - get_datetime  → Current date/time + timezone
  - memory_note   → Save/recall user preferences across sessions
  - set_reminder  → Schedule a push notification reminder

Premium harness tools (unlocked via IAP):
  - document_writer, chord_lookup, rhyme_finder, code_runner, etc.
"""

from __future__ import annotations

import json
import math
import os
import uuid
from datetime import datetime, timezone, timedelta

import httpx

from app.chat.agent_loop import AgentTool, ToolResult


# ──────────────────────────────────────────────
# Tool registry
# ──────────────────────────────────────────────

TOOL_REGISTRY: dict[str, AgentTool] = {}


def get_tools_for_harness(tools_config: list[str] | str | None) -> list[AgentTool]:
    """Load the tools specified by a harness's tools_config."""
    if not tools_config:
        return []

    if isinstance(tools_config, str):
        try:
            tools_config = json.loads(tools_config)
        except (json.JSONDecodeError, TypeError):
            return []

    return [TOOL_REGISTRY[name] for name in tools_config if name in TOOL_REGISTRY]


# =============================================
#  DEFAULT HARNESS TOOLS (free, safe, minimal)
# =============================================


# ──────────────────────────────────────────────
# 1. web_search — Search the web
# ──────────────────────────────────────────────

async def _web_search_execute(tool_call_id: str, args: dict) -> ToolResult:
    """Search the web using Brave Search API. Falls back gracefully."""
    query = args.get("query", "")
    count = min(int(args.get("count", 5)), 10)

    brave_key = os.getenv("BRAVE_API_KEY", "")

    if not brave_key:
        return ToolResult(
            content=f"Web search for '{query}': No search API key configured. "
                    "Please set BRAVE_API_KEY in your backend environment. "
                    "Get a free key at https://brave.com/search/api/",
        )

    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(
                "https://api.search.brave.com/res/v1/web/search",
                headers={
                    "Accept": "application/json",
                    "X-Subscription-Token": brave_key,
                },
                params={"q": query, "count": count},
                timeout=15.0,
            )
            response.raise_for_status()
            data = response.json()

        results = data.get("web", {}).get("results", [])
        if not results:
            return ToolResult(content=f"No results found for '{query}'.")

        # Format results clearly for the LLM
        formatted = []
        for i, r in enumerate(results[:count], 1):
            title = r.get("title", "")
            url = r.get("url", "")
            description = r.get("description", "")
            formatted.append(f"{i}. **{title}**\n   {url}\n   {description}")

        return ToolResult(
            content=f"Search results for '{query}':\n\n" + "\n\n".join(formatted),
            details={"result_count": len(results)},
        )

    except httpx.HTTPStatusError as e:
        return ToolResult(
            content=f"Search failed (HTTP {e.response.status_code}): {e.response.text[:200]}",
            is_error=True,
        )
    except Exception as e:
        return ToolResult(content=f"Search error: {str(e)}", is_error=True)


TOOL_REGISTRY["web_search"] = AgentTool(
    name="web_search",
    description=(
        "Search the web for current information on any topic. "
        "Use this when the user asks about recent events, facts you're unsure about, "
        "prices, weather, news, or anything that might be outdated in your training data."
    ),
    parameters={
        "type": "object",
        "properties": {
            "query": {
                "type": "string",
                "description": "The search query — be specific for better results"
            },
            "count": {
                "type": "integer",
                "description": "Number of results (1-10, default 5)"
            }
        },
        "required": ["query"]
    },
    execute=_web_search_execute,
)


# ──────────────────────────────────────────────
# 2. web_fetch — Read a URL's content
# ──────────────────────────────────────────────

async def _web_fetch_execute(tool_call_id: str, args: dict) -> ToolResult:
    """Fetch and extract text content from a URL."""
    url = args.get("url", "")
    max_chars = min(int(args.get("max_chars", 8000)), 50000)

    if not url:
        return ToolResult(content="Error: No URL provided.", is_error=True)

    try:
        async with httpx.AsyncClient(follow_redirects=True) as client:
            response = await client.get(
                url,
                headers={
                    "User-Agent": "Agent-Bot/1.0 (Personal AI Assistant)",
                    "Accept": "text/html,text/plain,application/json",
                },
                timeout=20.0,
            )
            response.raise_for_status()

        content_type = response.headers.get("content-type", "")
        text = response.text

        # Basic HTML stripping (good enough for LLM consumption)
        if "html" in content_type:
            import re
            # Remove script/style blocks
            text = re.sub(r"<script[^>]*>.*?</script>", "", text, flags=re.DOTALL | re.IGNORECASE)
            text = re.sub(r"<style[^>]*>.*?</style>", "", text, flags=re.DOTALL | re.IGNORECASE)
            # Remove HTML tags
            text = re.sub(r"<[^>]+>", " ", text)
            # Clean whitespace
            text = re.sub(r"\s+", " ", text).strip()

        # Truncate
        if len(text) > max_chars:
            text = text[:max_chars] + f"\n\n[Truncated at {max_chars} characters]"

        return ToolResult(
            content=f"Content from {url}:\n\n{text}",
            details={"url": url, "char_count": len(text)},
        )

    except httpx.HTTPStatusError as e:
        return ToolResult(
            content=f"Failed to fetch {url} (HTTP {e.response.status_code})",
            is_error=True,
        )
    except Exception as e:
        return ToolResult(content=f"Fetch error: {str(e)}", is_error=True)


TOOL_REGISTRY["web_fetch"] = AgentTool(
    name="web_fetch",
    description=(
        "Fetch and read the content of a web page URL. "
        "Use this when the user shares a link and wants you to summarize it, "
        "extract information from it, or answer questions about its content."
    ),
    parameters={
        "type": "object",
        "properties": {
            "url": {
                "type": "string",
                "description": "The URL to fetch"
            },
            "max_chars": {
                "type": "integer",
                "description": "Max characters to return (default 8000, max 50000)"
            }
        },
        "required": ["url"]
    },
    execute=_web_fetch_execute,
)


# ──────────────────────────────────────────────
# 3. calculator — Safe math evaluation
# ──────────────────────────────────────────────

async def _calculator_execute(tool_call_id: str, args: dict) -> ToolResult:
    """Safely evaluate a math expression with no access to builtins."""
    expr = args.get("expression", "")
    try:
        allowed = {
            "sqrt": math.sqrt, "abs": abs, "round": round,
            "sin": math.sin, "cos": math.cos, "tan": math.tan,
            "asin": math.asin, "acos": math.acos, "atan": math.atan,
            "log": math.log, "log2": math.log2, "log10": math.log10,
            "pow": pow, "ceil": math.ceil, "floor": math.floor,
            "pi": math.pi, "e": math.e, "inf": math.inf,
        }
        result = eval(expr, {"__builtins__": {}}, allowed)
        return ToolResult(content=f"{expr} = {result}")
    except ZeroDivisionError:
        return ToolResult(content=f"Error: Division by zero in '{expr}'", is_error=True)
    except Exception as e:
        return ToolResult(content=f"Error evaluating '{expr}': {e}", is_error=True)


TOOL_REGISTRY["calculator"] = AgentTool(
    name="calculator",
    description=(
        "Evaluate a mathematical expression. Supports arithmetic (+, -, *, /, **, %), "
        "functions (sqrt, sin, cos, tan, log, log10, ceil, floor, abs, round, pow), "
        "and constants (pi, e). Use this for any calculation the user asks about."
    ),
    parameters={
        "type": "object",
        "properties": {
            "expression": {
                "type": "string",
                "description": "The math expression, e.g. 'sqrt(144)', '15/100 * 87', 'sin(pi/4)'"
            }
        },
        "required": ["expression"]
    },
    execute=_calculator_execute,
)


# ──────────────────────────────────────────────
# 4. get_datetime — Current date and time
# ──────────────────────────────────────────────

async def _get_datetime_execute(tool_call_id: str, args: dict) -> ToolResult:
    """Get the current date/time with formatting."""
    now = datetime.now(timezone.utc)
    # Also provide common formats for convenience
    return ToolResult(
        content=(
            f"Current date and time (UTC): {now.strftime('%A, %B %d, %Y at %I:%M %p')} UTC\n"
            f"ISO format: {now.isoformat()}\n"
            f"Unix timestamp: {int(now.timestamp())}\n"
            f"Day of week: {now.strftime('%A')}\n"
            f"Week number: {now.isocalendar()[1]}"
        ),
    )


TOOL_REGISTRY["get_datetime"] = AgentTool(
    name="get_datetime",
    description=(
        "Get the current date, time, and day of week. "
        "Use this when the user asks what time/day it is, or when you need time context "
        "for scheduling, reminders, or time-sensitive answers."
    ),
    parameters={
        "type": "object",
        "properties": {},
        "required": []
    },
    execute=_get_datetime_execute,
)


# ──────────────────────────────────────────────
# 5. memory_note — SQLite-backed persistent memory
# ──────────────────────────────────────────────


async def _memory_note_execute(tool_call_id: str, args: dict) -> ToolResult:
    """Save, recall, list, or delete user memory notes. Persisted in SQLite."""
    from app.database import get_db

    action = args.get("action", "save")
    user_id = args.get("user_id", "default")
    key = args.get("key", "")
    value = args.get("value", "")

    db = await get_db()
    try:
        if action == "save":
            if not key or not value:
                return ToolResult(content="Error: Both 'key' and 'value' required to save.", is_error=True)
            await db.execute(
                """INSERT INTO memories (id, user_id, key, value)
                   VALUES (?, ?, ?, ?)
                   ON CONFLICT(user_id, key) DO UPDATE SET value = ?, updated_at = CURRENT_TIMESTAMP""",
                (str(uuid.uuid4()), user_id, key, value, value),
            )
            await db.commit()
            return ToolResult(
                content=f"✓ Saved: '{key}' = '{value}'",
                details={"key": key, "action": "saved"},
            )

        elif action == "recall":
            if not key:
                return ToolResult(content="Error: 'key' required to recall.", is_error=True)
            cursor = await db.execute(
                "SELECT value FROM memories WHERE user_id = ? AND key = ?",
                (user_id, key),
            )
            row = await cursor.fetchone()
            if row:
                return ToolResult(content=f"Memory '{key}': {row[0]}")
            return ToolResult(content=f"No memory found for key '{key}'.")

        elif action == "list":
            cursor = await db.execute(
                "SELECT key, value FROM memories WHERE user_id = ? ORDER BY updated_at DESC",
                (user_id,),
            )
            rows = await cursor.fetchall()
            if not rows:
                return ToolResult(content="No memories saved yet.")
            items = [f"• {r[0]}: {r[1]}" for r in rows]
            return ToolResult(content=f"Saved memories ({len(items)}):\n" + "\n".join(items))

        elif action == "delete":
            cursor = await db.execute(
                "DELETE FROM memories WHERE user_id = ? AND key = ? RETURNING key",
                (user_id, key),
            )
            deleted = await cursor.fetchone()
            await db.commit()
            if deleted:
                return ToolResult(content=f"✓ Deleted memory: '{key}'")
            return ToolResult(content=f"No memory found for key '{key}'.")

        else:
            return ToolResult(content=f"Unknown action: '{action}'. Use save/recall/list/delete.", is_error=True)
    finally:
        await db.close()


TOOL_REGISTRY["memory_note"] = AgentTool(
    name="memory_note",
    description=(
        "Save and recall user preferences, facts, and notes across conversations. "
        "Use 'save' when the user tells you something to remember (name, preferences, facts). "
        "Use 'recall' to look up previously saved info. 'list' shows all memories. "
        "'delete' removes a memory. This persists across sessions."
    ),
    parameters={
        "type": "object",
        "properties": {
            "action": {
                "type": "string",
                "enum": ["save", "recall", "list", "delete"],
                "description": "The action: save, recall, list, or delete"
            },
            "key": {
                "type": "string",
                "description": "Memory key (e.g. 'dog_name', 'favorite_food', 'work_schedule')"
            },
            "value": {
                "type": "string",
                "description": "Value to save (only needed for 'save' action)"
            },
            "user_id": {
                "type": "string",
                "description": "User ID for scoped memory (auto-injected by the system)"
            }
        },
        "required": ["action"]
    },
    execute=_memory_note_execute,
)


# ──────────────────────────────────────────────
# 6. set_reminder — SQLite-backed reminders
# ──────────────────────────────────────────────


async def _set_reminder_execute(tool_call_id: str, args: dict) -> ToolResult:
    """Set, list, or cancel reminders. Persisted in SQLite."""
    from app.database import get_db

    action = args.get("action", "set")
    user_id = args.get("user_id", "default")

    db = await get_db()
    try:
        if action == "set":
            message = args.get("message", "")
            minutes = int(args.get("minutes_from_now", 30))

            if not message:
                return ToolResult(content="Error: 'message' is required.", is_error=True)

            now = datetime.now(timezone.utc)
            remind_at = now + timedelta(minutes=minutes)
            reminder_id = str(uuid.uuid4())[:8]

            await db.execute(
                "INSERT INTO reminders (id, user_id, message, remind_at) VALUES (?, ?, ?, ?)",
                (reminder_id, user_id, message, remind_at.isoformat()),
            )
            await db.commit()

            # Format time nicely
            if minutes < 60:
                time_str = f"{minutes} minute{'s' if minutes != 1 else ''}"
            elif minutes < 1440:
                hours = minutes / 60
                time_str = f"{hours:.1f} hour{'s' if hours != 1 else ''}"
            else:
                days = minutes / 1440
                time_str = f"{days:.1f} day{'s' if days != 1 else ''}"

            return ToolResult(
                content=(
                    f"⏰ Reminder set!\n"
                    f"Message: {message}\n"
                    f"When: in {time_str} ({remind_at.strftime('%I:%M %p')} UTC)\n"
                    f"ID: {reminder_id}"
                ),
                details={"reminder_id": reminder_id, "remind_at": remind_at.isoformat()},
            )

        elif action == "list":
            cursor = await db.execute(
                "SELECT id, message, remind_at, status FROM reminders WHERE user_id = ? ORDER BY remind_at",
                (user_id,),
            )
            rows = await cursor.fetchall()
            if not rows:
                return ToolResult(content="No reminders set.")
            items = []
            for r in rows:
                icon = "✅" if r[3] == "delivered" else ("❌" if r[3] == "cancelled" else "⏳")
                items.append(f"{icon} [{r[0]}] {r[1]} — {r[2]}")
            return ToolResult(content=f"Reminders ({len(items)}):\n" + "\n".join(items))

        elif action == "cancel":
            reminder_id = args.get("reminder_id", "")
            cursor = await db.execute(
                "UPDATE reminders SET status = 'cancelled' WHERE id = ? AND user_id = ? RETURNING id",
                (reminder_id, user_id),
            )
            row = await cursor.fetchone()
            await db.commit()
            if row:
                return ToolResult(content=f"✓ Reminder '{reminder_id}' cancelled.")
            return ToolResult(content=f"Reminder '{reminder_id}' not found.", is_error=True)

        else:
            return ToolResult(content=f"Unknown action: '{action}'.", is_error=True)
    finally:
        await db.close()


TOOL_REGISTRY["set_reminder"] = AgentTool(
    name="set_reminder",
    description=(
        "Set a reminder to notify the user after a specified time. "
        "Use this when the user says things like 'remind me in 30 minutes', "
        "'set a timer for 1 hour', or 'don't let me forget to...' "
        "Also supports listing and cancelling reminders."
    ),
    parameters={
        "type": "object",
        "properties": {
            "action": {
                "type": "string",
                "enum": ["set", "list", "cancel"],
                "description": "set = create reminder, list = show all, cancel = remove one"
            },
            "message": {
                "type": "string",
                "description": "What to remind the user about"
            },
            "minutes_from_now": {
                "type": "integer",
                "description": "Minutes until reminder fires (default 30). Use 60 for 1 hour, 1440 for 1 day."
            },
            "reminder_id": {
                "type": "string",
                "description": "ID of reminder to cancel (only for 'cancel' action)"
            },
            "user_id": {
                "type": "string",
                "description": "User ID (auto-injected by the system)"
            }
        },
        "required": ["action"]
    },
    execute=_set_reminder_execute,
)


# =============================================
#  PREMIUM HARNESS TOOLS (unlocked via IAP)
# =============================================


# ──────────────────────────────────────────────
# document_writer — Structured document creation
# ──────────────────────────────────────────────

async def _document_writer_execute(tool_call_id: str, args: dict) -> ToolResult:
    """Write or format a document."""
    title = args.get("title", "Untitled")
    content = args.get("content", "")
    format_type = args.get("format", "markdown")
    return ToolResult(
        content=f"# {title}\n\n{content}",
        details={"format": format_type, "word_count": len(content.split())},
    )


TOOL_REGISTRY["document_writer"] = AgentTool(
    name="document_writer",
    description="Write or format a structured document (markdown, outline, report).",
    parameters={
        "type": "object",
        "properties": {
            "title": {"type": "string", "description": "Document title"},
            "content": {"type": "string", "description": "Document content"},
            "format": {
                "type": "string",
                "enum": ["markdown", "outline", "report"],
                "description": "Output format"
            }
        },
        "required": ["title", "content"]
    },
    execute=_document_writer_execute,
)


# ──────────────────────────────────────────────
# chord_lookup — Music theory (Musician harness)
# ──────────────────────────────────────────────

async def _chord_lookup_execute(tool_call_id: str, args: dict) -> ToolResult:
    chord = args.get("chord", "C")
    chords_db = {
        "C": "C E G — I chord in C major", "Cm": "C Eb G — i chord in C minor",
        "D": "D F# A — II chord", "Dm": "D F A — ii chord in C major",
        "E": "E G# B — III chord", "Em": "E G B — iii chord in C major",
        "F": "F A C — IV chord in C major", "Fm": "F Ab C",
        "G": "G B D — V chord in C major", "Gm": "G Bb D",
        "A": "A C# E — VI chord", "Am": "A C E — vi chord in C major",
        "B": "B D# F# — VII chord", "Bm": "B D F#",
        "C7": "C E G Bb — dominant 7th", "Cmaj7": "C E G B — major 7th",
        "Am7": "A C E G — minor 7th", "Dm7": "D F A C — minor 7th",
        "G7": "G B D F — dominant 7th", "Fmaj7": "F A C E — major 7th",
    }
    info = chords_db.get(chord, f"Chord '{chord}': not in quick reference. Try a music theory resource.")
    return ToolResult(content=info)


TOOL_REGISTRY["chord_lookup"] = AgentTool(
    name="chord_lookup",
    description="Look up notes and theory info for a chord.",
    parameters={
        "type": "object",
        "properties": {
            "chord": {"type": "string", "description": "Chord name, e.g. 'Am', 'G7', 'Cmaj7'"}
        },
        "required": ["chord"]
    },
    execute=_chord_lookup_execute,
)


# ──────────────────────────────────────────────
# rhyme_finder — Songwriting (Musician harness)
# ──────────────────────────────────────────────

async def _rhyme_finder_execute(tool_call_id: str, args: dict) -> ToolResult:
    word = args.get("word", "")
    # Placeholder — connect Datamuse API for production
    try:
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                f"https://api.datamuse.com/words?rel_rhy={word}&max=10",
                timeout=5.0,
            )
            resp.raise_for_status()
            words = [w["word"] for w in resp.json()]
            if words:
                return ToolResult(content=f"Rhymes for '{word}': {', '.join(words)}")
    except Exception:
        pass

    return ToolResult(content=f"Could not find rhymes for '{word}'. Try a different word.")


TOOL_REGISTRY["rhyme_finder"] = AgentTool(
    name="rhyme_finder",
    description="Find words that rhyme with a given word (uses Datamuse API).",
    parameters={
        "type": "object",
        "properties": {
            "word": {"type": "string", "description": "The word to find rhymes for"}
        },
        "required": ["word"]
    },
    execute=_rhyme_finder_execute,
)


# ──────────────────────────────────────────────
# summarizer — Condense text (Research harness)
# ──────────────────────────────────────────────

async def _summarizer_execute(tool_call_id: str, args: dict) -> ToolResult:
    """Return structured text for the LLM to summarize (the LLM does the actual work)."""
    text = args.get("text", "")
    style = args.get("style", "concise")
    if not text:
        return ToolResult(content="Error: no text provided to summarize.", is_error=True)

    word_count = len(text.split())
    return ToolResult(
        content=(
            f"[Summarize the following {word_count}-word text in {style} style]\n\n"
            f"{text[:10000]}"  # Cap input to 10k chars
        ),
        details={"word_count": word_count, "style": style},
    )


TOOL_REGISTRY["summarizer"] = AgentTool(
    name="summarizer",
    description="Summarize a long piece of text into a concise version.",
    parameters={
        "type": "object",
        "properties": {
            "text": {"type": "string", "description": "The text to summarize"},
            "style": {
                "type": "string",
                "enum": ["concise", "bullet_points", "detailed"],
                "description": "Summary style"
            }
        },
        "required": ["text"]
    },
    execute=_summarizer_execute,
)
