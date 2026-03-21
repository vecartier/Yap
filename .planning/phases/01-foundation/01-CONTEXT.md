# Phase 1: Foundation - Context

**Gathered:** 2026-03-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Strip the knowledge base feature entirely (code, UI, settings, dependencies) and add a mic-only solo recording mode with two flavors: voice memo (labeled "You") and room meeting (labeled "Room"). Existing call mode and auto-detection remain unchanged.

</domain>

<decisions>
## Implementation Decisions

### KB Removal
- Full deletion — not disable, not hide. Remove all KB files and references
- Delete: `KnowledgeBase.swift`, `SuggestionEngine.swift`, `VoyageClient.swift`, `OllamaEmbedClient.swift`
- Remove all KB references from `ContentView.swift` (knowledgeBase, suggestionEngine state vars, indexing, suggestion UI)
- Remove KB references from `SessionStore.swift` (suggestionEngine parameter, decision/suggestion fields)
- Remove KB-related settings: folder picker, embedding provider selector, `EmbeddingProvider` enum, Voyage API key
- Remove orphaned `AppSettings` properties related to KB/embedding
- Clean `AppRuntime.swift` of any KB initialization

### Solo Mode — Two Flavors
- **Voice memo**: mic-only, speaker labeled "You" — for personal dictation and thinking out loud
- **Room meeting**: mic-only, speaker labeled "Room" — for in-person meetings captured via laptop mic
- Both produce timestamped transcripts in the same format as call transcripts
- No system audio capture in either solo mode

### Menu Bar UI
- Three explicit buttons: "Start Call" / "Solo (memo)" / "Solo (room)"
- No dropdown or popover — direct action buttons
- Existing auto-detect for Zoom/Teams/Meet stays — auto-starts in Call mode when meeting app detected

### Speaker Labeling
- Call mode: "You" (mic) + "Them" (system audio) — unchanged
- Solo memo: "You" only — single speaker stream
- Solo room: "Room" only — signals to summary engine that multiple speakers may be present in one stream

### Claude's Discretion
- `MeetingMode` enum design (`.call`, `.soloMemo`, `.soloRoom` or similar)
- How TranscriptionEngine handles mic-only mode (skip system audio setup)
- Whether to add MeetingMode to session metadata for downstream use
- Exact button styling/positioning in menu bar

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### KB code to remove
- `OpenOats/Sources/OpenOats/Intelligence/KnowledgeBase.swift` — Main KB class, imports VoyageClient + OllamaEmbedClient
- `OpenOats/Sources/OpenOats/Intelligence/SuggestionEngine.swift` — Consumes KB, feeds suggestions to UI
- `OpenOats/Sources/OpenOats/Intelligence/VoyageClient.swift` — Embedding client for Voyage AI
- `OpenOats/Sources/OpenOats/Intelligence/OllamaEmbedClient.swift` — Embedding client for Ollama

### Files with KB references to clean
- `OpenOats/Sources/OpenOats/Views/ContentView.swift` — KB/suggestion state vars, indexing logic, suggestion display
- `OpenOats/Sources/OpenOats/Storage/SessionStore.swift` — SuggestionEngine parameter in appendRecord
- `OpenOats/Sources/OpenOats/App/AppRuntime.swift` — KB initialization references
- `OpenOats/Sources/OpenOats/Settings/AppSettings.swift` — KB folder, embedding provider, Voyage API key settings

### Audio capture (solo mode integration points)
- `OpenOats/Sources/OpenOats/Audio/MicCapture.swift` — Reuse as-is for solo mode
- `OpenOats/Sources/OpenOats/Audio/SystemAudioCapture.swift` — Skip in solo mode
- `OpenOats/Sources/OpenOats/Transcription/TranscriptionEngine.swift` — Dual-stream orchestrator, needs mode-aware path
- `OpenOats/Sources/OpenOats/App/AppCoordinator.swift` — Session lifecycle, needs MeetingMode routing

### Meeting detection
- `OpenOats/Sources/OpenOats/Meeting/MeetingState.swift` — State machine for meeting lifecycle
- `OpenOats/Sources/OpenOats/Meeting/` — Meeting detection, auto-start logic

No external specs — requirements fully captured in decisions above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `MicCapture`: Already a standalone audio capture class — solo mode reuses it directly
- `TranscriptStore`: Speaker enum has `.you` and `.them` — needs extension for `.room`
- `TranscriptLogger`: Plain text output, speaker-agnostic — works as-is with new labels
- `SessionStore`: JSONL persistence — works as-is once KB references removed
- `AppCoordinator`: Session lifecycle orchestrator — natural place for MeetingMode routing

### Established Patterns
- Actor isolation for persistence (SessionStore, TranscriptLogger)
- @Observable for UI-bound state (AppCoordinator, TranscriptStore)
- AsyncStream for audio buffer delivery
- `MeetingState` enum-based state machine for lifecycle transitions

### Integration Points
- `AppCoordinator.startSession()` — where MeetingMode determines which audio engines to start
- `TranscriptionEngine.start()` — needs to conditionally skip system audio
- `ContentView` menu bar — where three mode buttons replace single Start button
- `Speaker` enum in Models.swift — needs `.room` case
- `MeetingMetadata` — should carry MeetingMode for downstream phases (summary engine)

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 01-foundation*
*Context gathered: 2026-03-21*
