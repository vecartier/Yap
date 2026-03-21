---
phase: 03-past-meeting-detail
plan: "02"
subsystem: ui
tags: [swiftui, transcript, detail-view, macos, slack]

# Dependency graph
requires:
  - phase: 03-01
    provides: transcriptRows(for:) free function and SlackFormatter.Summary struct
  - phase: 02-window-scaffold
    provides: DetailRouter.swift with selectedSessionID binding and AppCoordinator environment
provides:
  - PastMeetingDetailView: single-pane detail view with metadata, summary placeholder, disabled Slack copy button, transcript with periodic timestamps
  - PastMeetingDetailTests: pure logic tests for empty transcript and zero-duration helper paths
  - Wired DetailRouter: routes all past-session selections to PastMeetingDetailView
affects:
  - phase 05-summary-engine (summary placeholder card and disabled Slack copy button are the integration points)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Private TranscriptRow file-private struct in same file as parent view
    - .task(id: sessionID) pattern for stale-free async session loading on selection change
    - Metadata badge helper (Text + background + rounded rectangle) for compact date/duration/type display

key-files:
  created:
    - OpenOats/Sources/OpenOats/Views/PastMeetingDetailView.swift
    - OpenOats/Tests/OpenOatsTests/PastMeetingDetailTests.swift
  modified:
    - OpenOats/Sources/OpenOats/Views/DetailRouter.swift

key-decisions:
  - "Private helpers (formattedDate, formattedDuration, meetingType) live in PastMeetingDetailView, not DetailRouter — they are only needed by the detail view"
  - "Speaker.room renders as 'Room' with Color.secondary — visually distinct from .you and .them without a new color token"
  - "Slack copy button disabled with .help('Summary required') — placeholder for Phase 5 summary engine integration"

patterns-established:
  - "TranscriptRow: file-private struct in PastMeetingDetailView.swift — keeps the parent file self-contained without a separate file for a small private subview"
  - ".task(id: sessionID): always use id-parameterised task on detail views that load from selection — prevents stale content on rapid navigation"

requirements-completed: [WIN-04, SLCK-03]

# Metrics
duration: 2min
completed: 2026-03-21
---

# Phase 3 Plan 02: PastMeetingDetailView Summary

**Granola-style unified meeting detail view with metadata header, summary placeholder card, disabled Slack copy button, and per-speaker transcript with periodic 2-minute timestamp markers, wired into DetailRouter replacing the Phase 2 placeholder**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-21T16:03:12Z
- **Completed:** 2026-03-21T16:05:44Z
- **Tasks:** 3 (2 auto + 1 auto-approved checkpoint)
- **Files modified:** 3

## Accomplishments
- PastMeetingDetailView: single ScrollView with four sections — metadata header (title + date/duration/type badges), summary placeholder card (stroke border, "Summary will appear here"), disabled "Copy for Slack" button with "Summary required" tooltip, and full transcript
- Private TranscriptRow sub-view handles all three Speaker cases (.you/.them/.room) with distinct colors; periodic timestamp markers appear every ≥120 seconds via `transcriptRows(for:)`
- DetailRouter updated: replaced the 60-line Phase 2 placeholder (with its private helper functions) with a single `PastMeetingDetailView(sessionID: sessionID, settings: settings)` call
- 192 tests all green — 2 new PastMeetingDetailTests (pure logic), no regressions

## Task Commits

Each task was committed atomically:

1. **Task 1: Create PastMeetingDetailTests scaffold + PastMeetingDetailView** - `d088f91` (feat)
2. **Task 2: Wire DetailRouter to PastMeetingDetailView** - `c830b7a` (feat)
3. **Task 3: Verify detail pane in running app** - auto-approved (checkpoint)

## Files Created/Modified
- `OpenOats/Sources/OpenOats/Views/PastMeetingDetailView.swift` - New unified detail view: metadata, summary placeholder, Slack copy button, transcript with speaker labels
- `OpenOats/Tests/OpenOatsTests/PastMeetingDetailTests.swift` - Two pure logic tests: empty transcript path and zero-duration helper
- `OpenOats/Sources/OpenOats/Views/DetailRouter.swift` - Replaced 60-line Phase 2 placeholder with one-line PastMeetingDetailView call; removed now-unused helpers

## Decisions Made
- Private helpers (formattedDate, formattedDuration, meetingType) moved into PastMeetingDetailView — they were only used by the detail view after Phase 3, not by DetailRouter itself
- Speaker.room renders as "Room" with Color.secondary — reuses an existing color token rather than introducing a new one
- Slack copy button disabled with `.help("Summary required")` — exact placeholder for Phase 5 integration

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 3 is complete: PastMeetingDetailView fully wired and displaying past meeting data
- Phase 5 (SummaryEngine): the summary placeholder card and disabled Slack copy button are the integration points — Phase 5 will replace the placeholder with real content and enable the copy button

---
*Phase: 03-past-meeting-detail*
*Completed: 2026-03-21*
