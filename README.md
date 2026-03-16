# 🎙️ Agent — Your Personal AI Harness

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-iOS%2017+-lightgrey.svg)
![Backend](https://img.shields.io/badge/backend-FastAPI%20%7C%20LangGraph-green.svg)

A beautifully native, voice-first iOS app where you bring your own LLM API keys (Anthropic, OpenAI, Gemini, xAI/Grok) and plug them in once. 

The magic lies in **Harnesses** — swappable, pre-built agent configurations that combine system prompts, external tools, knowledge bases, and custom integrations so your AI acts exactly how you need it to.

---

<p align="center">
  <!-- TODO: Replace with actual screenshot paths -->
  <img src="https://via.placeholder.com/250x500.png?text=Home+Screen" width="250" />
  &nbsp;&nbsp;&nbsp;
  <img src="https://via.placeholder.com/250x500.png?text=Voice+Interface" width="250" />
  &nbsp;&nbsp;&nbsp;
  <img src="https://via.placeholder.com/250x500.png?text=Harness+Marketplace" width="250" />
</p>

## ✨ Features

- **🔑 Bring Your Own Keys (BYOK):** No subscription lock-in. Use your own OpenAI, Anthropic, or Gemini API keys securely stored in the iOS Keychain.
- **🔌 Swappable Harnesses:** Switch between a Coding Assistant, a Personal Therapist, or a Language Tutor in seconds.
- **🗣️ Voice-First Native Experience:** Built with Apple Speech (STT) and seamless TTS support (ElevenLabs/Apple).
- **🛒 Harness Marketplace:** Browse and install community-made or premium AI configurations natively.

## 🛠️ Project Structure

```text
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

## 🚀 Quick Start

### iOS App
1. Open `ios/Agent.xcodeproj` in Xcode.
2. Select **iPhone 16 Pro** (or compatible iOS 17+ simulator).
3. Hit `Cmd + R` to run.

### Backend Server
1. Navigate to the backend directory:
   ```bash
   cd backend
   ```
2. Install the package in editable mode:
   ```bash
   pip install -e .
   ```
3. Run the Uvicorn dev server:
   ```bash
   uvicorn app.main:app --reload
   ```

## 💻 Tech Stack

- **iOS:** SwiftUI, MVVM + `@Observable`, iOS 17+, StoreKit 2
- **Backend:** Python 3.12, FastAPI, LangGraph, SQLite
- **Voice Capabilities:** Apple Speech (STT) + ElevenLabs / Native Apple TTS
- **Infrastructure:** Ready for Fly.io deployment

---

*Because generic chatbots are boring. Build your harness.*
