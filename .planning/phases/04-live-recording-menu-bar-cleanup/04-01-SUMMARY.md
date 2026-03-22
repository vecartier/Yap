---
phase: 04-live-recording-menu-bar-cleanup
plan: 01
subsystem: live-recording-ui
tags: [live-recording, navigation, sidebar, detail-view, utterance-persistence]
dependency_graph:
  requires:
    - Phase 03 PastMeetingDetailView (NavigationSplitView scaffold, DetailRouter base)
    - Phase 02 MeetingSidebarView (groupedSessions, List selection binding)
  provides:
    - LiveDetailView (live transcript + recording header in main window)
    - MeetingListItem enum (testable, Identifiable/Hashable)
    - _live_ routing sentinel in DetailRouter
    - Auto-navigate hooks in MainAppView
  affects:
    - DetailRouter (extended with .live case)
    - MeetingSidebarView (live row prepended when recording/finalizing)
    - MainAppView (onChange hooks added)
    - Models.swift (SessionIndex/TemplateSnapshot gain Equatable + Hashable)
tech_stack:
  added:
    - MeetingListItem enum (top-level in MeetingSidebarView.swift, testable)
    - LiveDetailView (new SwiftUI view file)
    - LiveSessionRowView (private struct in MeetingSidebarView.swift)
  patterns:
    - Task.sleep timer loop (consistent with MenuBarPopoverView pattern)
    - isFinalizing computed var via exhaustive switch on coordinator.state
    - Utterance persistence via onChange(of: utterances.count) — verbatim ContentView port
    - _live_ sentinel string for routing (avoids type-unsafe Bool flags)
key_files:
  created:
    - OpenOats/Sources/OpenOats/Views/LiveDetailView.swift
    - OpenOats/Tests/OpenOatsTests/MeetingListItemTests.swift
  modified:
    - OpenOats/Sources/OpenOats/Views/DetailRouter.swift
    - OpenOats/Sources/OpenOats/Views/MeetingSidebarView.swift
    - OpenOats/Sources/OpenOats/Views/MainAppView.swift
    - OpenOats/Sources/OpenOats/Models/Models.swift
decisions:
  - "SessionIndex and TemplateSnapshot gained Equatable + Hashable to enable onChange(of: lastEndedSession) binding and MeetingListItem auto-synthesis — safe because all stored properties are value types"
  - "isFinalizing checks coordinator.state directly (not coordinator.isRecording) because .ending state returns false for isRecording — this keeps LiveDetailView and LiveSessionRowView visible during finalization"
  - "MeetingListItem declared as top-level enum in MeetingSidebarView.swift for @testable import accessibility — consistent with groupedSessions free-function pattern from Phase 2"
  - "_live_ sentinel string is sole routing signal in DetailRouter — not coordinator.isRecording — ensuring Finalizing state stays on LiveDetailView"
metrics:
  duration: 5 min
  completed_date: "2026-03-22"
  tasks_completed: 3
  files_modified: 6
---

# Phase 4 Plan 1: Live Recording Main Window Presence Summary

**One-liner:** Live transcript in main window detail pane via `_live_` sentinel routing — LiveDetailView with recording header, pulsing sidebar row, and verbatim utterance persistence from ContentView.

## What Was Built

- **LiveDetailView.swift** (new): Recording header (pulsing red dot, elapsed timer, Stop/Finalizing state) + live `TranscriptView`. Utterance persistence (`handleNewUtterance`/`handleNewUtterances`) ported verbatim from ContentView — sessions now get utterances written to disk during recording from the main window.
- **DetailRouter.swift** (updated): `Content` private enum with `.live`, `.past(String)`, `.empty` cases. Routes `selectedSessionID == "_live_"` to `LiveDetailView`, real IDs to `PastMeetingDetailView`, `nil` to onboarding/empty state.
- **MeetingSidebarView.swift** (updated): `MeetingListItem` top-level enum (`Identifiable, Hashable`) with `.live` and `.session(SessionIndex)` cases. `LiveSessionRowView` private struct prepended at top of List when `isRecording || isFinalizing`. Removed the history-empty guard — List always renders (live row may be present even with no history).
- **MainAppView.swift** (updated): Two `onChange` modifiers — `isRecording` sets `selectedSessionID = "_live_"` on start (no-op on stop to avoid empty flash during finalization); `lastEndedSession` navigates to completed session after finalization.
- **Models.swift** (updated): `SessionIndex` and `TemplateSnapshot` gained `Equatable` and `Hashable` — required for `onChange(of: coordinator.lastEndedSession)` and `MeetingListItem` auto-synthesis.
- **MeetingListItemTests.swift** (new): 5 unit tests covering `.live.id` sentinel, `.session.id` match, `Equatable`, `Hashable` — all GREEN.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Added Equatable/Hashable to SessionIndex and TemplateSnapshot**
- **Found during:** Task 2 — swift build
- **Issue:** `SessionIndex` only conformed to `Identifiable, Codable, Sendable`. This blocked two things: (1) `MeetingListItem: Hashable` synthesis (SessionIndex as associated value), (2) `onChange(of: coordinator.lastEndedSession)` which requires `Equatable` on `SessionIndex?`.
- **Fix:** Added `Equatable, Hashable` to `TemplateSnapshot` first (required for SessionIndex synthesis), then to `SessionIndex`.
- **Files modified:** `OpenOats/Sources/OpenOats/Models/Models.swift`
- **Commit:** included in `7432736`

## Test Results

- `swift build`: clean (0 errors, pre-existing warnings in MarkdownMeetingWriter/TranscriptCleanupEngine out of scope)
- `swift test --filter MeetingListItemTests`: 5/5 passed
- `swift test` (full suite): 197/197 passed (up from 192 — 5 new tests added)

## Self-Check: PASSED

- LiveDetailView.swift: FOUND
- MeetingListItemTests.swift: FOUND
- 04-01-SUMMARY.md: FOUND
- Commit 8d5940f (test scaffold): FOUND
- Commit 7432736 (feat implementation): FOUND
