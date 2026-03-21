# MeetingScribe (OpenOats Fork)

## What This Is

A native macOS meeting companion — like Granola — that automatically transcribes every meeting, generates structured summaries, and makes sharing effortless. Works for Zoom, Google Meet, Teams, in-person meetings, and solo voice memos. Privacy-first: audio never leaves your Mac.

The app has two surfaces: a minimal **menu bar icon** for recording controls, and a full **main app window** (sidebar + detail) for browsing meetings, reading transcripts/summaries, sharing to Slack, and managing settings.

## Core Value

Every meeting produces a clear, shareable record — raw transcript, structured summary, and a ready-to-paste Slack message — without manual note-taking. All meetings are saved, searchable, and browsable in one place.

## Requirements

### Validated

- ✓ Local speech-to-text via Parakeet/Whisper/Qwen3 models — existing
- ✓ Dual audio capture: microphone + system audio (for Zoom) — existing
- ✓ Acoustic echo suppression for duplicate detection — existing
- ✓ Session auto-save as timestamped plain text transcript — existing
- ✓ Structured JSONL session logs — existing
- ✓ Meeting app auto-detection (Zoom, Teams, Meet) — existing
- ✓ Multi-provider LLM support (OpenRouter, Ollama, MLX) — existing
- ✓ Audio recording to M4A — existing
- ✓ Configurable transcription model selection — existing
- ✓ Secure API key storage via macOS Keychain — existing
- ✓ Solo meeting mode with two flavors (memo/room) — Phase 1
- ✓ Knowledge base stripped from codebase — Phase 1
- ✓ Three-button menu bar (Start Call / Solo memo / Solo room) — Phase 1

### Active

<!-- v1 milestone — building now -->

**Summary Engine**
- [ ] Auto-generated structured summary on session end
- [ ] Summary sections: key decisions, action items, discussion points, open questions
- [ ] Two-phase LLM prompt (grounding + formatting) to minimize hallucination
- [ ] Works with OpenRouter (cloud) and Ollama (local)
- [ ] Summary saved as Markdown alongside transcript

**Main App Window**
- [ ] Sidebar + detail layout (like Granola / Apple Notes)
- [ ] Sidebar: chronological meeting list with date, title, duration
- [ ] Detail pane: Granola-style unified view — summary at top, transcript below
- [ ] Live transcript view during recording (in main window, not menu bar)
- [ ] Slack-formatted message with copy-to-clipboard button
- [ ] Meeting metadata: date, time, duration, meeting type

**Menu Bar**
- [ ] Minimal popover: recording status, start/stop buttons, "Open MeetingScribe" link
- [ ] Live transcript removed from menu bar (moved to main window)

**Search & Browse**
- [ ] Full-text search across all past transcripts and summaries
- [ ] Browse meetings chronologically

**Export**
- [ ] Export meeting to PDF (transcript + summary)

**Settings (in main window)**
- [ ] LLM provider selection (OpenRouter / Ollama)
- [ ] Transcription model selection
- [ ] API key management
- [ ] Audio input device selection

### Out of Scope (v1)

- Slack webhook auto-send — v2 (copy/paste is sufficient for v1)
- Calendar integration / auto-launch — v2
- Pre-meeting notifications — v2
- Meeting title from calendar/window — v2
- Participant names from calendar — v2
- Speaker diarization with names — unreliable
- Always-on listening — privacy risk, battery drain
- Real-time AI suggestions — stripped, not core
- Video recording — storage nightmare
- Collaborative editing — personal tool
- Mobile app — macOS only

### v2 Backlog

- Calendar integration (Google Calendar / Apple Calendar)
- 5-minute pre-meeting notification (Granola-style)
- Auto-launch recording when calendar meeting starts
- Meeting title pulled from calendar event / Zoom window title
- Participant names from calendar → used in summary attribution
- Slack webhook auto-send to configured channel
- Recurring meeting → auto-send to same Slack channel
- Zoom .vtt transcript import as cross-reference
- Action item tracking across meetings
- Weekly synthesis / digest

## Context

- Fork of [OpenOats](https://github.com/yazinsai/OpenOats) — Swift 6.2 macOS app
- Phase 1 complete: KB stripped, solo mode working, 58 tests passing
- Existing architecture: Audio → Transcription → Intelligence → Storage layers
- NotesEngine exists for LLM notes generation — extend for structured summaries
- OpenRouterClient supports streaming + structured JSON — suitable for summaries
- Current UI is menu bar popover only — needs full app window (NSWindow + SwiftUI)
- TranscriptLogger saves transcripts to ~/Documents/OpenOats/
- SessionStore saves JSONL session logs to ~/Library/Application Support/OpenOats/

## Constraints

- **Platform**: macOS 15+ only — Core Audio APIs, Apple Silicon models
- **Privacy**: Audio stays local, only text sent to LLM for summaries
- **LLM flexibility**: Must support OpenRouter (cloud) and Ollama (local)
- **UI framework**: SwiftUI for views, AppKit for window management (menu bar + main window)
- **No new dependencies**: URLSession for network, existing Keychain for secrets

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Strip knowledge base | Not core to transcript→summary→share | ✓ Good (Phase 1) |
| Manual start for solo mode | Avoids always-on complexity | ✓ Good (Phase 1) |
| Keep multi-provider LLM | Flexibility between cloud and local | ✓ Good |
| Sidebar + detail layout | Granola-style, natural for meeting history browsing | — Pending |
| Live transcript in main window only | Menu bar stays minimal, main window is the hub | — Pending |
| Settings as tab in main window | Not a separate preferences window, Granola-style | — Pending |
| Granola-style detail pane | Summary flows into transcript, not tabbed | — Pending |
| Slack copy/paste for v1 | Webhook auto-send deferred to v2, simpler first | — Pending |
| Calendar integration for v2 | Ship core flow first, add automation later | — Pending |

---
*Last updated: 2026-03-21 after scope reframe (Granola-style app window)*
