# Agent — Your Personal AI Harness

A voice-first iOS app where users bring their own LLM API keys (Anthropic, OpenAI, Gemini, xAI/Grok) and plug them in once. The magic is **Harnesses** — swappable, pre-built agent configurations that combine system prompts, tools, knowledge, and integrations.

## Project Structure

```
Agent/
├── docs/                    # Architecture & planning docs
│   └── implementation_plan.md
├── ios/Agent/               # SwiftUI iOS app (iOS 17+)
│   ├── Core/                # Design system, keychain, networking, models
│   ├── Features/            # Auth, Home, Chat, Voice, Marketplace, Settings
│   └── Navigation/          # App router
└── backend/                 # FastAPI + LangGraph backend
    └── app/                 # Auth, chat, harnesses, IAP, users
```

## Quick Start

### iOS
Open `ios/Agent.xcodeproj` in Xcode → Run on iPhone 16 simulator.

### Backend
```bash
cd backend
pip install -e .
uvicorn app.main:app --reload
```

## Tech Stack
- **iOS**: SwiftUI, MVVM + @Observable, iOS 17+, StoreKit 2
- **Backend**: Python 3.12, FastAPI, LangGraph, SQLite
- **Voice**: Apple Speech (STT) + ElevenLabs/Apple TTS
- **Hosting**: Fly.io
