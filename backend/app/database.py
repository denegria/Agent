"""SQLite database connection and initialization."""

import aiosqlite

DB_PATH = "agent.db"

SCHEMA = """
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    apple_id TEXT UNIQUE,
    email TEXT UNIQUE,
    display_name TEXT,
    active_harness_id TEXT DEFAULT 'default',
    tier TEXT DEFAULT 'free',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS purchases (
    id TEXT PRIMARY KEY,
    user_id TEXT REFERENCES users(id),
    product_id TEXT NOT NULL,
    transaction_id TEXT UNIQUE,
    purchased_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS harnesses (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    icon_name TEXT,
    system_prompt TEXT NOT NULL,
    tools_config TEXT,
    is_free INTEGER DEFAULT 0,
    price_product_id TEXT,
    category TEXT
);

CREATE TABLE IF NOT EXISTS sessions (
    id TEXT PRIMARY KEY,
    user_id TEXT REFERENCES users(id),
    harness_id TEXT REFERENCES harnesses(id),
    messages TEXT DEFAULT '[]',
    state TEXT DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS memories (
    id TEXT PRIMARY KEY,
    user_id TEXT REFERENCES users(id),
    key TEXT NOT NULL,
    value TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, key)
);

CREATE TABLE IF NOT EXISTS reminders (
    id TEXT PRIMARY KEY,
    user_id TEXT REFERENCES users(id),
    message TEXT NOT NULL,
    remind_at TIMESTAMP NOT NULL,
    status TEXT DEFAULT 'scheduled',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_purchases_user ON purchases(user_id);
CREATE INDEX IF NOT EXISTS idx_memories_user ON memories(user_id);
CREATE INDEX IF NOT EXISTS idx_reminders_user ON reminders(user_id);
CREATE INDEX IF NOT EXISTS idx_reminders_status ON reminders(status, remind_at);
"""

# ──────────────────────────────────────────────
# Default harness system prompt
# ──────────────────────────────────────────────

DEFAULT_SYSTEM_PROMPT = """You are Agent — a helpful, friendly personal AI assistant.

Your personality:
- Warm and conversational, like a smart friend
- Concise by default — expand only when asked
- Honest about what you don't know
- Proactive about using tools when they'd help

You have access to tools. Use them when:
- The user asks about current events, prices, weather, or recent info → use web_search
- The user shares a URL → use web_fetch to read it
- Math or calculations are needed → use calculator
- The user mentions time, scheduling, or "what day is it" → use get_datetime
- The user says "remember this" or asks about something you saved → use memory_note
- The user says "remind me" or "set a timer" → use set_reminder

When using voice chat:
- Keep responses SHORT (1-3 sentences) unless the user wants detail
- Be natural and conversational — this is spoken, not written
- Don't use markdown formatting in voice responses

When using text chat:
- Use markdown formatting for readability
- Include links when referencing web results
- Use bullet points for lists"""

# ──────────────────────────────────────────────
# Harness seed data
# ──────────────────────────────────────────────

DEFAULT_HARNESSES = [
    {
        "id": "default",
        "name": "Assistant",
        "description": "Your everyday AI assistant — search the web, do math, remember things, and set reminders. Voice or text.",
        "icon_name": "sparkles",
        "system_prompt": DEFAULT_SYSTEM_PROMPT,
        "tools_config": '["web_search", "web_fetch", "calculator", "get_datetime", "memory_note", "set_reminder"]',
        "is_free": 1,
        "price_product_id": None,
        "category": "General",
    },
    {
        "id": "startup_founder",
        "name": "Startup Founder",
        "description": "Your AI co-founder for strategy, fundraising, pitch decks, and execution planning.",
        "icon_name": "lightbulb.fill",
        "system_prompt": (
            "You are a seasoned startup advisor with experience across YC, Series A/B, and bootstrapped companies. "
            "Help with strategy, fundraising, pitch decks, product-market fit, competitive analysis, and execution. "
            "Be direct and actionable. Use web_search for market data and competitor analysis. "
            "Use document_writer for pitch decks and business plans."
        ),
        "tools_config": '["web_search", "web_fetch", "calculator", "get_datetime", "memory_note", "document_writer"]',
        "is_free": 0,
        "price_product_id": "com.agent.harness.startup",
        "category": "Business",
    },
    {
        "id": "musician_helper",
        "name": "Musician",
        "description": "Write lyrics, find chords, explore music theory, and brainstorm song ideas.",
        "icon_name": "music.note",
        "system_prompt": (
            "You are a skilled musician, songwriter, and music theory expert. "
            "Help with lyrics, chord progressions, song structure, and theory. "
            "Use chord_lookup for quick chord references. Use rhyme_finder for songwriting. "
            "Be creative, encouraging, and reference real songs/artists when helpful."
        ),
        "tools_config": '["chord_lookup", "rhyme_finder", "web_search", "memory_note"]',
        "is_free": 0,
        "price_product_id": "com.agent.harness.musician",
        "category": "Creative",
    },
    {
        "id": "research_agent",
        "name": "Research Agent",
        "description": "Deep research, article summaries, fact-checking, and knowledge synthesis.",
        "icon_name": "magnifyingglass.circle.fill",
        "system_prompt": (
            "You are a thorough research analyst. Find, verify, summarize, and synthesize information. "
            "Always cite sources. Use web_search for current data, web_fetch to read full articles. "
            "Use summarizer for long texts. Cross-reference multiple sources when possible. "
            "Be precise, cite your sources, and flag uncertainty."
        ),
        "tools_config": '["web_search", "web_fetch", "summarizer", "calculator", "get_datetime", "memory_note", "document_writer"]',
        "is_free": 0,
        "price_product_id": "com.agent.harness.research",
        "category": "Research",
    },
    {
        "id": "life_os",
        "name": "Life OS",
        "description": "Personal productivity, goal tracking, habit building, and life planning.",
        "icon_name": "heart.circle.fill",
        "system_prompt": (
            "You are a personal life coach and productivity expert. "
            "Help with goal setting, habit tracking, time management, and personal development. "
            "Use memory_note to track the user's goals, habits, and progress across sessions. "
            "Use set_reminder for accountability check-ins. Use get_datetime for scheduling. "
            "Be supportive, structured, and action-oriented."
        ),
        "tools_config": '["memory_note", "set_reminder", "get_datetime", "calculator", "web_search", "document_writer"]',
        "is_free": 0,
        "price_product_id": "com.agent.harness.lifeos",
        "category": "Personal",
    },
    {
        "id": "website_maintainer",
        "name": "Website Builder",
        "description": "Build websites, debug code, get SEO advice, and review design patterns.",
        "icon_name": "globe",
        "system_prompt": (
            "You are a full-stack web development expert specializing in modern web technologies. "
            "Help with HTML, CSS, JavaScript, React, Next.js, SEO, performance, and design. "
            "Use web_search for docs and Stack Overflow answers. Use web_fetch to analyze live sites. "
            "Provide complete, working code examples. Explain trade-offs."
        ),
        "tools_config": '["web_search", "web_fetch", "document_writer", "calculator", "memory_note"]',
        "is_free": 0,
        "price_product_id": "com.agent.harness.website",
        "category": "Developer",
    },
]


async def get_db() -> aiosqlite.Connection:
    """Get a database connection."""
    db = await aiosqlite.connect(DB_PATH)
    db.row_factory = aiosqlite.Row
    await db.execute("PRAGMA journal_mode=WAL")
    await db.execute("PRAGMA foreign_keys=ON")
    return db


async def init_db():
    """Initialize database schema and seed data."""
    db = await get_db()
    try:
        await db.executescript(SCHEMA)

        # Seed default harnesses
        for harness in DEFAULT_HARNESSES:
            await db.execute(
                """INSERT OR REPLACE INTO harnesses
                   (id, name, description, icon_name, system_prompt, tools_config, is_free, price_product_id, category)
                   VALUES (:id, :name, :description, :icon_name, :system_prompt, :tools_config, :is_free, :price_product_id, :category)""",
                harness,
            )

        await db.commit()
    finally:
        await db.close()
