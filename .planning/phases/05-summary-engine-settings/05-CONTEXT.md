# Phase 5: Summary Engine + Settings - Context

**Gathered:** 2026-03-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Build SummaryEngine actor that auto-generates structured summaries on session end. Hook into AppCoordinator after awaitPendingWrites(). Populate PastMeetingDetailView summary card and enable Slack copy button. Move Settings into a gear icon in the sidebar bottom.

</domain>

<decisions>
## Implementation Decisions

### Summary Generation UX
- **Spinner then reveal** — "Generating summary..." spinner in the summary card area, then full summary appears at once when complete
- **No streaming** — don't show word-by-word, wait for complete result
- **One-shot** — summary generates once on session end, no regenerate button
- **Error handling:** Error message in summary card + "Retry" button if LLM call fails. Transcript still visible below.

### Summary Quality / Tone
- **Casual brief** tone — natural, like quick notes to yourself. "We went with option B" not "The team decided to proceed with option B"
- **Proportional length** — short meetings get short summaries, long meetings get longer ones. LLM decides based on transcript length.
- **Four sections:** Key Decisions, Action Items, Discussion Points, Open Questions (already defined in MeetingSummary struct)
- **Action item attribution:** Include owner names where identifiable from transcript context (e.g., "Vincent to follow up on X")

### Two-Phase LLM Prompt (from Phase 1 research)
- **Phase 1 (Grounding):** Extract cited evidence from transcript — direct quotes and speaker attributions
- **Phase 2 (Formatting):** Structure grounded evidence into the four summary sections
- This prevents hallucination (~14% false positive action items with single-phase prompt)

### Summary Persistence
- Saved as Markdown file alongside transcript in ~/Documents/OpenOats/
- Filename: `{session-id}-summary.md`
- Loaded by PastMeetingDetailView when displaying a past session

### Summary Card (Populating Phase 3 Placeholder)
- Replace the placeholder card with actual summary content
- Enable the Slack copy button (was disabled with "Summary required" tooltip)
- SlackFormatter.format() already exists — just pass the MeetingSummary to it

### Provider Support
- Must work with OpenRouter (cloud) — structured JSON output via `response_format: json_schema`
- Must work with Ollama (local) — use Ollama's native `format` field (OpenAI-compat `response_format` is unreliable per Phase 1 research)
- Fallback: if structured output fails, extract sections from markdown response

### Hook Point
- Summary generation triggers from `AppCoordinator.finalizeCurrentSession()` AFTER `awaitPendingWrites()`
- Not triggered from UI layer
- Runs as a Task — doesn't block finalization

### Settings Tab
- **Gear icon pinned at sidebar bottom** — click shows settings in detail pane (like Granola)
- **Settings include:** LLM provider + model selection, API keys (Keychain), transcription model selection
- **Audio input:** Use system default, no explicit selector (user said "should just be by default")
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

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Summary engine integration
- `OpenOats/Sources/OpenOats/App/AppCoordinator.swift` — `finalizeCurrentSession()`, `awaitPendingWrites()` — hook point for summary generation
- `OpenOats/Sources/OpenOats/Intelligence/OpenRouterClient.swift` — existing LLM client, `complete()` for structured JSON, `streamCompletion()` for streaming
- `OpenOats/Sources/OpenOats/Intelligence/NotesEngine.swift` — existing notes generation pattern, reference for how LLM calls are structured
- `OpenOats/Sources/OpenOats/Intelligence/SlackFormatter.swift` — `MeetingSummary` struct definition, `SlackFormatter.format()`, `transcriptRows()`

### Summary display
- `OpenOats/Sources/OpenOats/Views/PastMeetingDetailView.swift` — Has summary placeholder card + disabled Slack copy button to populate/enable
- `OpenOats/Sources/OpenOats/Storage/TranscriptStore.swift` — Where conversation state is tracked

### Settings
- `OpenOats/Sources/OpenOats/Views/SettingsView.swift` — Existing settings UI to embed in main window
- `OpenOats/Sources/OpenOats/Settings/AppSettings.swift` — All settings properties
- `OpenOats/Sources/OpenOats/Views/MeetingSidebarView.swift` — Sidebar where gear icon goes
- `OpenOats/Sources/OpenOats/Views/MainAppView.swift` — Parent view, detail pane routing

### Prior research
- `.planning/research/ARCHITECTURE.md` — SummaryEngine component spec
- `.planning/research/PITFALLS.md` — Ollama structured output compatibility, transcript truncation warning

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `OpenRouterClient.complete()` — non-streaming structured JSON output, already supports `response_format`
- `NotesEngine` — reference pattern for LLM-based content generation (streaming markdown)
- `MeetingSummary` struct — already defined in `SlackFormatter.swift` with decisions, actionItems, discussionPoints, openQuestions arrays
- `SlackFormatter.format()` — already tested, ready to receive real MeetingSummary data
- `SettingsView` — complete settings UI, just needs embedding in main window detail pane
- `AppSettings.llmProvider`, `AppSettings.selectedModel` — existing provider/model selection

### Established Patterns
- Actor isolation for engines (SessionStore, TranscriptLogger)
- `@Observable` for UI-bound state (AppCoordinator)
- `OpenRouterClient` as the shared LLM client across Intelligence/ components
- `.task {}` modifier for async data loading in views

### Integration Points
- `AppCoordinator.finalizeCurrentSession()` — add summary generation call after `awaitPendingWrites()`
- `PastMeetingDetailView` — replace placeholder card with summary section, enable Slack copy button
- `MeetingSidebarView` — add gear icon at bottom for settings
- `DetailRouter` — add settings routing case
- `MainAppView` — handle settings selection state

</code_context>

<specifics>
## Specific Ideas

- Casual brief tone for summaries — "We decided X" not "The team resolved to X"
- Proportional length — LLM decides based on transcript length
- Error in card with Retry — user never loses the transcript even if summary fails

</specifics>

<deferred>
## Deferred Ideas

- Templates system (custom summary/Slack prompts per meeting type) — v2, from user's PLANNING.md
- Editable summary before sending to Slack — v2
- Regenerate button for summaries — user chose one-shot for v1

</deferred>

---

*Phase: 05-summary-engine-settings*
*Context gathered: 2026-03-22*
