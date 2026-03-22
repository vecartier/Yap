# Phase 6: Search + Export - Context

**Gathered:** 2026-03-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Add full-text search across all past meetings (titles, transcripts, summaries) with real-time sidebar filtering. Add PDF export for any meeting (metadata + summary + transcript). This is the final v1 phase.

</domain>

<decisions>
## Implementation Decisions

### Search
- **Search scope:** Titles + transcript text + summary text (all three)
- **Search bar:** SwiftUI `.searchable` modifier — native macOS search in sidebar toolbar
- **Filtering:** Real-time sidebar filtering as user types
- **Background thread with debounce** — don't block UI (locked from requirements)
- **No results:** Standard empty state in sidebar when search matches nothing

### PDF Export
- **Content:** Metadata header + summary (if exists) + full transcript — complete meeting record
- **No user choice at export** — always exports the full record
- **Multi-page pagination** via NSPrintOperation (NOT ImageRenderer) — locked from research
- **Export trigger:** Button in the PastMeetingDetailView (alongside Slack copy button)

### Claude's Discretion
- Search debounce interval (200-500ms typical)
- How transcript/summary content is loaded for search (lazy load vs index on launch)
- PDF styling (fonts, margins, header formatting)
- Export button placement and icon
- "No results" empty state design
- Whether to highlight search matches in the sidebar rows

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Search integration
- `OpenOats/Sources/OpenOats/Views/MeetingSidebarView.swift` — Sidebar list to add .searchable to; groupedSessions() function to filter
- `OpenOats/Sources/OpenOats/Views/MainAppView.swift` — Parent NavigationSplitView, may need search state
- `OpenOats/Sources/OpenOats/App/AppCoordinator.swift` — sessionHistory data source
- `OpenOats/Sources/OpenOats/Storage/SessionStore.swift` — loadTranscript(sessionID:) for search content

### PDF export integration
- `OpenOats/Sources/OpenOats/Views/PastMeetingDetailView.swift` — Where export button goes
- `OpenOats/Sources/OpenOats/Intelligence/SlackFormatter.swift` — MeetingSummary struct, transcriptRows()

### Research
- `.planning/research/STACK.md` — NSPrintOperation for PDF, localizedStandardContains for search
- `.planning/research/PITFALLS.md` — ImageRenderer trap, search debounce requirement

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `groupedSessions()` in MeetingSidebarView — already groups sessions; filter before grouping for search
- `SessionStore.loadTranscript(sessionID:)` — loads [SessionRecord] for a session
- `String.localizedStandardContains()` — recommended search method from research
- `PastMeetingDetailView` metadata helpers — reuse for PDF header
- `SummaryEngine.markdownString(for:)` — formatted summary text for PDF

### Established Patterns
- `.searchable` SwiftUI modifier for native macOS search
- Actor isolation for background work
- `@State` for search text binding

### Integration Points
- `MeetingSidebarView` or `MainAppView` — add `.searchable(text:)` modifier
- `PastMeetingDetailView` — add "Export PDF" button near Slack copy
- New `PDFExporter` utility (or extension) for NSPrintOperation logic

</code_context>

<specifics>
## Specific Ideas

No specific requirements — standard macOS patterns for search and PDF export.

</specifics>

<deferred>
## Deferred Ideas

None — final v1 phase. All v2 features (calendar, templates, Slack auto-send) captured in PROJECT.md backlog.

</deferred>

---

*Phase: 06-search-export*
*Context gathered: 2026-03-22*
