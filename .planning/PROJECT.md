# MeetingScribe (OpenOats Fork)

## What This Is

A macOS meeting companion that transcribes any conversation — Zoom calls or in-person meetings — and automatically produces a structured summary with one-click Slack sharing. Built as a fork of OpenOats, stripped of the knowledge base feature, focused entirely on transcript → summary → share.

## Core Value

Every meeting produces a clear, shareable record — raw transcript, structured summary, and a ready-to-send Slack message — without manual note-taking.

## Requirements

### Validated

<!-- Inherited from OpenOats codebase -->

- ✓ Local speech-to-text via Parakeet/Whisper/Qwen3 models — existing
- ✓ Dual audio capture: microphone + system audio (for Zoom) — existing
- ✓ Real-time transcript display with speaker labels (you/them) — existing
- ✓ Acoustic echo suppression for duplicate detection — existing
- ✓ Session auto-save as timestamped plain text transcript — existing
- ✓ Structured JSONL session logs — existing
- ✓ Meeting app auto-detection (Zoom, Teams, Meet) — existing
- ✓ Multi-provider LLM support (OpenRouter, Ollama, MLX) — existing
- ✓ Menu bar app with recording controls — existing
- ✓ Audio recording to M4A — existing
- ✓ Configurable transcription model selection — existing
- ✓ Secure API key storage via macOS Keychain — existing

### Active

- [ ] Solo meeting mode (mic-only recording for in-person meetings and voice memos)
- [ ] Manual start for solo recording via menu bar
- [ ] Auto-generated structured summary on session end
- [ ] Summary covers: key decisions, action items, discussion points, open questions
- [ ] Slack message formatting from summary
- [ ] Post-meeting share screen with channel picker
- [ ] Slack webhook integration for auto-send
- [ ] Copy-to-clipboard as alternative to webhook
- [ ] Recurring meeting channel memory (auto-populate last-used channel)
- [ ] User-configurable Slack delivery preference (webhook, clipboard, or both)
- [ ] Strip knowledge base feature from UI and codebase

### Out of Scope

- Knowledge base / real-time note surfacing — stripping this to simplify, not core to transcript→summary→share flow
- Always-on listening / auto-start for solo mode — manual start is sufficient
- Mobile app — macOS only
- Multi-user / team features — personal tool
- Calendar integration for meeting detection — keep existing app-launch detection
- Real-time collaboration — single user

## Context

- Fork of [OpenOats](https://github.com/yazinsai/OpenOats) — Swift 6.2 macOS app
- Existing codebase has clean modular architecture: Audio → Transcription → Intelligence → Storage layers
- NotesEngine already exists for LLM-based meeting notes generation — can extend for structured summaries
- OpenRouterClient supports streaming + structured JSON responses — suitable for summary generation
- AppCoordinator manages full session lifecycle — natural place to hook post-meeting summary + Slack flow
- TranscriptLogger already saves plain text transcripts to ~/Documents/OpenOats/
- System audio capture uses Core Audio process taps — only needed for calls, not solo mode
- Solo mode can reuse MicCapture but skip SystemAudioCapture entirely

## Constraints

- **Platform**: macOS 15+ only — uses Core Audio APIs and Apple Silicon models
- **Privacy**: Audio stays local, only text sent to LLM providers for summaries
- **LLM flexibility**: Must support OpenRouter (cloud) and Ollama (local) for summaries
- **Slack API**: Webhook-based (no OAuth app install required) — user provides webhook URL in settings

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Strip knowledge base | Simplify app, not relevant to transcript→summary→share flow | — Pending |
| Slack webhook over OAuth bot | Simpler setup — user just pastes a webhook URL, no app review needed | — Pending |
| Manual start for solo mode | Avoids complexity of always-on listening, battery drain | — Pending |
| Keep multi-provider LLM | User wants flexibility between cloud and local models | — Pending |
| Post-meeting share screen | Better UX than auto-fire — user reviews summary, picks channel, sends | — Pending |
| Channel memory for recurring meetings | One-click re-share to same channel reduces friction | — Pending |

---
*Last updated: 2026-03-21 after initialization*
