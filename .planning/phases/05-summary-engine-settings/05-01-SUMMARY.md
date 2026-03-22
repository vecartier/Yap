---
phase: 05-summary-engine-settings
plan: 01
subsystem: intelligence
tags: [swift, llm, openrouter, ollama, summary, tdd, actor, markdown]

# Dependency graph
requires:
  - phase: 04-live-recording-menu-bar-cleanup
    provides: AppCoordinator.finalizeCurrentSession() hook point after awaitPendingWrites()
  - phase: 03-past-meeting-detail
    provides: SlackFormatter.Summary struct with four-section shape
provides:
  - SummaryEngine actor with two-phase LLM generate() (grounding + formatting pass)
  - SummaryEngine.PersistedSummary Codable+Sendable struct
  - SummaryEngine.ProviderConfig Sendable snapshot of AppSettings provider config
  - SummaryEngine.markdownString(for:) static Markdown serializer
  - SummaryState enum (loading / ready(PersistedSummary) / failed(String))
  - OpenRouterClient.completeStructured() with provider-specific structured output format fields
  - AppCoordinator.summaryCache [String: SummaryState] observable property
  - AppCoordinator.generateSummary() private hook called non-blocking after backfillRefinedText
  - AppCoordinator.requestSummaryRetry() public wrapper for retry from UI
  - On-disk summary file: {notesFolderPath}/{sessionID}-summary.md (Markdown)
affects: [05-02-settings, 06-export-pdf, PastMeetingDetailView]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "ProviderConfig Sendable snapshot: capture @MainActor AppSettings values into a Sendable struct before crossing actor boundary into SummaryEngine"
    - "Two-phase LLM generation: grounding pass (evidence extraction, plain text) then formatting pass (structured JSON via completeStructured)"
    - "completeStructured uses JSONSerialization to build request body with provider-specific format field (Ollama: top-level 'format'; OpenRouter/others: 'response_format' json_schema wrapper)"
    - "SummaryState enum in separate SummaryState.swift file (consistent with project pattern of one type per file)"
    - "Non-blocking Task {} for summary generation inside finalizeCurrentSession() — summary runs in background while finalization continues"

key-files:
  created:
    - OpenOats/Sources/OpenOats/Intelligence/SummaryEngine.swift
    - OpenOats/Sources/OpenOats/App/SummaryState.swift
    - OpenOats/Tests/OpenOatsTests/SummaryEngineTests.swift
  modified:
    - OpenOats/Sources/OpenOats/Intelligence/OpenRouterClient.swift
    - OpenOats/Sources/OpenOats/App/AppCoordinator.swift

key-decisions:
  - "SummaryEngine.generate() accepts [Utterance] (in-memory TranscriptStore type) not [SessionRecord] (JSONL type) — both have same fields but utterances are readily available without a JSONL reload"
  - "ProviderConfig Sendable value type captures AppSettings on MainActor before crossing into actor — avoids Swift 6 MainActor isolation errors without making the entire actor @MainActor"
  - "SummaryState extracted to SummaryState.swift (not nested in AppCoordinator) — consistent with project convention of one type per file; enables test access without namespace"
  - "summarySchema uses nonisolated(unsafe) static — [String: Any] is not Sendable, but the value is a compile-time constant never mutated"
  - "Summary generation is non-blocking Task{} in finalizeCurrentSession() — sessionID capture moved up to step 2c so it is available before endSession() clears the store"

patterns-established:
  - "ProviderConfig pattern: use for any future actor that needs AppSettings — always capture on MainActor into Sendable struct"
  - "completeStructured() pattern: build body as [String: Any] via JSONSerialization when provider-specific format keys are needed"

requirements-completed: [SUMM-01, SUMM-02, SUMM-03, SUMM-04, SUMM-05, SUMM-06, SUMM-07, SUMM-08, SUMM-09]

# Metrics
duration: 9min
completed: 2026-03-22
---

# Phase 5 Plan 01: SummaryEngine Summary

**SummaryEngine actor with two-phase LLM summary generation (grounding + structured JSON), auto-triggered after recording ends, persisted as {sessionID}-summary.md Markdown**

## Performance

- **Duration:** 9 min
- **Started:** 2026-03-22T10:07:15Z
- **Completed:** 2026-03-22T10:16:33Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- SummaryEngine actor: two-phase generate() (grounding pass for evidence extraction, formatting pass for structured JSON), PersistedSummary Codable struct, markdownString(for:) static serializer, ProviderConfig Sendable snapshot
- OpenRouterClient.completeStructured() with provider-specific format fields — Ollama uses top-level `format`, OpenRouter/OpenAI-compatible use `response_format` json_schema wrapper
- AppCoordinator wired: summaryCache observable dict, generateSummary() hook called non-blocking after backfillRefinedText, writes {sessionID}-summary.md to notesFolderPath
- SummaryEngineTests TDD cycle: 6 tests written RED first, then GREEN — Markdown headings, extractJSONFromMarkdown fence stripping, emptyTranscript error, SummaryState enum shape

## Task Commits

Each task was committed atomically:

1. **Task 1: SummaryEngineTests scaffold + SummaryEngine actor + OpenRouterClient structured output** - `8ac2e39` (feat)
2. **Task 2: AppCoordinator hook + summaryCache observable + Markdown disk persistence** - `066eb11` (feat)

**Plan metadata:** TBD (docs: complete plan)

_Note: TDD tasks have test commit embedded in feat commit (RED confirmed via build failure, GREEN via passing tests)_

## Files Created/Modified
- `OpenOats/Sources/OpenOats/Intelligence/SummaryEngine.swift` - SummaryEngine actor with two-phase generate(), ProviderConfig, markdownString(for:), extractJSONFromMarkdown()
- `OpenOats/Sources/OpenOats/App/SummaryState.swift` - SummaryState enum (loading / ready / failed)
- `OpenOats/Tests/OpenOatsTests/SummaryEngineTests.swift` - 6 tests covering Markdown format, JSON fence stripping, emptyTranscript error, SummaryState enum shape
- `OpenOats/Sources/OpenOats/Intelligence/OpenRouterClient.swift` - Added completeStructured() method
- `OpenOats/Sources/OpenOats/App/AppCoordinator.swift` - Added summaryEngine, summaryCache, generateSummary(), requestSummaryRetry(), hook in finalizeCurrentSession()

## Decisions Made
- SummaryEngine.generate() accepts `[Utterance]` not `[SessionRecord]` — utterances are already in memory in TranscriptStore after backfill; avoids an extra JSONL reload
- ProviderConfig Sendable value type captures AppSettings on MainActor before crossing into the actor — cleanest Swift 6 solution for @MainActor isolation boundary
- SummaryState in its own file SummaryState.swift — consistent with project pattern, tests can reference without namespace
- summarySchema uses nonisolated(unsafe) static — [String: Any] compile-time constant, never mutated
- Non-blocking Task{} for summary in finalizeCurrentSession() — sessionID moved to step 2c before endSession() clears the store

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Changed SummaryEngine.generate() to accept [Utterance] instead of [SessionRecord]**
- **Found during:** Task 2 (AppCoordinator hook)
- **Issue:** Plan specified `[SessionRecord]` but `transcriptStore.utterances` returns `[Utterance]` — type mismatch, build error
- **Fix:** Changed all generate() overloads and formatTranscript() to accept `[Utterance]`; both types have identical fields used by the engine (speaker, text, refinedText)
- **Files modified:** SummaryEngine.swift, AppCoordinator.swift
- **Verification:** Build succeeds, all tests pass
- **Committed in:** 066eb11 (Task 2 commit)

**2. [Rule 1 - Bug] Added ProviderConfig Sendable snapshot to fix Swift 6 MainActor isolation error**
- **Found during:** Task 1 (GREEN implementation)
- **Issue:** Accessing `@MainActor`-isolated AppSettings properties (llmProvider, openRouterApiKey, etc.) from non-MainActor SummaryEngine actor caused Swift 6 compilation errors
- **Fix:** Introduced `SummaryEngine.ProviderConfig` Sendable struct with `@MainActor init(from: AppSettings)` that captures all provider values synchronously; added convenience `@MainActor` overload of `generate()` that builds ProviderConfig then delegates
- **Files modified:** SummaryEngine.swift
- **Verification:** Build succeeds with zero concurrency errors
- **Committed in:** 8ac2e39 (Task 1 commit)

**3. [Rule 1 - Bug] Fixed extractJSONFromMarkdown() index out of bounds crash**
- **Found during:** Task 1 (GREEN — first test run)
- **Issue:** Original `text[start.lowerBound...end.upperBound]` crashed with "String index out of bounds" because `.upperBound` on a single-character range is already past the character
- **Fix:** Changed to `text.index(after: end.lowerBound)` as exclusive upper bound with half-open range `[lowerBound..<endIndex]`
- **Files modified:** SummaryEngine.swift
- **Verification:** All 6 SummaryEngineTests pass, no crash
- **Committed in:** 8ac2e39 (Task 1 commit)

---

**Total deviations:** 3 auto-fixed (3 bugs)
**Impact on plan:** All auto-fixes necessary for correctness and Swift 6 compliance. No scope creep.

## Issues Encountered
- Swift 6 MainActor isolation is strict — any actor that uses AppSettings must either be @MainActor itself or capture settings into a Sendable snapshot first. The ProviderConfig pattern is now established for future phases.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- SummaryEngine, SummaryState, summaryCache all wired and ready for Phase 05-02 (Settings UI for summary model choice)
- PastMeetingDetailView can now observe `coordinator.summaryCache[sessionID]` and call `coordinator.requestSummaryRetry()` for the Slack copy integration
- `{sessionID}-summary.md` files appear in notesFolderPath after each recording ends

---
*Phase: 05-summary-engine-settings*
*Completed: 2026-03-22*
