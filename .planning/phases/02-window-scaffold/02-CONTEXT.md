# Phase 2: Window Scaffold - Context

**Gathered:** 2026-03-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Replace the current two-window setup (Window("main") with ContentView + Window("notes") with NotesView) with a single NavigationSplitView main window. Sidebar shows date-grouped meeting list. Detail pane shows placeholder/empty states for now (transcript display comes in Phase 3, live view in Phase 4). Rename the app to "Papyrus".

</domain>

<decisions>
## Implementation Decisions

### App Naming
- Rename from "OpenOats" to **Papyrus**
- Window title: "Papyrus"
- Menu bar tooltip: "Papyrus"
- Update all user-facing strings (About, window title, menu bar)
- Internal package/module names can stay as OpenOats for now (cosmetic rename, not structural)

### Sidebar Content
- **Title format:** App name + timestamp + participants (participants empty for now, populated by calendar in v2)
  - Example: "Zoom — Mar 21, 2:00 PM" or "Solo (room) — Mar 21, 3:30 PM"
- **Row density:** Medium — title + date + duration + meeting type badge
- **Type badge:** Small icon + text label (video icon for Zoom, mic icon for solo, etc.)
- **Date grouping:** Sections — Today / Yesterday / Last 7 days / Earlier (Apple Notes pattern)

### Window Behavior
- **Launch:** Menu bar only — app starts as menu bar icon, no window opens
- **Open main window:** Click "Open Papyrus" in menu bar popover, or click menu bar icon
- **Close (Cmd+W):** Hides window, app stays in menu bar — standard menu bar app behavior
- **Activation policy:** Flip between .accessory (no dock icon, menu bar only) and .regular (dock icon visible) when showing/hiding window
- **Window size:** Default ~900×600, remember position across launches

### Empty States
- **No meetings (first launch):** Friendly centered onboarding — illustration/icon + "Start your first meeting" + Start button in the detail pane
- **No selection (meetings exist):** Standard macOS ContentUnavailableView — icon + "Select a Meeting" message
- **Sidebar empty during first launch:** Show the onboarding in detail pane, sidebar can show "No meetings yet"

### Claude's Discretion
- Exact NavigationSplitView column widths and resize behavior
- Icon choices for meeting type badges (SF Symbols)
- Sidebar row height and spacing
- Animation for window show/hide transitions
- Whether to use @SceneStorage for sidebar column visibility persistence

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Existing window management
- `OpenOats/Sources/OpenOats/App/OpenOatsApp.swift` — Current Window("main") + Window("notes") scenes, showMainWindow(), activation policy logic
- `OpenOats/Sources/OpenOats/Views/NotesView.swift` — Existing sidebar + detail layout (HStack), session history, session selection logic — reference for what to migrate
- `OpenOats/Sources/OpenOats/Views/ContentView.swift` — Current main window content, recording controls — will be replaced but study the patterns
- `OpenOats/Sources/OpenOats/App/MenuBarController.swift` — Menu bar icon, popover management, showMainWindow callback

### Architecture research (MUST read)
- `.planning/research/ARCHITECTURE.md` — Full component map, NavigationSplitView patterns, DetailRouter design, MeetingListItem enum, data flow diagrams, build order, anti-patterns to avoid

### Pitfalls research
- `.planning/research/PITFALLS.md` — Window singleton (not WindowGroup), activation policy flip gotchas, NavigationSplitView selection binding

### Session data (sidebar population)
- `OpenOats/Sources/OpenOats/App/AppCoordinator.swift` — sessionHistory, isRecording, lastEndedSession — the data source for sidebar
- `OpenOats/Sources/OpenOats/Storage/SessionStore.swift` — Session persistence, loadHistory()

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `NotesView.swift`: Has a working sidebar with session list, selection binding, rename/delete context menus — migrate patterns to new NavigationSplitView
- `AppCoordinator.sessionHistory`: Already provides `[SessionIndex]` sorted by date — direct data source for sidebar
- `AppCoordinator.lastEndedSession`: Auto-selects most recent session — reuse for auto-navigation
- `MenuBarController`: Already has `onShowMainWindow` callback — wire to new window
- `AppDelegate.windowShouldClose` + `showMainWindow()`: Existing activation policy flip — reuse as-is

### Established Patterns
- `@Environment(AppCoordinator.self)` for coordinator access in views
- `@Bindable var settings: AppSettings` for settings access
- Actor isolation for persistence (SessionStore)
- `coordinator.loadHistory()` called in `.task {}` modifier

### Integration Points
- `OpenOatsApp.body`: Replace `Window("main")` content with MainAppView; remove `Window("notes")` scene
- `MenuBarController.onShowMainWindow`: Wire to show the new main window
- `AppDelegate`: Update windowShouldClose to target new window
- `AppCoordinator.sessionHistory`: Direct binding for sidebar list

</code_context>

<specifics>
## Specific Ideas

- Granola's sidebar as the reference — clean, date-grouped, medium density
- Apple Notes as the reference for NavigationSplitView behavior on macOS
- App name is "Papyrus" — update all user-facing strings

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 02-window-scaffold*
*Context gathered: 2026-03-21*
