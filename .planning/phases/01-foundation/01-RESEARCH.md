# Phase 1: Foundation - Research

**Researched:** 2026-03-21
**Domain:** Swift/SwiftUI macOS app — KB feature removal and solo recording mode addition
**Confidence:** HIGH (all findings from direct codebase inspection)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **KB Removal:** Full deletion — not disable, not hide. Remove all KB files and references.
  - Delete: `KnowledgeBase.swift`, `SuggestionEngine.swift`, `VoyageClient.swift`, `OllamaEmbedClient.swift`
  - Remove all KB references from `ContentView.swift` (knowledgeBase, suggestionEngine state vars, indexing, suggestion UI)
  - Remove KB references from `SessionStore.swift` (suggestionEngine parameter, decision/suggestion fields)
  - Remove KB-related settings: folder picker, embedding provider selector, `EmbeddingProvider` enum, Voyage API key
  - Remove orphaned `AppSettings` properties related to KB/embedding
  - Clean `AppRuntime.swift` of any KB initialization
- **Solo Mode — Two Flavors:**
  - Voice memo: mic-only, speaker labeled "You" — for personal dictation and thinking out loud
  - Room meeting: mic-only, speaker labeled "Room" — for in-person meetings captured via laptop mic
  - Both produce timestamped transcripts in the same format as call transcripts
  - No system audio capture in either solo mode
- **Menu Bar UI:**
  - Three explicit buttons: "Start Call" / "Solo (memo)" / "Solo (room)"
  - No dropdown or popover — direct action buttons
  - Existing auto-detect for Zoom/Teams/Meet stays — auto-starts in Call mode when meeting app detected
- **Speaker Labeling:**
  - Call mode: "You" (mic) + "Them" (system audio) — unchanged
  - Solo memo: "You" only — single speaker stream
  - Solo room: "Room" only — signals to summary engine that multiple speakers may be present in one stream

### Claude's Discretion
- `MeetingMode` enum design (`.call`, `.soloMemo`, `.soloRoom` or similar)
- How TranscriptionEngine handles mic-only mode (skip system audio setup)
- Whether to add MeetingMode to session metadata for downstream use
- Exact button styling/positioning in menu bar

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SOLO-01 | User can start a mic-only recording session for in-person meetings via menu bar | `MeetingMode` enum + three-button UI in `MenuBarPopoverView`; `TranscriptionEngine.start()` skips `startSystemAudioStream` in solo mode |
| SOLO-02 | User can start a mic-only recording session for personal voice memos via menu bar | Same mode enum, same skip-system-audio path; only difference is speaker label |
| SOLO-03 | Solo mode produces a timestamped transcript identical in format to call transcripts | `TranscriptLogger`, `SessionStore`, `MarkdownMeetingWriter` are all speaker-label-agnostic — they encode `Speaker.rawValue` directly |
| SOLO-04 | Solo mode uses single-speaker labeling (no "them" speaker) | Add `Speaker.room` case; TranscriptionEngine only starts `micTask` in solo mode, never `sysTask` |
| CLEAN-01 | Knowledge base feature is removed from codebase | Delete 4 files; scrub 5 files of references |
| CLEAN-02 | KB-related UI elements are removed from settings and main views | `SettingsView` KB section and Embedding Provider section; `ContentView` suggestion section and indexing progress |
| CLEAN-03 | Voyage AI and Ollama embed client dependencies removed if only used by KB | `VoyageClient.swift` and `OllamaEmbedClient.swift` are only imported by `KnowledgeBase.swift` — safe to delete alongside it |
</phase_requirements>

---

## Summary

This phase has two workstreams: a subtraction task (KB removal) and an addition task (solo mode). Both are bounded and well-understood — the codebase inspection reveals exactly where every dependency lives.

**KB removal blast radius** is larger than "four files." `Models.swift` contains KB-specific types (`KBResult`, `Suggestion`, `SuggestionTrigger`, `SuggestionTriggerKind`, `SuggestionEvidence`, `SuggestionDecision`, `SuggestionFeedback`) that must also go. `SessionRecord` carries `suggestions`, `kbHits`, `suggestionDecision`, and `surfacedSuggestionText` fields. `ConversationState` carries `suggestedAnglesRecentlyShown` and `themGoals`. `AppSettings` has `EmbeddingProvider` enum plus four KB/embed properties. `AppRuntime.AppServices` struct carries `knowledgeBase` and `suggestionEngine`. `SuggestionsView.swift` is a full UI component that becomes dead code. The test file `KnowledgeBaseTests.swift` must be deleted.

**Solo mode addition** is smaller in scope. The core insight is that `TranscriptionEngine.start()` unconditionally calls `startSystemAudioStream()` — the solo path just needs to skip that call. Speaker routing is already label-driven; adding `Speaker.room` is a one-line enum extension. `MeetingMetadata` is the natural carrier for `MeetingMode` so the downstream summary engine (Phase 2) can read it. `AppCoordinator.startTranscription()` is the right place to pass mode context to `TranscriptionEngine`.

**Primary recommendation:** Remove KB from Models.swift and AppSettings.swift alongside the four Intelligence files. Add `MeetingMode` to `MeetingMetadata` from the start so Phase 2 summary routing is free.

---

## Standard Stack

No new dependencies are introduced in this phase. All work uses existing project frameworks.

| Framework | Version (Package.swift) | Purpose |
|-----------|------------------------|---------|
| FluidAudio | ≥ 0.7.9 | VAD + transcription backends (Parakeet, Qwen3) |
| WhisperKit | ≥ 0.9.0 | Whisper transcription backend |
| Sparkle | ≥ 2.7.0 | Auto-update — unchanged |
| LaunchAtLogin-Modern | ≥ 1.1.0 | Login item — unchanged |

Swift tools version: 6.2. Platform target: macOS 15.

**No new packages to install.** The embed clients (`VoyageClient`, `OllamaEmbedClient`) use only `Foundation` — no package entry to remove from `Package.swift`.

---

## Architecture Patterns

### Established Patterns in This Codebase

**Actor isolation for persistence:**
- `SessionStore` is an `actor` — all mutations go through `await`
- `TranscriptLogger` is an `actor`

**@Observable for UI-bound state:**
- `AppCoordinator`, `TranscriptionEngine`, `AppSettings`, `KnowledgeBase` all use `@Observable`
- Backing storage pattern: `@ObservationIgnored nonisolated(unsafe) private var _field` with manual `access`/`withMutation` to bypass MainActor executor checks in Swift 6.2

**State machine:** `MeetingState` is a pure value enum (`idle`/`recording`/`ending`). Transitions via `transition(from:on:)` free function. Side effects dispatched by `AppCoordinator.performSideEffects(for:settings:)` after transition.

**Scripted/live mode split:** `TranscriptionEngine.Mode` (`.live` / `.scripted([Utterance])`) and `AppRuntimeMode` (`.live` / `.uiTest`) — the UI test infrastructure uses scripted utterances and ephemeral storage.

### Plan 01-01: KB Removal

**Files to delete:**
```
OpenOats/Sources/OpenOats/Intelligence/KnowledgeBase.swift
OpenOats/Sources/OpenOats/Intelligence/SuggestionEngine.swift
OpenOats/Sources/OpenOats/Intelligence/VoyageClient.swift
OpenOats/Sources/OpenOats/Intelligence/OllamaEmbedClient.swift
OpenOats/Sources/OpenOats/Views/SuggestionsView.swift
OpenOats/Tests/OpenOatsTests/KnowledgeBaseTests.swift
```

**Files to scrub (surgical edits):**

| File | What to remove |
|------|----------------|
| `Models/Models.swift` | Entire `// MARK: - Suggestion Trigger` through `// MARK: - KB Result` blocks; the `Suggestion` struct; `kbHits`/`suggestions`/`suggestionDecision`/`surfacedSuggestionText` fields from `SessionRecord`; `suggestedAnglesRecentlyShown`/`themGoals` from `ConversationState` |
| `Settings/AppSettings.swift` | `EmbeddingProvider` enum; `kbFolderPath`, `voyageApiKey`, `embeddingProvider` properties and their `kbFolderURL` computed property; `ollamaEmbedModel`, `openAIEmbedBaseURL`, `openAIEmbedApiKey`, `openAIEmbedModel` properties (embed-only settings) |
| `App/AppRuntime.swift` | `knowledgeBase` and `suggestionEngine` from `AppServices` struct; `makeServices()` KB/SE construction; `ensureServicesInitialized()` passes through only the remaining services |
| `App/AppCoordinator.swift` | No KB state stored here — coordinator only receives services from AppRuntime |
| `Views/ContentView.swift` | `@State private var knowledgeBase`, `@State private var suggestionEngine` state vars; `kbIndexingProgress`/`suggestions`/`isGeneratingSuggestions`/`voyageApiKey`/`kbFolderPath` in `ViewState`; `observedKBFolderPath`/`observedVoyageApiKey` observation vars; entire `SUGGESTIONS` section in `rootContent`; `indexKBIfNeeded()` method; `suggestionEngine?.clear()` in `startSession()`; suggestion-related `appendRecordDelayed` call; KB/suggestion handling in `synchronizeDerivedState()`; suggestion parameter from `handlePendingExternalCommandIfPossible()` guard |
| `Storage/SessionStore.swift` | `suggestionEngine: SuggestionEngine?` parameter from `appendRecordDelayed`; `decision`/`latestSuggestion` capture inside that method |
| `Views/SettingsView.swift` | "Knowledge Base" `Section`; "Embedding Provider" `Section`; `chooseKBFolder()` method |

**Risk: `ConversationState` in `TranscriptStore`**
`TranscriptStore` holds a `ConversationState` and exposes `updateConversationState(_:)`. After removing `SuggestionEngine`, no caller updates this state. The `conversationState` property is still read by `AppCoordinator.finalizeCurrentSession()` (for the session title). The title extraction uses `transcriptStore.conversationState.currentTopic` — that field survives KB removal. Safe to keep `ConversationState` stripped to its non-suggestion fields (`currentTopic`, `shortSummary`, `openQuestions`, `activeTensions`, `recentDecisions`, `lastUpdatedAt`).

**Risk: `appendRecordDelayed` simplification**
Once `suggestionEngine` is removed, `appendRecordDelayed` no longer needs a 5-second delay for suggestion pipeline capture. It still needs the delay for `refinedText` from the refinement engine. Simplify the signature to remove `suggestionEngine:` but retain the delay and `transcriptStore:` parameter for refined text backfill.

### Plan 01-02: Solo Mode

**New enum: `MeetingMode`**

Add to `MeetingTypes.swift` alongside `DetectionSignal`:

```swift
// Source: codebase pattern — Sendable, Codable, Equatable enum
enum MeetingMode: String, Sendable, Codable, Equatable {
    case call       // mic + system audio, "You" + "Them" speakers
    case soloMemo   // mic only, "You" speaker
    case soloRoom   // mic only, "Room" speaker
}
```

**`Speaker` enum extension**

`Models.swift` line 3-6, add `.room` case:

```swift
enum Speaker: String, Codable, Sendable {
    case you
    case them
    case room
}
```

**`MeetingMetadata` — add `mode` field**

```swift
struct MeetingMetadata: Sendable, Equatable, Codable {
    let detectionContext: DetectionContext?
    let calendarEvent: CalendarEvent?
    let title: String?
    let startedAt: Date
    var endedAt: Date?
    var mode: MeetingMode   // NEW — defaults to .call for backward compat
}
```

Add a new static factory:
```swift
static func solo(_ mode: MeetingMode) -> MeetingMetadata {
    MeetingMetadata(
        detectionContext: nil, calendarEvent: nil,
        title: nil, startedAt: Date(), endedAt: nil,
        mode: mode
    )
}
```

Update `MeetingMetadata.manual()` to set `mode: .call`.

**`TranscriptionEngine` — mode-aware start**

`TranscriptionEngine.start()` currently unconditionally calls `startSystemAudioStream()` at step 3. The solo path skips this:

```swift
// Step 3: system audio — skip in solo modes
if mode == .call {
    await startSystemAudioStream(locale: locale, vadManager: vadManager)
}
```

`TranscriptionEngine` needs access to the `MeetingMode`. Two options:
1. Add a `meetingMode` parameter to `start()` — keeps the engine stateless between sessions.
2. Store mode in init — requires engine re-instantiation per session (not the current pattern).

**Recommended:** Pass `meetingMode` as a parameter to `start()`. The existing `start()` signature already takes `locale`, `inputDeviceID`, and `transcriptionModel` — adding `meetingMode` is consistent.

**Speaker labeling in `startMicStream`**

Currently hardcoded to `.you`. For solo room mode, the mic transcriber should use `.room`:

```swift
private func startMicStream(
    locale: Locale,
    vadManager: VadManager,
    deviceID: AudioDeviceID,
    echoCancellation: Bool = false,
    speaker: Speaker = .you  // NEW parameter
) {
    // ...
    store.append(Utterance(text: text, speaker: speaker))
}
```

**AEC comment update**

The comment in `start()` says "AEC disabled — conflicts with system audio capture." In solo mode, system audio is not active, so AEC _could_ be enabled. However, the user decision is clear: no system audio in solo mode. Leave AEC disabled for simplicity; add a code comment explaining solo mode doesn't need the restriction but keeps it for consistency.

**`AppCoordinator.startTranscription()`**

Extract `MeetingMode` from `metadata.mode` and pass to `transcriptionEngine?.start()`:

```swift
await transcriptionEngine?.start(
    locale: settings.locale,
    inputDeviceID: settings.inputDeviceID,
    transcriptionModel: settings.transcriptionModel,
    meetingMode: metadata.mode   // NEW
)
```

**`ContentView.swift` — three-button UI**

Replace the single `ControlBar` toggle trigger with three explicit action cases:

```swift
private enum ControlBarAction {
    case toggle          // existing stop path
    case startCall       // replaces generic startSession
    case startSoloMemo
    case startSoloRoom
    case confirmDownload
}
```

The `ControlBar` component may need a new layout. Per the decision: "Three explicit buttons: 'Start Call' / 'Solo (memo)' / 'Solo (room)'" — all direct actions, no dropdown. These buttons are only visible when not recording. When recording, the existing stop button remains.

**`ContentView.startSession()` — mode-aware**

```swift
private func startSession(mode: MeetingMode = .call) {
    guard settings.hasAcknowledgedRecordingConsent else {
        withAnimation(.easeInOut(duration: 0.25)) { showConsentSheet = true }
        return
    }
    let metadata: MeetingMetadata = mode == .call
        ? .manual()
        : .solo(mode)
    coordinator.handle(.userStarted(metadata), settings: settings)
}
```

**`TranscriptLogger.append(speaker:text:timestamp:)`**

Currently called with hardcoded strings: `last.speaker == .you ? "You" : "Them"`. Update to cover `.room`:

```swift
let label: String
switch last.speaker {
case .you: label = "You"
case .them: label = "Them"
case .room: label = "Room"
}
```

**`ContentView.copyTranscript()`**

Same pattern — add `.room` case to the ternary.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead |
|---------|-------------|-------------|
| System audio capture | Custom CoreAudio tap | Existing `SystemAudioCapture` — just skip it in solo mode |
| Mic capture for solo | New audio pipeline | Existing `MicCapture.bufferStream()` — already standalone |
| Transcript persistence | Custom file format | Existing `SessionStore` JSONL + `MarkdownMeetingWriter` — speaker-label-agnostic |
| Speaker routing | Conditional string injection | `Speaker` enum with `.room` case — same encoding path |
| State management | Ad-hoc flags | Extend existing `MeetingMetadata.mode` field and `MeetingState` machine |

**Key insight:** The KB removal and solo mode work entirely within existing architectural patterns. No new patterns, protocols, or abstractions are needed.

---

## Common Pitfalls

### Pitfall 1: Leaving orphaned KB types in Models.swift
**What goes wrong:** `KBResult`, `Suggestion`, and the suggestion-related fields of `SessionRecord` and `ConversationState` are in `Models.swift`, not in the Intelligence files. Deleting the four Intelligence files leaves these types behind, causing no compile error but accumulating dead code.
**How to avoid:** Treat Models.swift as part of the KB removal scope. Audit every type and field for KB-only usage.

### Pitfall 2: `appendRecordDelayed` signature breakage
**What goes wrong:** `SessionStore.appendRecordDelayed` takes `suggestionEngine: SuggestionEngine?`. After deletion, callers in `ContentView.swift` and the `SessionStore` actor itself break. Removing the parameter without updating all call sites causes a compile failure.
**How to avoid:** Remove the `suggestionEngine:` parameter from `appendRecordDelayed` in the same commit as removing KB from `ContentView`. Simplify the method body to drop the decision/suggestion capture.

### Pitfall 3: AEC comment becomes misleading
**What goes wrong:** The comment "AEC disabled — conflicts with system audio capture" is false in solo mode (no system audio). Future developers may re-enable AEC for solo mode based on the comment's logic, causing unexpected behavior.
**How to avoid:** Update the comment to acknowledge solo mode when adding the `meetingMode` parameter.

### Pitfall 4: `Speaker.room` not handled in string-formatting call sites
**What goes wrong:** `ContentView.copyTranscript()` and `TranscriptLogger.append()` use ternary/binary expressions on `Speaker`. Adding `.room` triggers no compiler warning if they use `== .you ? "You" : "Them"` — the room case silently falls through to "Them".
**How to avoid:** Convert both sites to exhaustive `switch` statements so the compiler enforces handling of the new case.

### Pitfall 5: `MeetingMetadata.manual()` ignores mode
**What goes wrong:** Existing detection path calls `.manual()` to build metadata. After adding `mode` field, `manual()` must explicitly set `.call` to preserve existing behavior. The auto-detect path in `AppCoordinator.handleDetectionAccepted()` also constructs `MeetingMetadata` directly — it needs `mode: .call`.
**How to avoid:** Search for all `MeetingMetadata(` construction sites and ensure each sets `mode`. The three sites are: `MeetingMetadata.manual()`, `AppCoordinator.handleDetectionAccepted()`, and test helpers in `MeetingStateTests.swift`.

### Pitfall 6: EmbeddingProvider enum removal leaves orphaned Keychain key
**What goes wrong:** `AppSettings` stores `voyageApiKey` in the Keychain under key `"voyageApiKey"`. Simply removing the property leaves stale Keychain entries on existing installs. The app won't crash, but it's untidy.
**How to avoid:** Add a migration in `AppSettings` that deletes the `voyageApiKey` Keychain entry on next launch. The migration infrastructure already exists (`runMigration3`, `runMigration4`, etc.).

---

## Code Examples

### Extending Speaker enum (verified from Models.swift)

```swift
// Source: OpenOats/Sources/OpenOats/Models/Models.swift lines 3-6
enum Speaker: String, Codable, Sendable {
    case you
    case them
    case room  // ADD: solo room mode
}
```

### MeetingMode enum (new, follows DetectionSignal pattern from MeetingTypes.swift)

```swift
// Source: pattern from OpenOats/Sources/OpenOats/Meeting/MeetingTypes.swift
enum MeetingMode: String, Sendable, Codable, Equatable {
    case call
    case soloMemo
    case soloRoom

    var micSpeaker: Speaker {
        switch self {
        case .call, .soloMemo: return .you
        case .soloRoom: return .room
        }
    }

    var capturesSystemAudio: Bool {
        self == .call
    }
}
```

### TranscriptionEngine start with mode parameter (surgical addition)

```swift
// Source: OpenOats/Sources/OpenOats/Transcription/TranscriptionEngine.swift
// Add meetingMode parameter to start():
func start(
    locale: Locale,
    inputDeviceID: AudioDeviceID = 0,
    transcriptionModel: TranscriptionModel,
    meetingMode: MeetingMode = .call   // ADD with default for backward compat
) async {
    // ... existing steps 1-2 unchanged ...

    // Step 3: system audio — skip in solo modes
    if meetingMode.capturesSystemAudio {
        await startSystemAudioStream(locale: locale, vadManager: vadManager)
    }
}
```

### MeetingMetadata with mode (surgical addition)

```swift
// Source: OpenOats/Sources/OpenOats/Meeting/MeetingTypes.swift
struct MeetingMetadata: Sendable, Equatable, Codable {
    // ... existing fields ...
    var mode: MeetingMode = .call  // ADD with default for Codable backward compat

    static func manual() -> MeetingMetadata {
        // existing body but add mode: .call explicitly
    }

    static func solo(_ mode: MeetingMode) -> MeetingMetadata {  // ADD
        MeetingMetadata(
            detectionContext: nil, calendarEvent: nil,
            title: nil, startedAt: Date(), endedAt: nil,
            mode: mode
        )
    }
}
```

### Exhaustive speaker label (prevents pitfall 4)

```swift
// Source: pattern needed in ContentView.swift and TranscriptLogger
private func speakerLabel(for speaker: Speaker) -> String {
    switch speaker {
    case .you: return "You"
    case .them: return "Them"
    case .room: return "Room"
    }
}
```

---

## State of the Art

| Old Approach | New Approach | Impact |
|--------------|--------------|--------|
| Single "Start" button → always starts call mode | Three explicit buttons for call / memo / room | Menu bar UI change; `ControlBarAction` enum gains new cases |
| `TranscriptionEngine.start()` always starts system audio | `meetingMode.capturesSystemAudio` gate | Solo sessions produce no "Them" utterances, no system audio permission prompt |
| KB enabled: `SuggestionEngine` feeds `appendRecordDelayed` | KB removed: `appendRecordDelayed` simplified, only writes utterance + refinedText | `SessionStore.appendRecordDelayed` loses `suggestionEngine:` parameter |

---

## Open Questions

1. **ConversationState fields after KB removal**
   - What we know: `SuggestionEngine` is the only updater of `conversationState` fields beyond `currentTopic`. `AppCoordinator.finalizeCurrentSession()` reads only `currentTopic`.
   - What's unclear: Does Phase 2 (summary engine) intend to repurpose `ConversationState` for summary pipeline state, or will it introduce new types?
   - Recommendation: Strip `ConversationState` to `{currentTopic, shortSummary, openQuestions, activeTensions, recentDecisions, lastUpdatedAt}` — remove `themGoals` and `suggestedAnglesRecentlyShown`. Leave the struct itself in place; Phase 2 can use or replace it.

2. **`Suggestion` struct in existing JSONL files**
   - What we know: Existing sessions on disk have `suggestions`/`kbHits`/`suggestionDecision` fields in their JSONL records. After removing these from `SessionRecord`, decoding old JSONL fails silently (fields ignored by `Codable`) or crashes on strict decoding.
   - What's unclear: Is the session decoder strict or lenient?
   - Recommendation: Verify `SessionStore.loadTranscript()` decoder strategy. If it uses default `JSONDecoder()` (lenient), old files decode fine — unknown fields are ignored. If strict, add a migration. Based on the code pattern (ISO8601 dates, no strict decoding flags), lenient decoding is the current behavior. HIGH confidence no migration needed, but verify during implementation.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (Swift Package Manager target `OpenOatsTests`) |
| Config file | `OpenOats/Package.swift` — testTarget at `Tests/OpenOatsTests` |
| Quick run command | `cd /Users/vcartier/Desktop/OpenOats-fork/OpenOats && swift test --filter MeetingStateTests` |
| Full suite command | `cd /Users/vcartier/Desktop/OpenOats-fork/OpenOats && swift test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| CLEAN-01 | KB files deleted, no KB symbols in build | unit (compile) | `swift build 2>&1 | grep -c error` = 0 | Build validation |
| CLEAN-02 | KB UI absent — no KBResult/Suggestion types visible | unit (compile) | Same build validation | Build validation |
| CLEAN-03 | VoyageClient/OllamaEmbedClient removed | unit (compile) | Same build validation | Build validation |
| SOLO-01 | Room mode produces mic-only session | unit | `swift test --filter MeetingStateTests/testSoloRoomSessionLifecycle` | ❌ Wave 0 |
| SOLO-02 | Memo mode produces mic-only session | unit | `swift test --filter MeetingStateTests/testSoloMemoSessionLifecycle` | ❌ Wave 0 |
| SOLO-03 | Solo transcript format matches call transcript format | unit | `swift test --filter SessionStoreTests` | ✅ (covers format) |
| SOLO-04 | Solo mode has no `.them` speaker utterances | unit | `swift test --filter MeetingStateTests/testSoloModeSpeakerLabels` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `cd /Users/vcartier/Desktop/OpenOats-fork/OpenOats && swift build`
- **Per wave merge:** `cd /Users/vcartier/Desktop/OpenOats-fork/OpenOats && swift test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `Tests/OpenOatsTests/MeetingStateTests.swift` — add `testSoloRoomSessionLifecycle`, `testSoloMemoSessionLifecycle`, `testSoloModeSpeakerLabels` test methods — covers SOLO-01, SOLO-02, SOLO-04
- [ ] `Tests/OpenOatsTests/MeetingStateTests.swift` — add `testMeetingModeEnum` and `testMeetingMetadataSoloFactory` tests for new enum/factory
- [ ] `Tests/OpenOatsTests/KnowledgeBaseTests.swift` — DELETE this file (becomes orphan after KB removal)

*(Existing `SessionStoreTests`, `TranscriptStoreTests`, `AppCoordinatorIntegrationTests` and `MeetingStateTests` cover the persistence and lifecycle surfaces. Only new solo-mode behavior needs new tests.)*

---

## Sources

### Primary (HIGH confidence — direct codebase inspection)

All findings verified from direct file reading. No external sources consulted.

- `OpenOats/Sources/OpenOats/Intelligence/KnowledgeBase.swift` — KB structure, embed client dependencies
- `OpenOats/Sources/OpenOats/Intelligence/SuggestionEngine.swift` — ConversationState mutation surface
- `OpenOats/Sources/OpenOats/Transcription/TranscriptionEngine.swift` — dual-stream start flow, AEC handling
- `OpenOats/Sources/OpenOats/App/AppCoordinator.swift` — session lifecycle, startTranscription call site
- `OpenOats/Sources/OpenOats/App/AppRuntime.swift` — AppServices struct, KB construction
- `OpenOats/Sources/OpenOats/Models/Models.swift` — Speaker enum, Utterance, SessionRecord, ConversationState
- `OpenOats/Sources/OpenOats/Meeting/MeetingTypes.swift` — MeetingMetadata, DetectionSignal patterns
- `OpenOats/Sources/OpenOats/Meeting/MeetingState.swift` — state machine structure
- `OpenOats/Sources/OpenOats/Settings/AppSettings.swift` — EmbeddingProvider, kbFolderPath, voyageApiKey
- `OpenOats/Sources/OpenOats/Storage/SessionStore.swift` — appendRecordDelayed signature
- `OpenOats/Sources/OpenOats/Views/ContentView.swift` — KB state vars, suggestion display, copyTranscript
- `OpenOats/Sources/OpenOats/Views/SettingsView.swift` — KB and Embedding sections
- `OpenOats/Tests/OpenOatsTests/MeetingStateTests.swift` — existing test patterns and coverage
- `OpenOats/Package.swift` — target structure, test target path

---

## Metadata

**Confidence breakdown:**
- KB removal scope: HIGH — every reference located via direct file inspection
- Solo mode architecture: HIGH — integration points identified from TranscriptionEngine source
- Test infrastructure: HIGH — Package.swift and test files read directly

**Research date:** 2026-03-21
**Valid until:** 2026-06-21 (stable Swift/macOS platform — 90-day window)
