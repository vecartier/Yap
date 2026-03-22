---
phase: 05-summary-engine-settings
plan: 02
subsystem: UI/UX
tags: [summary-display, settings, sidebar, keyboard-shortcut, slack-copy]
dependency_graph:
  requires: [05-01]
  provides: [summary-card-ui, settings-gear-tab, cmd-comma-shortcut]
  affects: [PastMeetingDetailView, MeetingSidebarView, DetailRouter, MainAppView, OpenOatsApp]
tech_stack:
  added: [SPUUpdater threading via parameter chain]
  patterns: [SummaryState switch in @ViewBuilder, Markdown disk-load with section parser, SessionRecord-to-Utterance conversion for retry]
key_files:
  created: []
  modified:
    - OpenOats/Sources/OpenOats/Views/PastMeetingDetailView.swift
    - OpenOats/Sources/OpenOats/Views/MeetingSidebarView.swift
    - OpenOats/Sources/OpenOats/Views/DetailRouter.swift
    - OpenOats/Sources/OpenOats/Views/MainAppView.swift
    - OpenOats/Sources/OpenOats/App/OpenOatsApp.swift
decisions:
  - "SPUUpdater threaded as parameter (OpenOatsRootApp -> MainAppView -> DetailRouter) — not env-injected; updaterController is a let on root app, not available via @Environment"
  - "retrySummary() converts [SessionRecord] to [Utterance] inline — loadTranscript returns SessionRecord but requestSummaryRetry accepts Utterance; conversion uses matching fields"
  - "onChange(of: coordinator.summaryCache[sessionID] != nil) uses Bool wrapper — SummaryState not Equatable, optional subscript on dictionary; Bool bridge avoids spurious triggers"
  - "CommandGroup(replacing: .appSettings) removes the system Settings menu item — this prevents duplicate Settings entries since SettingsView is now in the main window detail pane"
metrics:
  duration: 5 min
  completed_date: "2026-03-22"
  tasks_completed: 2
  files_modified: 5
---

# Phase 05 Plan 02: Summary UI and Settings Tab Summary

Summary card and settings gear tab wired — PastMeetingDetailView shows live SummaryState from coordinator cache or parses `{sessionID}-summary.md` Markdown from disk, with spinner/content/error+retry states; gear icon at sidebar bottom routes to embedded SettingsView via DetailRouter `.settings` case; Cmd+, shortcut routes through `coordinator.queueSessionSelection`.

## Tasks Completed

| # | Task | Commit | Key Files |
|---|------|--------|-----------|
| 1 | PastMeetingDetailView summary card — live state + Markdown disk-load + Slack enable | 529469c | PastMeetingDetailView.swift |
| 2 | Settings gear icon + DetailRouter + Cmd+, shortcut | 71f9c83 | MeetingSidebarView.swift, DetailRouter.swift, MainAppView.swift, OpenOatsApp.swift |

## What Was Built

**Task 1 — Summary card in PastMeetingDetailView:**
- Replaced `summaryPlaceholderCard` with `summarySection` that switches on `SummaryState?`
- Four states: `nil` (no summary placeholder), `.loading` (spinner), `.failed` (error+Retry), `.ready` (four bullet sections)
- `.task(id: sessionID)` block checks `coordinator.summaryCache[sessionID]` first, then falls back to parsing `{sessionID}-summary.md` Markdown from disk
- `parseSummaryMarkdown(_:sessionID:)` scans section headings (`## Key Decisions`, etc.) and bullet lines (`- item`) to reconstruct `SummaryEngine.PersistedSummary`
- `.onChange` observer reacts when coordinator generates a new summary during the session
- Slack copy button enabled when `canCopySlack` is true (`.ready` state); converts to `SlackFormatter.Summary` and puts `SlackFormatter.format()` output on `NSPasteboard.general`
- `retrySummary()` converts `[SessionRecord]` to `[Utterance]` inline (matching fields) before calling `coordinator.requestSummaryRetry`

**Task 2 — Settings gear + routing + Cmd+,:**
- `MeetingSidebarView`: wrapped existing `List` in `VStack(spacing: 0)`, added `Divider()` + gear `Button` pinned below; button sets `selectedSessionID = "_settings_"` and shows highlight when active
- `DetailRouter`: added `let updater: SPUUpdater` parameter; added `.settings` to `Content` enum and `resolvedContent`; `.settings` case renders `SettingsView` inside `ScrollView`
- `MainAppView`: added `let updater: SPUUpdater` parameter; added `.onChange(of: coordinator.requestedSessionSelectionID)` calling `consumeRequestedSessionSelection()` to drive navigation
- `OpenOatsApp.swift`: passes `updaterController.updater` to `MainAppView`; adds `CommandGroup(replacing: .appSettings)` with Cmd+, that calls `coordinator.queueSessionSelection("_settings_")` + `showMainWindow()`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Converted [SessionRecord] to [Utterance] in retrySummary()**
- **Found during:** Task 1 — implementing retrySummary()
- **Issue:** `coordinator.requestSummaryRetry` accepts `[Utterance]` but `sessionStore.loadTranscript` returns `[SessionRecord]`; these are distinct types with the same fields
- **Fix:** Inline `map` converting `SessionRecord` -> `Utterance(text:speaker:timestamp:refinedText:)` in `retrySummary()`
- **Files modified:** PastMeetingDetailView.swift
- **Commit:** 529469c (inline in Task 1)

## Test Results

203 tests passing, 0 failures — unchanged from Plan 01 baseline.

## Self-Check: PASSED
