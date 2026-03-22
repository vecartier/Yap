# Phase 5: Summary Engine + Settings - Research

**Researched:** 2026-03-22
**Domain:** Swift actor-based LLM integration, two-phase prompt engineering, Markdown file persistence, NavigationSplitView settings routing
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **Spinner then reveal** — "Generating summary..." spinner in the summary card area, then full summary appears at once when complete
- **No streaming** — don't show word-by-word, wait for complete result
- **One-shot** — summary generates once on session end, no regenerate button
- **Error handling:** Error message in summary card + "Retry" button if LLM call fails. Transcript still visible below.
- **Casual brief** tone — natural, like quick notes to yourself. "We went with option B" not "The team decided to proceed with option B"
- **Proportional length** — short meetings get short summaries, long meetings get longer ones. LLM decides based on transcript length.
- **Four sections:** Key Decisions, Action Items, Discussion Points, Open Questions (already defined in MeetingSummary struct)
- **Action item attribution:** Include owner names where identifiable from transcript context (e.g., "Vincent to follow up on X")
- **Two-Phase LLM Prompt:** Phase 1 (Grounding) extracts cited evidence; Phase 2 (Formatting) structures grounded evidence into four sections
- Saved as Markdown file alongside transcript in ~/Documents/OpenOats/
- Filename: `{session-id}-summary.md`
- Loaded by PastMeetingDetailView when displaying a past session
- Must work with OpenRouter (cloud) — structured JSON output via `response_format: json_schema`
- Must work with Ollama (local) — use Ollama's native `format` field (OpenAI-compat `response_format` is unreliable)
- Fallback: if structured output fails, extract sections from markdown response
- Summary generation triggers from `AppCoordinator.finalizeCurrentSession()` AFTER `awaitPendingWrites()`
- Not triggered from UI layer; runs as a Task — doesn't block finalization
- **Gear icon pinned at sidebar bottom** — click shows settings in detail pane (like Granola)
- **Settings include:** LLM provider + model selection, API keys (Keychain), transcription model selection
- **Audio input:** Use system default, no explicit selector
- Reuse existing SettingsView content, embed in the sidebar detail pane when gear is selected
- Cmd+, keyboard shortcut should also open settings (existing macOS convention)

### Claude's Discretion
- SummaryEngine actor internal structure
- Exact LLM prompt wording (following the two-phase pattern and casual tone)
- Spinner/loading indicator design
- Error card design
- How settings gear icon integrates with NavigationSplitView selection model
- Summary markdown file format details
- Retry logic for failed LLM calls (simple single retry or immediate)

### Deferred Ideas (OUT OF SCOPE)
- Templates system (custom summary/Slack prompts per meeting type) — v2
- Editable summary before sending to Slack — v2
- Regenerate button for summaries — user chose one-shot for v1
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SUMM-01 | Structured summary is auto-generated when a session ends | SummaryEngine actor called from finalizeCurrentSession() after awaitPendingWrites(); existing AppCoordinator hook point identified |
| SUMM-02 | Summary includes key decisions extracted from transcript | Two-phase prompt grounding pass; SlackFormatter.Summary.decisions array already defined |
| SUMM-03 | Summary includes action items with owner attribution | Two-phase prompt; attribution instruction in formatting pass prompt |
| SUMM-04 | Summary includes main discussion points | SlackFormatter.Summary.discussionPoints already defined |
| SUMM-05 | Summary includes open questions / unresolved items | SlackFormatter.Summary.openQuestions already defined |
| SUMM-06 | Summary uses two-phase LLM prompt (grounding then formatting) | OpenRouterClient.complete() supports two sequential non-streaming calls; pattern matches NotesEngine |
| SUMM-07 | Summary hooks into AppCoordinator after awaitPendingWrites() | finalizeCurrentSession() structure analyzed; hook point is after step 2 (awaitPendingWrites) |
| SUMM-08 | Summary works with both OpenRouter and Ollama providers | NotesEngine.generate() shows the exact provider-switch pattern; same pattern applies to SummaryEngine |
| SUMM-09 | Summary is saved as Markdown alongside transcript in ~/Documents/OpenOats/ | MarkdownMeetingWriter.insertLLMSections() already handles inserting LLM sections into existing .md files; SummaryEngine should use this |
| SETT-01 | Settings accessible as tab/section in main window sidebar | MeetingSidebarView selection model uses String?; "_settings_" sentinel string follows same pattern as "_live_"; DetailRouter needs settings case |
| SETT-02 | Settings include LLM provider, transcription model, API keys, audio input | SettingsView already has all these; just needs embedding in detail pane |
</phase_requirements>

---

## Summary

Phase 5 builds on a well-understood codebase. The architecture, storage patterns, and LLM client are all established. The primary new component is `SummaryEngine`, an actor that accepts a `[SessionRecord]` array and `AppSettings`, calls the LLM twice (grounding pass then formatting pass), and produces a `SlackFormatter.Summary` value. This then gets written to the existing `.md` file via `MarkdownMeetingWriter.insertLLMSections()` and saved separately as `{session-id}-summary.md`.

The settings integration is straightforward: `MeetingSidebarView` already uses `String?` selection binding with a `"_live_"` sentinel; adding `"_settings_"` follows the identical pattern. `DetailRouter` gains one more case. `SettingsView` already exists and renders correctly — it just needs to be embedded in the detail pane and lose its fixed `.frame(width: 450, height: 750)` constraint.

The main complexity is prompt engineering for the two-phase approach and ensuring Ollama's `format` field is used instead of `response_format` for structured JSON. The existing `OpenRouterClient.complete()` method sends non-streaming requests but does not support `response_format` or `format` fields yet — the `ChatRequest` struct will need to be extended.

**Primary recommendation:** Create `SummaryEngine` as an actor following the NotesEngine pattern, extend `ChatRequest` to optionally carry `format`/`response_format`, then wire the gear icon into MeetingSidebarView as a `"_settings_"` sentinel selection.

---

## Standard Stack

### Core (all already in the project — no new dependencies)

| Component | Type | Purpose | Status |
|-----------|------|---------|--------|
| `OpenRouterClient` | actor | Non-streaming LLM calls for both phases | Exists; needs `ChatRequest` extension |
| `SlackFormatter.Summary` | struct | Output type for SummaryEngine | Exists in `SlackFormatter.swift` |
| `MarkdownMeetingWriter.insertLLMSections()` | static func | Persists LLM summary sections into .md file | Exists; ready to use |
| `NotesEngine` | `@Observable @MainActor` class | Reference pattern for LLM-based generation | Exists; read for pattern |
| `AppCoordinator.finalizeCurrentSession()` | async func | Hook point for triggering summary | Exists; add call after step 2 |
| `SettingsView` | SwiftUI View | Complete settings UI | Exists; remove fixed frame for embedding |

### No New Dependencies

This phase requires zero new Swift packages. All primitives exist.

---

## Architecture Patterns

### Recommended Project Structure (additions only)

```
Sources/OpenOats/
├── Intelligence/
│   └── SummaryEngine.swift          # NEW: two-phase summary actor
├── Views/
│   ├── PastMeetingDetailView.swift  # MODIFIED: replace placeholder, enable Slack button
│   ├── MeetingSidebarView.swift     # MODIFIED: add gear icon + "_settings_" sentinel
│   ├── DetailRouter.swift           # MODIFIED: add .settings case
│   └── MainAppView.swift            # MODIFIED: Cmd+, shortcut → selectedSessionID = "_settings_"
└── [all other files unchanged]
```

### Pattern 1: SummaryEngine Actor (mirrors NotesEngine)

**What:** A Swift actor that owns two sequential LLM calls. Because it's an actor (not `@Observable @MainActor`), it runs off the main thread without blocking UI. State is published back to the view via `@Observable` on `AppCoordinator`, or by passing the result back via callback/return value.

**Key difference from NotesEngine:** SummaryEngine is an `actor`, not `@Observable @MainActor`. It returns a value rather than mutating observable state directly. The caller (AppCoordinator) holds the result and the view reads it from the coordinator.

**Recommended structure:**

```swift
// Sources/OpenOats/Intelligence/SummaryEngine.swift
actor SummaryEngine {
    private let client = OpenRouterClient()

    /// Generate a structured summary from a transcript.
    /// Returns nil if generation fails — caller decides error handling.
    func generate(
        sessionID: String,
        records: [SessionRecord],
        settings: AppSettings
    ) async throws -> SlackFormatter.Summary {
        let (apiKey, baseURL, model) = resolveProvider(settings)

        // Phase 1: Grounding pass — extract evidence citations
        let groundingMessages = buildGroundingMessages(records: records)
        let groundedEvidence = try await client.complete(
            apiKey: apiKey,
            model: model,
            messages: groundingMessages,
            maxTokens: 2048,
            baseURL: baseURL
        )

        // Phase 2: Formatting pass — structure into four sections as JSON
        let formattingMessages = buildFormattingMessages(evidence: groundedEvidence)
        let jsonString = try await client.completeStructured(
            apiKey: apiKey,
            model: model,
            messages: formattingMessages,
            schema: SummarySchema.jsonSchema,
            provider: settings.llmProvider,
            maxTokens: 1024,
            baseURL: baseURL
        )

        return try parseSummaryJSON(jsonString, sessionID: sessionID, records: records)
    }
}
```

**Why actor, not @Observable @MainActor:** NotesEngine is `@Observable @MainActor` because it streams results to a view in real time. SummaryEngine runs after session end, returns a complete result, and must not block the main thread during two sequential LLM calls. Actor isolation is the correct choice.

### Pattern 2: OpenRouterClient Extension for Structured Output

**What:** Add a `completeStructured()` method to `OpenRouterClient` that handles the provider difference:
- OpenRouter: adds `response_format: {"type": "json_schema", "json_schema": {...}}` to the request body
- Ollama: adds `format: {...}` to the request body (the Ollama-native field)
- Other providers: falls back to plain `complete()` with instructions to output JSON in system prompt

**Why this is needed:** The existing `ChatRequest` struct has no format field. Adding one optional field with a `Codable` representation is cleaner than duplicating the entire request path.

```swift
// Extension on OpenRouterClient (or new method)
func completeStructured(
    apiKey: String? = nil,
    model: String,
    messages: [Message],
    schema: [String: Any],    // JSON Schema dict
    provider: LLMProvider,
    maxTokens: Int = 1024,
    baseURL: URL? = nil
) async throws -> String {
    // For Ollama: use `format` field
    // For OpenRouter: use `response_format.json_schema` field
    // For others: plain complete() with JSON instructions in system prompt
}
```

**Confidence:** MEDIUM — Ollama's `format` field behavior has been flagged as requiring verification against current Ollama release (STATE.md note). The fallback (plain completion + markdown extraction) must be robust.

### Pattern 3: Summary State on AppCoordinator

**What:** AppCoordinator holds the summary state per session, observed by PastMeetingDetailView.

**Two valid approaches:**

Option A — In-memory cache on coordinator:
```swift
// AppCoordinator additions
@ObservationIgnored nonisolated(unsafe) private var _summaryCache: [String: SummaryState] = [:]
var summaryCache: [String: SummaryState] { ... }  // @Observable property

enum SummaryState {
    case loading
    case ready(SlackFormatter.Summary)
    case failed(Error)
}
```

Option B — Load from disk only:
PastMeetingDetailView reads the `{session-id}-summary.md` file in its `.task(id: sessionID)` block, same as it loads the transcript. No coordinator state needed. Simpler.

**Recommendation (Claude's Discretion):** Option B for past sessions. Option A for the just-completed session (where the summary is actively generating). The coordinator sets `summaryCache[sessionID] = .loading` before the Task starts, then `.ready(summary)` when done. PastMeetingDetailView checks the cache first, then falls back to disk load.

### Pattern 4: Settings Gear Icon in Sidebar

**What:** Follow the `"_live_"` sentinel pattern exactly. The gear icon is a separate row pinned at the bottom of `MeetingSidebarView`. Selecting it sets `selectedSessionID = "_settings_"`. `DetailRouter` routes this to `SettingsView`.

**Implementation sketch:**

```swift
// MeetingSidebarView additions
var body: some View {
    VStack(spacing: 0) {
        List(selection: $selectedSessionID) {
            // existing live row + session rows
        }
        .listStyle(.sidebar)

        Divider()

        // Gear icon — pinned at bottom, outside the List
        Button {
            selectedSessionID = "_settings_"
        } label: {
            Label("Settings", systemImage: "gear")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .background(selectedSessionID == "_settings_" ? Color.accentColor.opacity(0.1) : Color.clear)
        .accessibilityIdentifier("sidebar.settingsButton")
    }
}
```

**Why outside the List:** macOS List selection binding (`List(selection: $selectedSessionID)`) only tracks items inside the List. Placing the gear button outside with a manual `selectedSessionID = "_settings_"` assignment is cleaner — it avoids adding a non-session item to the data model and matches common macOS app patterns (Sidebar button rows outside the scrollable list).

**DetailRouter addition:**
```swift
private var resolvedContent: Content {
    if selectedSessionID == "_settings_" { return .settings }
    if selectedSessionID == "_live_" { return .live }
    if let id = selectedSessionID { return .past(id) }
    return .empty
}
```

**Cmd+, shortcut** — add to MainAppView:
```swift
.commands {
    CommandGroup(replacing: .appSettings) {
        Button("Settings") { selectedSessionID = "_settings_" }
            .keyboardShortcut(",", modifiers: .command)
    }
}
```
Note: `MainAppView` owns `selectedSessionID` — but `commands` modifier can't directly mutate `@AppStorage`. The cleanest approach is to use `AppCoordinator.queueSessionSelection("_settings_")` pattern that already exists, or add a `@AppStorage` property to a commands-accessible location. Claude's discretion.

### Pattern 5: SettingsView Embedding

**What:** `SettingsView` has `.frame(width: 450, height: 750)` which was sized for a standalone window. Remove this fixed frame and let it fill the detail pane with a `ScrollView` wrapper.

**What SettingsView currently requires:**
- `@Bindable var settings: AppSettings` — already passed in DetailRouter
- `var updater: SPUUpdater` — must be threaded from AppCoordinator/AppRuntime to SettingsView

**The `SPUUpdater` dependency:** SettingsView takes an `SPUUpdater` for the auto-updates toggle. This is currently injected from the `Settings {}` scene in `OpenOatsApp.swift`. When settings moves into the detail pane, the updater must be accessible. Check how `AppRuntime` or `AppDelegate` holds the updater — pass it through DetailRouter the same way `settings` is passed.

### Pattern 6: Two-Phase Prompt Design

**Grounding Pass (Phase 1) system prompt:**
```
You are a transcript analyst. Extract direct evidence from the meeting transcript.
Do not summarize yet. For each of these four categories, copy relevant quotes
and note the speaker:
- Decisions made
- Action items (with owner if named)
- Topics discussed
- Questions raised but not resolved

Output plain text. Be terse. Include only what was explicitly said.
```

**Formatting Pass (Phase 2) system prompt:**
```
You are a meeting notes assistant. Given evidence extracted from a transcript,
produce a casual JSON summary. Write like a colleague's quick notes — "We decided X",
"Vincent to follow up on Y". Keep it brief and proportional to the amount of evidence.

Output JSON matching this schema exactly:
{"decisions": [...], "actionItems": [...], "discussionPoints": [...], "openQuestions": [...]}

Each array contains strings. If a category has no evidence, return an empty array.
```

**Why two phases:** Single-phase prompts hallucinate ~14% false-positive action items because the model invents plausible-sounding items from context. The grounding pass anchors the model to explicit transcript evidence before structuring.

### Pattern 7: Summary Markdown Persistence

**Existing infrastructure:** `MarkdownMeetingWriter.insertLLMSections()` already handles inserting LLM-generated sections into the existing `.md` file. SummaryEngine should use this.

**The `{session-id}-summary.md` file (for PastMeetingDetailView to load):**

The CONTEXT.md specifies saving a separate `{session-id}-summary.md` alongside the transcript. This is in addition to inserting sections into the main `.md` file. The separate file makes loading in PastMeetingDetailView simple — no need to parse the main markdown file.

**Format for `{session-id}-summary.md`:**
```json
// Internal format: plain JSON (easier for loading than parsing Markdown)
// OR: Codable struct written as JSON to disk
{
  "decisions": ["..."],
  "actionItems": ["..."],
  "discussionPoints": ["..."],
  "openQuestions": ["..."],
  "generatedAt": "ISO8601"
}
```

**Loading pattern in PastMeetingDetailView:**
```swift
.task(id: sessionID) {
    // existing: load transcript rows
    // NEW: load summary from disk
    let summaryURL = URL(fileURLWithPath: settings.notesFolderPath)
        .appendingPathComponent("\(sessionID)-summary.json")
    if let data = try? Data(contentsOf: summaryURL),
       let summary = try? JSONDecoder().decode(PersistedSummary.self, from: data) {
        self.summary = .ready(summary.toSlackSummary(sessionID: sessionID, sessionHistory: coordinator.sessionHistory))
    }
}
```

**Note:** Filename convention. The session ID format is `session_2026-03-22_14-30-00` (from `SessionStore.startSession()`). So the summary file is `session_2026-03-22_14-30-00-summary.json`. This is deterministic and collision-free.

### Anti-Patterns to Avoid

- **Making SummaryEngine @Observable @MainActor:** Causes two sequential LLM calls to run on the main thread, blocking UI. Use `actor`.
- **Triggering summary from PastMeetingDetailView's .task:** The CONTEXT.md explicitly requires the hook to be in AppCoordinator, not the UI. This ensures summary runs even if the user closes the window.
- **Passing `response_format` to Ollama:** Ollama ignores the OpenAI-style `response_format` field. Must use Ollama's native `format` field. See pitfall below.
- **Placing gear button inside the List:** macOS `List(selection:)` only tracks `Identifiable` items that are actually in the list's data. A non-data button inside the List causes selection binding inconsistencies.
- **Regenerate button:** Explicitly out of scope (one-shot per CONTEXT.md).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| LLM HTTP requests | Custom URLSession request builder | `OpenRouterClient.complete()` | Already handles auth, error codes, provider routing |
| Markdown file writing | Custom file writer | `MarkdownMeetingWriter.insertLLMSections()` | Already handles frontmatter parsing, section insertion, file renaming |
| Slack formatting | Custom formatter | `SlackFormatter.format()` | Already tested (12 tests), handles empty sections, Markdown escaping |
| Session history lookup | Custom file scan | `coordinator.sessionHistory` | Already loaded and observable |
| API key storage | Plain UserDefaults | `KeychainHelper.save/load` | Already used by all providers; Keychain is the correct macOS approach |
| Provider-selection branching | Ad-hoc switch | Copy `NotesEngine.generate()` provider-switch block | Handles all 4 providers (openRouter, ollama, mlx, openAICompatible) |

---

## Common Pitfalls

### Pitfall 1: Ollama Structured Output — `response_format` vs `format`

**What goes wrong:** Using `response_format: {"type": "json_schema", ...}` with Ollama silently fails — Ollama ignores the field and returns plain markdown. The summary JSON parser then fails and triggers the error path.

**Why it happens:** Ollama implements a subset of the OpenAI API. The `response_format` field is in the OpenAI spec but Ollama uses its own `format` field instead.

**How to avoid:** In `OpenRouterClient.ChatRequest`, add an optional `format` field (used for Ollama) and an optional `response_format` field (used for OpenRouter). The `completeStructured()` method sets the correct one based on the provider enum.

**Warning signs:** Summary always falls back to markdown extraction when using Ollama. Error logs show JSON parse failures. The plain `complete()` call returns readable text but not JSON.

**Confidence:** MEDIUM — flagged in STATE.md as requiring verification against current Ollama release. The fallback markdown extraction must be robust.

### Pitfall 2: `AppCoordinator.finalizeCurrentSession()` — Settings Not Available

**What goes wrong:** `finalizeCurrentSession()` is a `private` func that takes `settings: AppSettings?`. When SummaryEngine is called from within `finalizeCurrentSession`, settings is available. But the summary generation should run as a `Task` (non-blocking), and the Task captures `settings`.

**Current code at hook point:**
```swift
// Step 2: Drain delayed JSONL writes
await sessionStore.awaitPendingWrites()

// ADD HERE: Step 2c — Trigger summary generation (non-blocking)
if let settings {
    Task {
        await generateSummary(sessionID: sessionID, settings: settings)
    }
}
```

**Why `sessionID` must be captured before the Task:** `sessionID` is computed earlier in `finalizeCurrentSession`. Capture it explicitly in the Task closure.

**How to avoid:** The Task captures `settings` and `sessionID` by value. `SummaryEngine` is an actor stored on `AppCoordinator`. Call `await summaryEngine.generate(...)` inside the Task.

### Pitfall 3: Transcript Truncation for Long Meetings

**What goes wrong:** `NotesEngine.formatTranscript()` truncates at 60,000 characters by dropping the middle third of utterances. For long meetings this discards important context mid-meeting.

**Why it happens:** LLM context windows have limits. The truncation is intentional but the drop-middle strategy loses context.

**How to avoid for SummaryEngine:** Use the same 60k character limit and drop-middle strategy (already validated in NotesEngine). The grounding pass only needs evidence — it doesn't need the full transcript. For the grounding pass, consider a smarter strategy: keep first 1/3 and last 1/3, which captures opening context and closing decisions. This is Claude's Discretion.

**Warning signs:** Very long meetings (90+ min) produce summaries missing decisions made in the middle of the meeting.

### Pitfall 4: SettingsView `SPUUpdater` Dependency

**What goes wrong:** `SettingsView` requires a `SPUUpdater` instance. When embedded in the detail pane, the updater must be threaded from AppRuntime/AppDelegate down through DetailRouter.

**Current injection path:** `SettingsView(settings: settings, updater: updater)` — the updater comes from the Sparkle framework, initialized in AppDelegate or AppRuntime.

**How to avoid:** Check where `AppRuntime` or `AppDelegate` holds the `SPUUpdater`. Pass it through `DetailRouter` alongside `settings`. Do not create a new `SPUUpdater` instance — only one should exist per app lifetime.

**Warning signs:** SettingsView "Updates" section toggle is broken or crashes. `SPUUpdater` initializer called multiple times.

### Pitfall 5: Summary Card State Race — Loading vs. Just-Generated

**What goes wrong:** When a session ends, `finalizeCurrentSession()` fires the summary generation Task. Meanwhile `PastMeetingDetailView` loads for the just-ended session. The view's `.task(id: sessionID)` checks disk for the summary file — but the file doesn't exist yet (generation is in-flight).

**How to avoid:** The summary state on `AppCoordinator` (Option A from Pattern 3) solves this. The view checks the coordinator's `summaryCache[sessionID]`:
- `.loading` → show spinner
- `.ready(summary)` → show content
- `.failed(error)` → show error + Retry
- `nil` → try to load from disk (for old sessions)

For old sessions (no cache entry), PastMeetingDetailView loads the summary JSON file from disk in the `.task` block.

---

## Code Examples

### SummaryEngine Integration Hook in AppCoordinator

```swift
// In AppCoordinator.finalizeCurrentSession() — after awaitPendingWrites()

// 2b. Backfill refined text ... (existing)

// 2c. Trigger summary generation (non-blocking Task)
let capturedSessionID = sessionID  // local copy
if let settings {
    summaryCache[capturedSessionID] = .loading  // visible to PastMeetingDetailView immediately
    Task {
        do {
            let summary = try await summaryEngine.generate(
                sessionID: capturedSessionID,
                records: utterancesSnapshot,  // already captured above
                settings: settings
            )
            summaryCache[capturedSessionID] = .ready(summary)
            // Persist to disk
            persistSummary(summary, sessionID: capturedSessionID, settings: settings)
        } catch {
            summaryCache[capturedSessionID] = .failed(error)
        }
    }
}
```

### Provider Switch in SummaryEngine (from NotesEngine pattern)

```swift
// SummaryEngine.resolveProvider(_:) — exact copy of NotesEngine provider switch
private func resolveProvider(_ settings: AppSettings) -> (apiKey: String?, baseURL: URL?, model: String) {
    switch settings.llmProvider {
    case .openRouter:
        return (
            settings.openRouterApiKey.isEmpty ? nil : settings.openRouterApiKey,
            nil,
            settings.selectedModel
        )
    case .ollama:
        let base = settings.ollamaBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return (nil, URL(string: base + "/v1/chat/completions"), settings.ollamaLLMModel)
    case .mlx:
        let base = settings.mlxBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return (nil, URL(string: base + "/v1/chat/completions"), settings.mlxModel)
    case .openAICompatible:
        return (
            settings.openAILLMApiKey.isEmpty ? nil : settings.openAILLMApiKey,
            URL(string: settings.openAILLMBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/v1/chat/completions"),
            settings.openAILLMModel
        )
    }
}
```

### Transcript Formatting (reuse NotesEngine.formatTranscript pattern)

```swift
// SummaryEngine — same 60k char limit as NotesEngine
private func formatTranscriptForGrounding(_ records: [SessionRecord]) -> String {
    let timeFmt = DateFormatter()
    timeFmt.dateFormat = "HH:mm:ss"
    var lines: [String] = []
    var totalChars = 0
    let maxChars = 60_000
    for record in records {
        let label = record.speaker == .you ? "You" : "Them"
        let text = record.refinedText ?? record.text
        let line = "[\(timeFmt.string(from: record.timestamp))] \(label): \(text)"
        totalChars += line.count
        lines.append(line)
    }
    if totalChars > maxChars {
        let keepLines = lines.count / 3
        let head = Array(lines.prefix(keepLines))
        let tail = Array(lines.suffix(keepLines))
        let omitted = lines.count - (keepLines * 2)
        return (head + ["[... \(omitted) utterances omitted ...]"] + tail).joined(separator: "\n")
    }
    return lines.joined(separator: "\n")
}
```

### JSON Fallback Extraction (when structured output fails)

```swift
// SummaryEngine — parse LLM output that may be JSON or markdown
private func parseSummaryOutput(_ raw: String, sessionTitle: String, date: Date) throws -> SlackFormatter.Summary {
    // Try JSON first
    if let data = raw.data(using: .utf8),
       let json = try? JSONDecoder().decode(SummaryJSON.self, from: data) {
        return json.toSummary(title: sessionTitle, date: date)
    }

    // Try to find JSON object embedded in markdown code block
    if let jsonRange = raw.range(of: #"\{[^{}]*"decisions"[^{}]*\}"#, options: .regularExpression),
       let data = String(raw[jsonRange]).data(using: .utf8),
       let json = try? JSONDecoder().decode(SummaryJSON.self, from: data) {
        return json.toSummary(title: sessionTitle, date: date)
    }

    // Fallback: return empty summary (error will be surfaced separately)
    throw SummaryEngine.GenerationError.unparsableResponse
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Single-phase LLM for meeting summaries | Two-phase (grounding + formatting) | Phase 1 research finding | ~14% reduction in false-positive action items |
| `response_format` for all providers | Provider-specific structured output fields | Ollama API diverged from OpenAI spec | Must branch on provider |
| Settings in separate macOS `Settings {}` window | Settings embedded in main window detail pane | Phase 2 design decision | Simpler window management; macOS Settings scene removed |

---

## Open Questions

1. **Ollama `format` field — current Ollama version compatibility**
   - What we know: STATE.md flags this as MEDIUM confidence requiring verification. Ollama added JSON mode via `format` field but the exact schema syntax varies by version.
   - What's unclear: Whether current Ollama release (as of 2026-03) accepts a full JSON Schema object in `format`, or only `"json"` as a string value.
   - Recommendation: Implement two fallback levels: (1) `format: {"type": "object", "properties": {...}}` (full schema), (2) `format: "json"` (forces JSON output but no schema validation), (3) plain `complete()` with JSON instructions in system prompt. Try in order.

2. **SPUUpdater injection path**
   - What we know: `SettingsView` takes `var updater: SPUUpdater`. The updater is currently created somewhere in AppDelegate/AppRuntime.
   - What's unclear: Whether AppRuntime exposes the updater as a property, or if it's only held by AppDelegate.
   - Recommendation: Read `AppRuntime.swift` during planning to confirm the injection path. Pass `updater` through `DetailRouter` → `SettingsView` alongside `settings`.

3. **`selectedSessionID` and `@AppStorage` + Cmd+, shortcut**
   - What we know: `selectedSessionID` is stored as `@AppStorage("selectedMeetingID")` in `MainAppView`. SwiftUI `.commands` modifier runs in a context where `@AppStorage` is accessible if declared at the right scope.
   - What's unclear: The cleanest way to set `selectedSessionID = "_settings_"` from a `.commands` block.
   - Recommendation: Use `coordinator.queueSessionSelection("_settings_")` and have `MainAppView.onChange(of: coordinator.requestedSessionSelectionID)` set `selectedSessionID`. This is the same pattern already used for deep links.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (via Swift Package Manager) |
| Config file | `OpenOats/Package.swift` — `testTarget("OpenOatsTests", ...)` |
| Quick run command | `cd /Users/vcartier/Desktop/OpenOats-fork/OpenOats && swift test --filter OpenOatsTests 2>&1 | tail -20` |
| Full suite command | `cd /Users/vcartier/Desktop/OpenOats-fork/OpenOats && swift test 2>&1 | tail -40` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SUMM-01 | Summary generates on session end | unit | `swift test --filter SummaryEngineTests` | ❌ Wave 0 |
| SUMM-02 | Decisions extracted from transcript | unit | `swift test --filter SummaryEngineTests/testDecisionsExtracted` | ❌ Wave 0 |
| SUMM-03 | Action items with attribution | unit | `swift test --filter SummaryEngineTests/testActionItemAttribution` | ❌ Wave 0 |
| SUMM-04 | Discussion points section | unit | `swift test --filter SummaryEngineTests/testDiscussionPoints` | ❌ Wave 0 |
| SUMM-05 | Open questions section | unit | `swift test --filter SummaryEngineTests/testOpenQuestions` | ❌ Wave 0 |
| SUMM-06 | Two-phase prompt (grounding + formatting) | unit | `swift test --filter SummaryEngineTests/testTwoPhasePromptMessages` | ❌ Wave 0 |
| SUMM-07 | Hook point after awaitPendingWrites | integration | `swift test --filter AppCoordinatorIntegrationTests/testSummaryGeneratedAfterFinalize` | ❌ Wave 0 |
| SUMM-08 | Works with OpenRouter + Ollama | unit | `swift test --filter SummaryEngineTests/testProviderRouting` | ❌ Wave 0 |
| SUMM-09 | Summary saved as Markdown on disk | unit | `swift test --filter SummaryEngineTests/testSummaryPersistedToDisk` | ❌ Wave 0 |
| SETT-01 | Settings accessible via gear icon | manual-only | N/A — NavigationSplitView selection in UI | — |
| SETT-02 | Settings fields are correct | manual-only | N/A — UI layout verification | — |

### Sampling Rate

- **Per task commit:** `swift test --filter SummaryEngineTests 2>&1 | tail -10`
- **Per wave merge:** `swift test --filter OpenOatsTests 2>&1 | tail -20`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `Tests/OpenOatsTests/SummaryEngineTests.swift` — covers SUMM-01 through SUMM-09
- [ ] SummaryEngine needs a `.scripted(summary:)` mode (like `NotesEngine.Mode.scripted`) for testability without real LLM calls

*(Existing `AppCoordinatorIntegrationTests.swift` can be extended for SUMM-07 by adding a test that verifies summary generation is triggered on session end.)*

---

## Sources

### Primary (HIGH confidence — direct code inspection)

- `/Users/vcartier/Desktop/OpenOats-fork/OpenOats/Sources/OpenOats/Intelligence/OpenRouterClient.swift` — `complete()` method, `ChatRequest` struct, `OpenRouterError` enum
- `/Users/vcartier/Desktop/OpenOats-fork/OpenOats/Sources/OpenOats/Intelligence/NotesEngine.swift` — actor/observable pattern, provider switch, transcript formatting, 60k char limit
- `/Users/vcartier/Desktop/OpenOats-fork/OpenOats/Sources/OpenOats/Intelligence/SlackFormatter.swift` — `SlackFormatter.Summary` struct definition, `format()` method
- `/Users/vcartier/Desktop/OpenOats-fork/OpenOats/Sources/OpenOats/Intelligence/MarkdownMeetingWriter.swift` — `insertLLMSections()`, `findMarkdownFile()`, file persistence patterns
- `/Users/vcartier/Desktop/OpenOats-fork/OpenOats/Sources/OpenOats/App/AppCoordinator.swift` — `finalizeCurrentSession()` step-by-step structure, hook point after `awaitPendingWrites()`, `summaryCache` approach
- `/Users/vcartier/Desktop/OpenOats-fork/OpenOats/Sources/OpenOats/Views/PastMeetingDetailView.swift` — placeholder card, disabled Slack button, `.task(id: sessionID)` load pattern
- `/Users/vcartier/Desktop/OpenOats-fork/OpenOats/Sources/OpenOats/Views/MeetingSidebarView.swift` — `"_live_"` sentinel pattern, `List(selection: $selectedSessionID)`
- `/Users/vcartier/Desktop/OpenOats-fork/OpenOats/Sources/OpenOats/Views/DetailRouter.swift` — routing switch, all current cases
- `/Users/vcartier/Desktop/OpenOats-fork/OpenOats/Sources/OpenOats/Views/MainAppView.swift` — `@AppStorage("selectedMeetingID")`, `queueSessionSelection` usage
- `/Users/vcartier/Desktop/OpenOats-fork/OpenOats/Sources/OpenOats/Views/SettingsView.swift` — `SPUUpdater` dependency, `.frame(width: 450, height: 750)` constraint
- `/Users/vcartier/Desktop/OpenOats-fork/OpenOats/Sources/OpenOats/Settings/AppSettings.swift` — `LLMProvider` enum, all four provider cases, `KeychainHelper`
- `/Users/vcartier/Desktop/OpenOats-fork/OpenOats/Sources/OpenOats/Models/Models.swift` — `SessionIndex`, `SessionSidecar`, `hasNotes` field
- `/Users/vcartier/Desktop/OpenOats-fork/.planning/research/PITFALLS.md` — Ollama structured output pitfall (Pitfall 7)
- `/Users/vcartier/Desktop/OpenOats-fork/.planning/STATE.md` — Phase 5 blockers: Ollama `format` field MEDIUM confidence warning

### Secondary (MEDIUM confidence — prior phase research)

- `.planning/research/ARCHITECTURE.md` — SummaryEngine component spec, data flow diagrams, build order
- `.planning/phases/05-summary-engine-settings/05-CONTEXT.md` — user decisions, canonical references

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all components exist in codebase; verified by direct file reading
- Architecture (SummaryEngine): HIGH — mirrors well-understood NotesEngine; actor pattern is standard Swift
- Architecture (Settings routing): HIGH — "_live_" sentinel pattern already proven in Phases 2-4
- Ollama structured output: MEDIUM — flagged in STATE.md; fallback strategy documented
- Pitfalls: HIGH — sourced from direct code analysis + prior phase research

**Research date:** 2026-03-22
**Valid until:** 2026-04-22 (stable codebase; no fast-moving external dependencies)
