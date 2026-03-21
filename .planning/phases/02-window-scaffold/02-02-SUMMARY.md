---
phase: 02-window-scaffold
plan: 02
subsystem: app-shell
tags: [sidebar, navigation, tdd, session-history, detail-router]
dependency_graph:
  requires: [02-01]
  provides: [MeetingSidebarView, DetailRouter, groupedSessions, SidebarDateGroupingTests]
  affects: [03-detail-views]
tech_stack:
  added: []
  patterns: [NavigationSplitView-List-selection, ContentUnavailableView, DateComponentsFormatter, TDD-red-green]
key_files:
  created:
    - OpenOats/Sources/OpenOats/Views/MeetingSidebarView.swift
    - OpenOats/Sources/OpenOats/Views/DetailRouter.swift
    - OpenOats/Tests/OpenOatsTests/SidebarDateGroupingTests.swift
  modified:
    - OpenOats/Sources/OpenOats/Views/MainAppView.swift
decisions:
  - "groupedSessions implemented as top-level free function in MeetingSidebarView.swift so @testable import OpenOatsKit exposes it to unit tests"
  - "List(selection: $selectedSessionID) with ForEach + .tag(session.id) used for sectioned sidebar selection binding"
  - "MeetingRowView created as separate struct (not inline) for clean separation"
metrics:
  duration: 3 min
  completed_date: "2026-03-21"
  tasks_completed: 2
  files_created: 3
  files_modified: 1
---

# Phase 02 Plan 02: Sidebar + Detail Router Wiring Summary

**One-liner:** Date-grouped session sidebar with List(selection:) binding and placeholder DetailRouter using ContentUnavailableView states.

## What Was Built

### MeetingSidebarView.swift
- `groupedSessions(_ sessions:)` free function: classifies sessions into Today / Yesterday / Last 7 Days / Earlier buckets, omitting empty sections
- `MeetingSidebarView`: `List(selection: $selectedSessionID)` with `ForEach` over grouped sections; `ContentUnavailableView` for empty state; `.task { await coordinator.loadHistory() }` on appear
- `MeetingRowView`: displays formatted title (app or template name + time), duration via `DateComponentsFormatter`, short date, and `video.fill` / `mic.fill` type badge

### DetailRouter.swift
- Phase 2 placeholder with three states: meeting selected (metadata table), no meetings (onboarding with waveform icon), no selection (ContentUnavailableView prompt)
- Meeting metadata shows formatted date, duration (full style), and meeting type

### MainAppView.swift (updated)
- Sidebar column: replaced `Text("Sidebar — coming in Plan 02")` with `MeetingSidebarView(selectedSessionID: $selectedSessionID)`
- Detail column: replaced `ContentUnavailableView(...)` placeholder with `DetailRouter(selectedSessionID: $selectedSessionID, settings: settings)`

### SidebarDateGroupingTests.swift (8 tests, TDD)
- RED: tests written first, failed on missing `groupedSessions`
- GREEN: implemented function, all 8 passed
- Tests cover: empty input, all four date buckets, mixed sessions, omit-empty-sections invariant, preserve-input-order invariant

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Correction] Test file used correct module name**
- **Found during:** Task 1 RED phase
- **Issue:** Plan template showed `@testable import OpenOats`; actual module is `OpenOatsKit`
- **Fix:** Used `@testable import OpenOatsKit` to match all existing test files
- **Files modified:** SidebarDateGroupingTests.swift
- **Commit:** b88777b

**2. [Rule 2 - Correction] SessionIndex memberwise init includes required fields**
- **Found during:** Task 1
- **Issue:** Plan's `makeSession` helper used `SessionIndex(id:startedAt:)` with only 2 args; actual memberwise init requires `utteranceCount:hasNotes:` as well
- **Fix:** Updated `makeSession` to pass `utteranceCount: 0, hasNotes: false`
- **Files modified:** SidebarDateGroupingTests.swift
- **Commit:** b88777b

## Verification Results

| Check | Result |
|-------|--------|
| `swift test --filter SidebarDateGroupingTests` | 8/8 passed |
| `swift test --filter OpenOatsTests` | 175/175 passed |
| `swift build` | Build complete, 0 errors |
| `MeetingSidebarView(selectedSessionID:` in MainAppView | match |
| `DetailRouter(selectedSessionID:` in MainAppView | match |
| `List(selection: $selectedSessionID)` in MeetingSidebarView | match |
| `.tag(session.id)` in MeetingSidebarView | match |
| `coordinator.loadHistory` in MeetingSidebarView | match |
| No placeholder text remaining | confirmed |

## Self-Check: PASSED
