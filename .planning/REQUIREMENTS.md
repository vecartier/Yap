# Requirements: MeetingScribe

**Defined:** 2026-03-21
**Core Value:** Every meeting produces a clear, shareable record without manual note-taking

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Solo Mode (Phase 1 — Complete)

- [x] **SOLO-01**: User can start a mic-only recording session for in-person meetings via menu bar
- [x] **SOLO-02**: User can start a mic-only recording session for personal voice memos via menu bar
- [x] **SOLO-03**: Solo mode produces a timestamped transcript identical in format to call transcripts
- [x] **SOLO-04**: Solo mode uses single-speaker labeling (no "them" speaker)

### Cleanup (Phase 1 — Complete)

- [x] **CLEAN-01**: Knowledge base feature (KB indexing, embedding, real-time suggestions) is removed from codebase
- [x] **CLEAN-02**: KB-related UI elements are removed from settings and main views
- [x] **CLEAN-03**: Voyage AI and Ollama embed client dependencies are removed if only used by KB

### Summary

- [ ] **SUMM-01**: Structured summary is auto-generated when a session ends
- [ ] **SUMM-02**: Summary includes key decisions extracted from transcript
- [ ] **SUMM-03**: Summary includes action items with owner attribution where identifiable
- [ ] **SUMM-04**: Summary includes main discussion points
- [ ] **SUMM-05**: Summary includes open questions / unresolved items
- [ ] **SUMM-06**: Summary uses two-phase LLM prompt (grounding pass then formatting) to minimize hallucination
- [ ] **SUMM-07**: Summary generation hooks into AppCoordinator after awaitPendingWrites(), not from UI
- [ ] **SUMM-08**: Summary works with both OpenRouter (cloud) and Ollama (local) providers
- [ ] **SUMM-09**: Summary is saved as Markdown alongside the transcript in ~/Documents/OpenOats/

### Main App Window

- [ ] **WIN-01**: App has a main window with NavigationSplitView (sidebar + detail layout)
- [ ] **WIN-02**: Sidebar shows chronological meeting list with date, title, duration, meeting type
- [ ] **WIN-03**: Sidebar groups meetings by date sections (Today / Yesterday / Last 7 days / Earlier)
- [ ] **WIN-04**: Clicking a meeting shows Granola-style unified detail: summary at top, transcript below
- [ ] **WIN-05**: Detail pane shows meeting metadata (date, time, duration, type)
- [ ] **WIN-06**: Main window uses singleton `Window` scene (not `WindowGroup`)
- [ ] **WIN-07**: Activation policy flips between .accessory and .regular when showing/hiding main window

### Live Recording

- [ ] **LIVE-01**: During recording, live transcript appears in the main window detail pane (not menu bar)
- [ ] **LIVE-02**: Sidebar shows synthetic "Live Session" row pinned at top during recording
- [ ] **LIVE-03**: When recording stops, detail auto-navigates to the completed session
- [ ] **LIVE-04**: DetailRouter routes between live view and past meeting view based on state

### Menu Bar

- [ ] **MENU-01**: Menu bar popover shows only: recording status, start/stop buttons, "Open MeetingScribe" link
- [ ] **MENU-02**: Live transcript is removed from menu bar popover
- [ ] **MENU-03**: ContentView.swift and NotesView.swift are removed (logic migrated to main window)

### Slack Message

- [ ] **SLCK-01**: Summary is formatted as a Slack-ready message (Markdown with clear sections)
- [ ] **SLCK-02**: Slack message includes header, key decisions, action items, discussion points, open questions
- [ ] **SLCK-03**: Copy-to-clipboard button for Slack message in meeting detail pane

### Search

- [ ] **SRCH-01**: Full-text search across all past transcripts and summaries
- [ ] **SRCH-02**: Search runs on background thread with debounce (not blocking UI)
- [ ] **SRCH-03**: Search filters the sidebar meeting list in real-time

### Export

- [ ] **EXPRT-01**: User can export a meeting to PDF (summary + transcript)
- [ ] **EXPRT-02**: PDF uses NSPrintOperation for proper multi-page pagination (not ImageRenderer)

### Settings

- [ ] **SETT-01**: Settings accessible as a tab/section in the main window sidebar
- [ ] **SETT-02**: Settings include: LLM provider, transcription model, API keys, audio input device

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Calendar Integration

- **CAL-01**: Calendar integration (Google Calendar / Apple Calendar)
- **CAL-02**: 5-minute pre-meeting notification
- **CAL-03**: Auto-launch recording when calendar meeting starts
- **CAL-04**: Meeting title pulled from calendar event / Zoom window title
- **CAL-05**: Participant names from calendar used in summary attribution

### Slack Automation

- **SLCK2-01**: Slack webhook auto-send to configured channel
- **SLCK2-02**: Recurring meeting → auto-send to same Slack channel
- **SLCK2-03**: Webhook URLs stored in macOS Keychain

### Enhanced Features

- **ENH-01**: Zoom .vtt transcript import as cross-reference
- **ENH-02**: Inline transcript search (Cmd+F within transcript view)
- **ENH-03**: Meeting type context adjusts summary prompt

## Out of Scope

| Feature | Reason |
|---------|--------|
| Always-on listening | Privacy risk, battery drain |
| Speaker diarization with names | Unreliable without calendar context |
| Video recording | Storage nightmare, privacy issues |
| Collaborative editing | Personal tool |
| Mobile app | macOS only |
| Tags/folders for meetings | Search covers the use case |
| Inline AI chat | Structured summary is sufficient |
| iCloud sync | Time Machine is sufficient |
| SwiftData/Core Data | File-based storage works at personal scale |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| SOLO-01 | Phase 1 | Complete |
| SOLO-02 | Phase 1 | Complete |
| SOLO-03 | Phase 1 | Complete |
| SOLO-04 | Phase 1 | Complete |
| CLEAN-01 | Phase 1 | Complete |
| CLEAN-02 | Phase 1 | Complete |
| CLEAN-03 | Phase 1 | Complete |
| (remaining populated during roadmap creation) | | |

**Coverage:**
- v1 requirements: 38 total (7 complete, 31 active)
- Mapped to phases: 7
- Unmapped: 31 ⚠️

---
*Requirements defined: 2026-03-21*
*Last updated: 2026-03-21 after scope reframe*
