# Agent — Your Personal AI Harness

See [implementation_plan.md](implementation_plan.md) for full architecture and tech decisions.

## Architecture Overview

- **iOS**: SwiftUI + MVVM + @Observable, iOS 17+
- **Backend**: Python 3.12 + FastAPI + LangGraph + SQLite
- **Hosting**: Fly.io (auto-scaling, pay-per-use)
- **Voice**: Apple Speech STT + ElevenLabs/Apple TTS  
- **IAP**: StoreKit 2 native

## Scaling Path

| Users | Fly.io Setup | Cost |
|-------|-------------|------|
| 0–100 | Free tier (3 shared VMs) | $0/mo |
| 100–500 | shared-cpu-2x | ~$7/mo |
| 500–2000 | 2x shared-cpu-2x | ~$15/mo |
| 2000+ | Dedicated CPU + horizontal scale | ~$30-50/mo |
