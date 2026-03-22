---
phase: 04-live-recording-menu-bar-cleanup
plan: 02
subsystem: ui
tags: [swiftui, menubar, macos, popover]

# Dependency graph
requires:
  - phase: 04-01
    provides: LiveDetailView, DetailRouter, MeetingListItem live case, MainAppView auto-navigate
provides:
  - MenuBarPopoverView with 3 idle start buttons (Start Call, Solo memo, Solo room)
  - ContentView.swift deleted — legacy popover UI gone
  - NotesView.swift deleted — legacy notes window view gone
  - All openWindow(id: "notes") call sites eliminated
affects:
  - 04-03 (human verify)
  - 05-summary-engine (menu bar entry point confirmed minimal)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Menu bar popover idle state: 3 bordered buttons, each with consent gate via onShowMainWindow"
    - "Legacy view deletion pattern: audit all refs (grep), confirm no external instantiations, delete files, rebuild"

key-files:
  created: []
  modified:
    - OpenOats/Sources/OpenOats/Views/MenuBarPopoverView.swift
  deleted:
    - OpenOats/Sources/OpenOats/Views/ContentView.swift
    - OpenOats/Sources/OpenOats/Views/NotesView.swift

key-decisions:
  - "ContentView.swift is fully self-contained — all openWindow(id: 'notes') calls lived inside it; deletion was safe with zero external references needing cleanup"
  - "No Window('notes') scene existed in OpenOatsApp.swift at time of deletion (already removed in a prior phase); only ContentView's internal calls remained"
  - "Comment references to 'ContentView' in TranscriptionEngine.swift and LiveDetailView.swift are harmless (not type references); no changes needed"

patterns-established:
  - "Menu bar popover has no live transcript — transcript only lives in main window LiveDetailView"
  - "Three start modes accessible from both popover (Task 1) and main window (MainAppView flow)"

requirements-completed: [MENU-01, MENU-02, MENU-03]

# Metrics
duration: 6min
completed: 2026-03-22
---

# Phase 4 Plan 2: Menu Bar Cleanup Summary

**MenuBarPopoverView expanded to 3 start buttons (Start Call / Solo memo / Solo room) and legacy ContentView.swift + NotesView.swift (1197 lines) deleted with zero broken references**

## Performance

- **Duration:** ~6 min
- **Started:** 2026-03-22T09:17:00Z
- **Completed:** 2026-03-22T09:23:15Z
- **Tasks:** 2 of 2 auto tasks complete (Task 3 is human-verify checkpoint)
- **Files modified:** 1 modified, 2 deleted

## Accomplishments
- MenuBarPopoverView idle branch now shows 3 bordered buttons — Start Call, Solo (memo), Solo (room) — each with consent gate, replacing the single "Start Recording" button
- ContentView.swift (529 lines) deleted — legacy popover UI with transcript, openWindow(id: "notes") calls, and ControlBar integration gone
- NotesView.swift (668 lines) deleted — legacy notes window view fully removed
- All openWindow(id: "notes") call sites eliminated (were only inside ContentView.swift)
- swift build clean, 197/197 tests passing

## Task Commits

Each task was committed atomically:

1. **Task 1: Expand MenuBarPopoverView idle state to three start buttons** - `9cbe7bb` (feat)
2. **Task 2: Delete ContentView.swift and NotesView.swift** - `17fc0d2` (feat)

## Files Created/Modified
- `OpenOats/Sources/OpenOats/Views/MenuBarPopoverView.swift` - Replaced single "Start Recording" button with VStack of 3 bordered buttons: Start Call, Solo (memo), Solo (room)
- `OpenOats/Sources/OpenOats/Views/ContentView.swift` - DELETED (529 lines of legacy popover UI)
- `OpenOats/Sources/OpenOats/Views/NotesView.swift` - DELETED (668 lines of legacy notes window view)

## Decisions Made
- ContentView.swift was fully self-contained: all `openWindow(id: "notes")` calls (4 occurrences) lived only inside ContentView.swift. MainAppView already handled `.openNotes` via `selectedSessionID = sessionID` from Plan 04-01. No external cleanup needed beyond the file deletion.
- Comment references to "ContentView" in TranscriptionEngine.swift and LiveDetailView.swift were left as-is (they are code comments, not type references, and are accurate historical context).

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 04 implementation tasks complete pending human verification (Task 3 checkpoint)
- Menu bar is now minimal: 3 start buttons when idle, Stop + status when recording, no live transcript
- Legacy views gone — all recording starts and history browsing go through main window
- Ready for Phase 05 (summary engine) once checkpoint is approved

## Self-Check: PASSED

- MenuBarPopoverView.swift: FOUND
- ContentView.swift: CONFIRMED DELETED
- NotesView.swift: CONFIRMED DELETED
- 04-02-SUMMARY.md: FOUND
- Commit 9cbe7bb (Task 1): FOUND
- Commit 17fc0d2 (Task 2): FOUND

---
*Phase: 04-live-recording-menu-bar-cleanup*
*Completed: 2026-03-22*
