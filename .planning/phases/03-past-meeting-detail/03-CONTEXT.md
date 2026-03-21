# Phase 3: Past Meeting Detail - Context

**Gathered:** 2026-03-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Replace the DetailRouter placeholder (Phase 2) with a real PastMeetingDetailView. Granola-style unified scrollable view: metadata header → summary card (placeholder until Phase 5) → full transcript. Add Slack copy button (disabled until summary engine exists). Wire session data loading.

</domain>

<decisions>
## Implementation Decisions

### Detail Pane Layout
- **Single continuous scroll** — metadata, summary card, and transcript all in one scrollable view (Granola-style)
- **No split panes** — everything flows together, not fixed header + scrolling body
- **Order top to bottom:** Meeting metadata → Summary card (placeholder) → Transcript
- **Action buttons (Slack copy, future export) sit inline below the summary card** — not in a toolbar or floating bar

### Summary Section (Placeholder)
- **Empty card placeholder** with subtle outline — "Summary will appear here" message
- Card shows where the summary will eventually render (Phase 5)
- Slack copy button exists below the card but is **disabled/greyed out** with tooltip "Summary required"
- When Phase 5 adds the summary engine, it populates this card and enables the button

### Transcript Display
- **Labeled lines** format: `[timestamp] Speaker: text` — clean, scannable, like meeting minutes
- **Timestamps:** Granola-style — show timestamps every few minutes as subtle section markers, not on every utterance. Exact cadence is Claude's discretion.
- **Speaker labels:** "You", "Them", or "Room" — consistent with existing Speaker enum
- Speaker labels should be visually distinct (bold or colored) to scan quickly

### Slack Message Format (Template for Phase 5)
- **Structured sections** with bold headers and bullet points:
  ```
  *Meeting: [Title] — [Date]*

  *Key Decisions*
  • Decision 1
  • Decision 2

  *Action Items*
  • Action 1
  • Action 2

  *Discussion Points*
  • Point 1

  *Open Questions*
  • Question 1
  ```
- Uses Slack mrkdwn syntax (`*bold*`, `•` bullets)
- The `SlackFormatter` should be a separate utility — not embedded in the view

### Slack Copy Button (Pre-Summary)
- Button exists in the UI but is **disabled** until Phase 5 provides a summary
- Tooltip: "Summary required" when disabled
- When enabled (Phase 5): copies the Slack-formatted message to NSPasteboard

### Claude's Discretion
- Exact timestamp cadence for transcript (every 2-3 minutes or similar)
- Speaker label colors/styling
- Summary placeholder card visual design
- Transcript line spacing and font sizing
- Loading state while transcript data fetches from SessionStore
- Whether to use `LazyVStack` vs `List` for transcript performance

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Detail pane integration
- `OpenOats/Sources/OpenOats/Views/DetailRouter.swift` — Current placeholder to replace; has meeting metadata helpers to reuse
- `OpenOats/Sources/OpenOats/Views/MainAppView.swift` — Parent view, passes selectedSessionID + settings to DetailRouter
- `OpenOats/Sources/OpenOats/Views/NotesView.swift` — Existing transcript loading logic (`loadedTranscript: [SessionRecord]`), session data fetching patterns — reference implementation

### Session data
- `OpenOats/Sources/OpenOats/Storage/SessionStore.swift` — `loadTranscript(sessionID:)` returns `[SessionRecord]`
- `OpenOats/Sources/OpenOats/Models/Models.swift` — `SessionRecord` struct (speaker, text, timestamp), `Speaker` enum (.you, .them, .room)
- `OpenOats/Sources/OpenOats/App/AppCoordinator.swift` — `sessionStore`, `sessionHistory`

### Architecture research
- `.planning/research/ARCHITECTURE.md` — PastMeetingDetailView component spec, data flow diagrams

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `DetailRouter.meetingMetadata(for:)` — already renders date, duration, type — move into PastMeetingDetailView or extract as shared component
- `DetailRouter.formattedDate()`, `formattedDuration()`, `meetingType()` — reuse these helpers
- `NotesView` transcript loading pattern: `coordinator.sessionStore.loadTranscript(sessionID:)` in `.task {}` modifier
- `TranscriptView.swift` — existing transcript rendering component, may be reusable for the labeled-lines format

### Established Patterns
- `@Environment(AppCoordinator.self)` for coordinator access
- `.task { }` modifier for async data loading on view appear
- `SessionRecord` has: `.speaker` (Speaker enum), `.text` (String), `.timestamp` (Date), `.refinedText` (String?)

### Integration Points
- `DetailRouter.swift` — replace the `if let sessionID` branch with `PastMeetingDetailView(sessionID:settings:)`
- `PastMeetingDetailView` loads transcript via `coordinator.sessionStore.loadTranscript(sessionID:)`
- `SlackFormatter` — new utility file in Intelligence/ or a new Formatting/ directory

</code_context>

<specifics>
## Specific Ideas

- Granola as the visual reference — summary flows into transcript, not tabbed
- Slack message uses mrkdwn formatting (Slack's markdown dialect)
- SlackFormatter as a standalone utility, not coupled to the view

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 03-past-meeting-detail*
*Context gathered: 2026-03-21*
