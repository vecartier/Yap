# Phase 4: Live Recording + Menu Bar Cleanup - Context

**Gathered:** 2026-03-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Port the live transcript view from ContentView into a new LiveDetailView in the main window. Add synthetic "Live Session" row in sidebar during recording. Strip menu bar popover to minimal controls. Delete ContentView.swift and NotesView.swift (legacy). Start buttons available in both menu bar and main window.

</domain>

<decisions>
## Implementation Decisions

### Live View Layout
- **Granola-style** — live transcript in detail pane, auto-scrolling as new utterances arrive
- Same labeled-lines format as PastMeetingDetailView for consistency
- **Recording controls at top of detail pane** — recording indicator (red dot), duration timer, Stop button in a header/toolbar area
- Partial/in-progress utterances shown in a distinct style (lighter text or italic)

### Recording Transition (Stop Flow)
- **Brief "Finalizing..." loading state** when recording stops — while transcript saves and session finalizes
- Then auto-swap to PastMeetingDetailView for the completed session
- Sidebar: live row disappears, completed session row appears and auto-selects
- **If main window is closed during recording: stay hidden** — no auto-open. User gets a notification from menu bar instead, opens when ready.

### Sidebar Live Row
- Synthetic "Live Session" row pinned at top of sidebar during recording
- Shows recording indicator (pulsing dot) + meeting type + duration timer
- Auto-selects on recording start
- When recording stops: row transitions to completed session entry

### Start Buttons
- **Both places** — three start buttons (Start Call / Solo memo / Solo room) in:
  - Menu bar popover (existing, keep as-is)
  - Main window (in the empty/onboarding state, or as toolbar actions)
- Starting from either location triggers the same AppCoordinator flow

### Menu Bar Popover (During Recording)
- **Status + Stop** — recording indicator (red dot + duration timer) + Stop button
- "Open Papyrus" link always visible
- No live transcript in popover (transcript is in main window only)

### Menu Bar Popover (Idle)
- Three start buttons: Start Call / Solo (memo) / Solo (room)
- "Open Papyrus" link
- Quit Papyrus

### Legacy File Deletion
- **Delete ContentView.swift** — live transcript logic migrates to LiveDetailView
- **Delete NotesView.swift** — session history/notes logic already migrated to MainAppView + PastMeetingDetailView
- Verify no remaining references after deletion

### Claude's Discretion
- LiveDetailView internal layout details (spacing, fonts, animation for new utterances)
- How partial utterances are styled (italic, lighter color, etc.)
- "Finalizing..." loading state design
- Start button placement in main window (toolbar vs onboarding empty state vs both)
- Whether to show audio level meter in the recording header

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Live transcript source (to migrate from)
- `OpenOats/Sources/OpenOats/Views/ContentView.swift` — Current live transcript implementation, recording controls, start/stop flow, onboarding logic. THIS FILE GETS DELETED after migration.
- `OpenOats/Sources/OpenOats/Views/NotesView.swift` — Session history, transcript loading. THIS FILE GETS DELETED.

### Target views (to wire into)
- `OpenOats/Sources/OpenOats/Views/DetailRouter.swift` — Needs `.live` case added for LiveDetailView routing
- `OpenOats/Sources/OpenOats/Views/MainAppView.swift` — Parent NavigationSplitView, owns selectedSessionID
- `OpenOats/Sources/OpenOats/Views/MeetingSidebarView.swift` — Needs MeetingListItem enum with .live case
- `OpenOats/Sources/OpenOats/Views/PastMeetingDetailView.swift` — Reference for consistent transcript styling

### Coordination
- `OpenOats/Sources/OpenOats/App/AppCoordinator.swift` — isRecording, transcriptStore, lastEndedSession, startSession/handle flows
- `OpenOats/Sources/OpenOats/Views/MenuBarPopoverView.swift` — Strip to minimal, keep start buttons + status

### Architecture research
- `.planning/research/ARCHITECTURE.md` — LiveDetailView spec, MeetingListItem enum, DetailRouter live routing, data flow diagrams

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ContentView` live transcript logic: `transcriptStore.utterances`, `volatileYouText`, `volatileThemText` — migrate to LiveDetailView
- `ContentView` recording controls: start/stop buttons, audio level display — migrate to LiveDetailView header
- `TranscriptView.swift` — existing transcript rendering, may be reusable
- `PastMeetingDetailView` transcript styling — reference for consistency
- `AppCoordinator.isRecording` — direct observable for sidebar live row + DetailRouter routing

### Established Patterns
- `@Environment(AppCoordinator.self)` for state access
- `.task {}` for async loading
- `coordinator.handle(.userStarted(metadata))` for starting sessions
- `coordinator.handle(.userStopped)` for stopping

### Integration Points
- `DetailRouter.swift` — add `.live` routing case (when `isRecording && selectedSessionID == "_live_"`)
- `MeetingSidebarView.swift` — add `MeetingListItem` enum, prepend `.live` row when recording
- `MainAppView.swift` — auto-select `"_live_"` when recording starts, auto-select completed session when stops
- `MenuBarPopoverView.swift` — strip live transcript section, keep start/stop/status
- `AppCoordinator` — no changes needed (already exposes all required state)

</code_context>

<specifics>
## Specific Ideas

- Granola-style live view — clean, minimal, auto-scrolling
- Consistent labeled-lines format between live and past views
- "Finalizing..." brief loading state on stop, not instant swap

</specifics>

<deferred>
## Deferred Ideas

- User shared a comprehensive PLANNING.md with expanded features (calendar integration via EventKit, templates system, Slack Bot Token, meeting series mapping, preview modal, week recap). These are v2 features — captured in PROJECT.md backlog. Current v1 focus: finish core app window + summary engine + search.

</deferred>

---

*Phase: 04-live-recording-menu-bar-cleanup*
*Context gathered: 2026-03-22*
