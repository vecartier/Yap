---
phase: 02-window-scaffold
plan: 01
subsystem: app-shell
tags: [window-scene, navigation, branding, menu-bar]
dependency_graph:
  requires: [01-foundation]
  provides: [MainAppView, singleton-Window-scene, Papyrus-branding]
  affects: [02-02-sidebar-wiring]
tech_stack:
  added: []
  patterns: [Window-not-WindowGroup, NavigationSplitView-balanced, activation-policy-flip]
key_files:
  created:
    - OpenOats/Sources/OpenOats/Views/MainAppView.swift
  modified:
    - OpenOats/Sources/OpenOats/App/OpenOatsApp.swift
    - OpenOats/Sources/OpenOats/App/MenuBarController.swift
    - OpenOats/Sources/OpenOats/Views/MenuBarPopoverView.swift
decisions:
  - "Use @State (not @SceneStorage) for NavigationSplitViewVisibility — type does not conform to RawRepresentable"
metrics:
  duration: 3 min
  completed_date: "2026-03-21T15:03:54Z"
  tasks_completed: 2
  files_changed: 4
---

# Phase 02 Plan 01: Window Scaffold and Papyrus Rename Summary

**One-liner:** Single Window("Papyrus") scene at 900x600 with system title bar, hosting MainAppView NavigationSplitView scaffold with all lifecycle preserved.

## What Was Built

### Task 1: MainAppView.swift + OpenOatsApp.swift window scene update

Created `MainAppView.swift` as a `NavigationSplitView` scaffold with placeholder sidebar and detail panes (wired in Plan 02). The view carries forward all lifecycle work that previously lived on the Window scene in OpenOatsApp:

- `.onAppear`: wires AppDelegate properties (coordinator, settings, runtime), calls `setupMenuBarIfNeeded` in `.live` mode, calls `applyScreenShareVisibility`
- `.onOpenURL`: restores activation policy when app is in background, routes deep links — `.openNotes` sets `selectedSessionID` instead of opening the removed notes window

Updated `OpenOatsApp.swift`:
- Window title: "OpenOats" -> "Papyrus"
- Window content: `ContentView` -> `MainAppView`
- Window style: `.hiddenTitleBar` -> `.titleBar`
- Window resizability: `.contentSize` -> `.contentMinSize`
- Default size: 320x560 -> 900x600
- Deleted `Window("Notes", id: "notes")` scene and `.defaultSize` modifier
- Deleted `openNotesWindow()` helper
- "Past Meetings" menu button now calls `showMainWindow()` (kept Cmd+Shift+M shortcut)
- `showMainWindow()` extension preserved — menu bar callback still uses it

### Task 2: User-facing string rename to Papyrus

- `MenuBarController.swift`: accessibility description "OpenOats" -> "Papyrus" in both `init` and `updateIcon()`
- `MenuBarPopoverView.swift`: "Show OpenOats" -> "Open Papyrus", "Quit OpenOats" -> "Quit Papyrus"
- `OpenOatsApp.swift`: background notification title "OpenOats is still running" -> "Papyrus is still running"
- All internal identifiers (class names, module, filenames) left unchanged per plan instructions

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| `@State` for `columnVisibility` instead of `@SceneStorage` | `NavigationSplitViewVisibility` does not conform to `RawRepresentable`; `@SceneStorage` requires this conformance — build error confirmed at compile time |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] @SceneStorage incompatible with NavigationSplitViewVisibility**
- **Found during:** Task 1
- **Issue:** Plan specified `@SceneStorage("sidebarColumnVisibility") private var columnVisibility = NavigationSplitViewVisibility.all`. Swift compiler error: `NavigationSplitViewVisibility` does not conform to `RawRepresentable`, which is required by `@SceneStorage`.
- **Fix:** Changed to `@State private var columnVisibility = NavigationSplitViewVisibility.all`. State-based persistence is sufficient for Phase 2 scaffold; persistence across launches can be added in a later plan via a custom encoding approach if needed.
- **Files modified:** `OpenOats/Sources/OpenOats/Views/MainAppView.swift`
- **Commit:** 160be74

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | 160be74 | feat(02-01): create MainAppView and update Window scene to Papyrus |
| 2 | 1b0dcf3 | feat(02-01): rename user-facing strings from OpenOats to Papyrus |

## Verification Results

All 7 plan verification checks passed:
1. `swift build` — Build complete, zero errors
2. No `Window("Notes")` in sources
3. No `openNotesWindow` in sources
4. No `"OpenOats"` string in MenuBarController
5. No "Show OpenOats"/"Quit OpenOats" in MenuBarPopoverView
6. `Window("Papyrus")` present in OpenOatsApp.swift
7. `NavigationSplitView` count in MainAppView >= 1 (found: 2)

## Self-Check: PASSED
