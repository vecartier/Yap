# Roadmap: MeetingScribe

## Overview

Transforms OpenOats from a menu-bar recording utility into a full Granola-style macOS companion app. Phase 1 (solo mode + KB cleanup) is complete. Phases 2–6 build the main app window from the ground up: scaffold the NavigationSplitView layout, wire the past-meeting detail pane, connect live recording, strip the old menu bar UI, add the summary engine, and finish with full-text search and PDF export. When complete, every meeting ends with a transcript, a structured AI summary, and a ready-to-paste Slack message — browsable in one place.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Foundation** - Solo mode, KB removal, three-button menu bar (complete 2026-03-21)
- [x] **Phase 2: Window Scaffold** - NavigationSplitView main window with sidebar meeting list (complete 2026-03-21)
- [x] **Phase 3: Past Meeting Detail** - Unified detail pane with transcript, metadata, and Slack copy (completed 2026-03-21)
- [x] **Phase 4: Live Recording + Menu Bar Cleanup** - Live transcript in main window, stripped menu bar popover, legacy views deleted (completed 2026-03-22)
- [ ] **Phase 5: Summary Engine + Settings** - Auto-generated structured summaries, settings as sidebar tab
- [ ] **Phase 6: Search + Export** - Full-text sidebar search and multi-page PDF export

## Phase Details

### Phase 1: Foundation
**Goal**: Codebase is clean, solo mic-only recording works, and the three-button menu bar is in place
**Depends on**: Nothing (first phase)
**Requirements**: SOLO-01, SOLO-02, SOLO-03, SOLO-04, CLEAN-01, CLEAN-02, CLEAN-03
**Success Criteria** (what must be TRUE):
  1. User can start a mic-only recording session from the menu bar (memo and room flavors) without triggering system audio capture
  2. Solo mode transcript uses single-speaker labeling and is saved in the same format as call transcripts
  3. Knowledge base UI and code are entirely absent from the running app
  4. VoyageAI and Ollama embed client code is removed from the codebase
**Plans**: 2 plans

Plans:
- [x] 01-01: Remove knowledge base feature (CLEAN-01, CLEAN-02, CLEAN-03)
- [x] 01-02: Add solo mode with MeetingMode enum and three-button menu bar UI (SOLO-01, SOLO-02, SOLO-03, SOLO-04)

---

### Phase 2: Window Scaffold
**Goal**: Users can open a main app window and browse the full meeting history in a date-grouped sidebar
**Depends on**: Phase 1
**Requirements**: WIN-01, WIN-02, WIN-03, WIN-05, WIN-06, WIN-07
**Success Criteria** (what must be TRUE):
  1. User can open a single main window from the menu bar "Open MeetingScribe" link; opening it again does not spawn a second window
  2. Sidebar lists all past meetings in date sections (Today / Yesterday / Last 7 days / Earlier) with date, title, duration, and meeting type badge
  3. Clicking a meeting selects it with system highlight; the detail pane shows a placeholder state (wired in Phase 3)
  4. Main window gains focus correctly and does not appear behind other running apps
**Plans**: 2 plans

Plans:
- [x] 02-01-PLAN.md — App rename to Papyrus + MainAppView window scene (WIN-06, WIN-07)
- [x] 02-02-PLAN.md — MeetingSidebarView date grouping + DetailRouter placeholder (WIN-01, WIN-02, WIN-03, WIN-05)

---

### Phase 3: Past Meeting Detail
**Goal**: Users can read any completed meeting — metadata, full transcript, and a Slack-ready message — from the detail pane
**Depends on**: Phase 2
**Requirements**: WIN-04, SLCK-01, SLCK-02, SLCK-03
**Success Criteria** (what must be TRUE):
  1. Selecting a past meeting shows its date, time, duration, and type in a metadata header at the top of the detail pane
  2. Full transcript is visible below the (initially empty) summary section; detail pane does not crash when no summary file exists yet
  3. A Slack-formatted message with header and all summary sections is shown in the detail pane with a one-click copy-to-clipboard button
**Plans**: 2 plans

Plans:
- [ ] 03-01-PLAN.md — SlackFormatter utility + transcript timestamp logic (TDD) (SLCK-01, SLCK-02)
- [ ] 03-02-PLAN.md — PastMeetingDetailView + DetailRouter wiring + human verify (WIN-04, SLCK-03)

---

### Phase 4: Live Recording + Menu Bar Cleanup
**Goal**: Live transcript appears in the main window during recording, the menu bar popover is minimal, and the old UI files are gone
**Depends on**: Phase 3
**Requirements**: LIVE-01, LIVE-02, LIVE-03, LIVE-04, MENU-01, MENU-02, MENU-03
**Success Criteria** (what must be TRUE):
  1. Starting a recording pins a "Live Session" row at the top of the sidebar and shows the live transcript updating in the detail pane
  2. Stopping a recording automatically navigates the detail pane to the newly completed session
  3. Menu bar popover shows only recording status, start/stop buttons, and "Open MeetingScribe" — no transcript text
  4. ContentView.swift and NotesView.swift no longer exist in the project
**Plans**: 2 plans

Plans:
- [ ] 04-01-PLAN.md — LiveDetailView + MeetingListItem enum + DetailRouter live branch + MainAppView hooks (LIVE-01, LIVE-02, LIVE-03, LIVE-04)
- [ ] 04-02-PLAN.md — Menu bar popover 3-button idle state + legacy view deletion (MENU-01, MENU-02, MENU-03)

---

### Phase 5: Summary Engine + Settings
**Goal**: Every completed meeting automatically gains a structured AI summary visible in the detail pane, and settings are accessible as a sidebar tab
**Depends on**: Phase 4
**Requirements**: SUMM-01, SUMM-02, SUMM-03, SUMM-04, SUMM-05, SUMM-06, SUMM-07, SUMM-08, SUMM-09, SETT-01, SETT-02
**Success Criteria** (what must be TRUE):
  1. After a recording ends, the detail pane displays a structured summary with key decisions, action items, discussion points, and open questions — without any manual trigger
  2. Summary generation works with both OpenRouter (cloud) and Ollama (local) providers
  3. A Markdown summary file appears in ~/Documents/OpenOats/ alongside the transcript after each session
  4. Settings (LLM provider, transcription model, API keys, audio input device) are accessible from a sidebar tab in the main window
**Plans**: 2 plans

Plans:
- [ ] 05-01: SummaryEngine actor + two-phase LLM prompt + AppCoordinator hook (SUMM-01, SUMM-02, SUMM-03, SUMM-04, SUMM-05, SUMM-06, SUMM-07, SUMM-08, SUMM-09)
- [ ] 05-02: Settings sidebar tab (SETT-01, SETT-02)

---

### Phase 6: Search + Export
**Goal**: Users can find any past meeting by keyword and export any meeting to a paginated PDF
**Depends on**: Phase 5
**Requirements**: SRCH-01, SRCH-02, SRCH-03, EXPRT-01, EXPRT-02
**Success Criteria** (what must be TRUE):
  1. Typing in the search field filters the sidebar meeting list in real-time without any UI stutter or main-thread blocking
  2. Search matches text in both transcripts and summaries across all past meetings
  3. User can export a meeting to a properly paginated multi-page PDF (summary + transcript) via a save dialog
**Plans**: 2 plans

Plans:
- [ ] 06-01: Full-text search with background Task + 250ms debounce (SRCH-01, SRCH-02, SRCH-03)
- [ ] 06-02: PDF export via NSPrintOperation + NSSavePanel (EXPRT-01, EXPRT-02)

---

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 2/2 | Complete | 2026-03-21 |
| 2. Window Scaffold | 2/2 | Complete | 2026-03-21 |
| 3. Past Meeting Detail | 2/2 | Complete   | 2026-03-21 |
| 4. Live Recording + Menu Bar Cleanup | 2/2 | Complete   | 2026-03-22 |
| 5. Summary Engine + Settings | 1/2 | In Progress|  |
| 6. Search + Export | 0/2 | Not started | - |
