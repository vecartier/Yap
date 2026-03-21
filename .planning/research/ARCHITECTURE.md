# Architecture Research

**Domain:** Meeting transcription + summary + Slack integration (macOS native)
**Researched:** 2026-03-21
**Confidence:** HIGH

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Presentation Layer                        │
│  ┌──────────┐  ┌──────────────┐  ┌────────────────────┐     │
│  │ MenuBar  │  │ TranscriptUI │  │ PostMeetingShareUI │     │
│  └────┬─────┘  └──────┬───────┘  └────────┬───────────┘     │
├───────┴────────────────┴───────────────────┴─────────────────┤
│                     Coordination Layer                        │
│  ┌───────────────────────────────────────────────────────┐   │
│  │                   AppCoordinator                       │   │
│  └───────────────────────────────────────────────────────┘   │
├──────────────────────────────────────────────────────────────┤
│                     Intelligence Layer                        │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────┐     │
│  │ SummaryEngine│  │ SlackService │  │ OpenRouterClient│     │
│  └──────────────┘  └──────────────┘  └────────────────┘     │
├──────────────────────────────────────────────────────────────┤
│                     Capture Layer                             │
│  ┌──────────┐  ┌───────────────┐  ┌──────────────────┐      │
│  │MicCapture│  │SystemAudioCap │  │TranscriptionEng  │      │
│  └──────────┘  └───────────────┘  └──────────────────┘      │
├──────────────────────────────────────────────────────────────┤
│                     Persistence Layer                         │
│  ┌───────────────┐  ┌───────────────┐  ┌─────────────┐      │
│  │TranscriptStore│  │ SessionStore  │  │ChannelStore │      │
│  └───────────────┘  └───────────────┘  └─────────────┘      │
└──────────────────────────────────────────────────────────────┘
```

## New Components

### 1. Solo Mode (Audio Layer)

**Integration point:** `AppCoordinator.startSession()`

The existing flow starts both MicCapture and SystemAudioCapture. Solo mode only needs MicCapture.

**Approach:**
- Add `MeetingMode` enum: `.call` (mic + system) vs `.solo` (mic only)
- AppCoordinator checks mode before starting SystemAudioCapture
- TranscriptionEngine already handles mic-only — just don't feed system audio
- Speaker labels change: solo mode = single speaker ("you"), no "them"

**Data flow:**
```
Solo: Mic → StreamingTranscriber(mic) → Utterance(.you) → TranscriptStore
Call: Mic + System → StreamingTranscriber(mic) + StreamingTranscriber(sys) → Utterance(.you/.them) → TranscriptStore
```

### 2. Summary Engine (Intelligence Layer)

**Integration point:** `AppCoordinator.endSession()` → after transcript finalize

**Approach:**
- New `SummaryEngine` actor (sibling to existing `NotesEngine`)
- Input: Full transcript from TranscriptStore (array of Utterances)
- Output: `MeetingSummary` struct (decisions, action items, discussion points, open questions)
- Uses `OpenRouterClient` for LLM call (structured JSON output mode)
- Runs after session finalization, before showing share UI

**Data flow:**
```
endSession() → finalize transcript → SummaryEngine.generate(utterances) → MeetingSummary
  → MarkdownFormatter.format(summary) → save to ~/Documents/OpenOats/
  → SlackFormatter.format(summary) → feed to ShareUI
```

**LLM prompt structure:**
- System: "You are a meeting summarizer. Extract structured information."
- User: Full transcript with timestamps + speaker labels
- Response format: JSON with `decisions[]`, `action_items[]`, `discussion_points[]`, `open_questions[]`
- Use structured output (JSON mode) via OpenRouterClient.complete()

### 3. Slack Service (New Layer)

**New directory:** `OpenOats/Sources/OpenOats/Slack/`

**Components:**
- `SlackService` (actor) — sends messages via webhook URL
- `SlackFormatter` — converts MeetingSummary to Slack Block Kit JSON
- `ChannelStore` (actor) — persists channel preferences, maps meeting → channel

**Webhook approach (no OAuth needed):**
```swift
actor SlackService {
    func send(message: SlackMessage, webhookURL: URL) async throws -> Bool
}
```

- User creates Incoming Webhook in Slack workspace settings
- Pastes webhook URL in app settings (stored in Keychain)
- Multiple webhooks for multiple channels

**Channel memory:**
- Store mapping: meeting app bundle ID or manual label → webhook URL
- On recurring meetings, auto-populate last-used webhook
- Persist in UserDefaults (not sensitive — just channel names + webhook identifiers)

### 4. Post-Meeting Share UI (Presentation Layer)

**Integration point:** After SummaryEngine completes, AppCoordinator presents share window

**Flow:**
```
Summary generated → AppCoordinator.showShareUI(summary)
  → ShareView displays:
     - Formatted summary (read-only)
     - Channel picker (dropdown, remembers last choice)
     - "Send to Slack" button (if webhook configured)
     - "Copy to Clipboard" button (always available)
     - "Save & Close" button
```

**Window management:** New NSWindow/NSPanel (separate from menu bar popover), shown modally after meeting ends.

## Build Order (Dependencies)

```
Phase 1: Solo Mode + KB Removal
  - No dependencies on new features
  - Modifies: AppCoordinator, MeetingState, TranscriptionEngine
  - Removes: KnowledgeBase, SuggestionEngine, VoyageClient, OllamaEmbedClient

Phase 2: Summary Engine
  - Depends on: transcript store (existing)
  - New: SummaryEngine, MeetingSummary model, SlackFormatter
  - Modifies: AppCoordinator (hook into endSession)

Phase 3: Slack Integration + Share UI
  - Depends on: SummaryEngine (Phase 2)
  - New: SlackService, ChannelStore, ShareView
  - Modifies: AppSettings (webhook config), AppCoordinator (show share UI)
```

## Key Architectural Decisions

1. **SummaryEngine as actor** — matches existing pattern (SessionStore, TranscriptLogger are actors)
2. **Slack webhooks over Bot API** — no OAuth flow, no app review, user just pastes URL
3. **Structured JSON for summaries** — use OpenRouterClient's existing structured output support
4. **Separate share window** — don't cram into menu bar popover, give it proper screen space
5. **Channel memory in UserDefaults** — not sensitive data, simpler than Keychain
