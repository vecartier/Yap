# Phase 2: Window Scaffold - Research

**Researched:** 2026-03-21
**Domain:** macOS SwiftUI NavigationSplitView, window lifecycle, activation policy, app rename
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- Rename app from "OpenOats" to **Papyrus** (window title, menu bar tooltip, About, all user-facing strings; internal package names stay OpenOats)
- Replace the two-window setup (Window("main") + Window("notes")) with a single NavigationSplitView main window
- Sidebar title format: app name + timestamp — "Zoom — Mar 21, 2:00 PM" or "Solo (room) — Mar 21, 3:30 PM"
- Sidebar row density: medium — title + date + duration + meeting type badge
- Type badge: small icon + text label (video icon for Zoom, mic icon for solo)
- Date grouping: Today / Yesterday / Last 7 days / Earlier (Apple Notes pattern)
- Launch behavior: menu bar only — app starts as menu bar icon, no window opens on launch
- Open main window: "Open Papyrus" button in menu bar popover, or click menu bar icon
- Cmd+W: hides window, app stays in menu bar
- Activation policy: flip between .accessory and .regular when showing/hiding window
- Window default size: ~900x600, remember position across launches
- Empty state (no meetings / first launch): friendly centered onboarding in detail pane — icon + "Start your first meeting" + Start button
- Empty state (meetings exist, no selection): ContentUnavailableView — icon + "Select a Meeting"

### Claude's Discretion

- Exact NavigationSplitView column widths and resize behavior
- Icon choices for meeting type badges (SF Symbols)
- Sidebar row height and spacing
- Animation for window show/hide transitions
- Whether to use @SceneStorage for sidebar column visibility persistence

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| WIN-01 | App has a main window with NavigationSplitView (sidebar + detail layout) | MainAppView pattern, ARCHITECTURE.md Pattern 1 |
| WIN-02 | Sidebar shows chronological meeting list with date, title, duration, meeting type | SessionIndex model has all fields; NotesView.swift sidebar is migration baseline |
| WIN-03 | Sidebar groups meetings by date sections (Today / Yesterday / Last 7 days / Earlier) | Pure Swift date grouping computed property; no library needed |
| WIN-05 | Detail pane shows meeting metadata (date, time, duration, type) | SessionIndex.startedAt, endedAt, meetingApp fields supply all values |
| WIN-06 | Main window uses singleton Window scene (not WindowGroup) | Already using Window("main", id: "main") in OpenOatsApp.swift — preserve this |
| WIN-07 | Activation policy flips between .accessory and .regular when showing/hiding main window | showMainWindow() + windowShouldClose() already implement this; reuse exactly |
</phase_requirements>

---

## Summary

Phase 2 replaces the current two-window layout (a compact floating `ContentView` at 320x560 + a separate `NotesView` window) with a single Granola-style `NavigationSplitView` main window at 900x600. The codebase already has most of the raw materials: `AppCoordinator.sessionHistory` supplies the sidebar data, `NotesView.swift` has a working sidebar with selection binding and context menus, and `AppDelegate`/`showMainWindow()` already implement the activation policy flip correctly. Phase 2 is primarily a migration and composition task, not a ground-up build.

The architecture research (`ARCHITECTURE.md`) is comprehensive and directly applicable. Research for Phase 2 therefore focuses on three gaps that ARCHITECTURE.md does not cover: (1) exact codebase integration points that must change, (2) what is safe to reuse verbatim vs. what must be rewritten, and (3) the sidebar data model gap — `SessionIndex` does not currently store a computed display title in "Zoom — Mar 21, 2:00 PM" format, so that label must be assembled in the view.

The most important discovery from reading the existing code: `ContentView.swift` is larger and more complex than Phase 2 needs. It owns onboarding, consent, meeting detection setup, audio level polling, and the utterance-to-storage pipeline — none of which belong in Phase 2's new `MainAppView`. These must be migrated to the correct future homes (LiveDetailView in Phase 4, AppRuntime in Phase 1 infrastructure) without being lost.

**Primary recommendation:** Build `MainAppView` + `MeetingSidebarView` first with the existing `coordinator.sessionHistory` as the data source, wire the window lifecycle, then add the placeholder `DetailRouter` that shows `ContentUnavailableView`. Defer the live recording flow (`LiveDetailView`) to Phase 4.

---

## Standard Stack

### Core (all already in the project — no new dependencies)

| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| SwiftUI `NavigationSplitView` | macOS 13+ | Two-column sidebar+detail layout | Native Apple API; Granola/Notes use this pattern |
| SwiftUI `Window` scene | macOS 13+ | Singleton main window | Already used in OpenOatsApp.swift (WIN-06 satisfied) |
| `@Observable` / `AppCoordinator` | Swift 5.9+ | State coordination | Existing project pattern; `@Environment(AppCoordinator.self)` |
| `NSApp.setActivationPolicy` | AppKit | Menu-bar-to-regular flip | Already implemented in `showMainWindow()` + `windowShouldClose()` |
| `ContentUnavailableView` | macOS 14+ | Empty/no-selection state | Apple-native; used in existing `NotesView.swift` |
| `@SceneStorage` | macOS 12+ | Persist sidebar visibility across launches | Idiomatic SwiftUI alternative to AppStorage for per-scene state |

**Installation:** No new packages required. All needed APIs are in the OS and existing codebase.

---

## Architecture Patterns

The full patterns are documented in `.planning/research/ARCHITECTURE.md`. This section captures the codebase-specific application of those patterns.

### Pattern 1: MainAppView as NavigationSplitView Root

Replace `Window("main")` content from `ContentView(settings:)` to `MainAppView(settings:)`. The `Window` scene itself (id: "main", `.windowStyle(.hiddenTitleBar)`, `.defaultSize`) must be updated: change title to "Papyrus", update `.defaultSize` from 320x560 to 900x600, and change `.windowStyle` from `.hiddenTitleBar` to `.titleBar`.

**Critical wiring that must be preserved:**
- `.onAppear` block in the current `Window("main")` scene sets up `appDelegate.coordinator`, `appDelegate.settings`, `appDelegate.defaults`, `appDelegate.runtime`, calls `setupMenuBarIfNeeded(...)`, and calls `settings.applyScreenShareVisibility()`. All of this must move into `MainAppView.onAppear` or an equivalent `.task {}`.
- `.onOpenURL` handler in the same scene handles deep links including `.openNotes(sessionID:)`. This must be preserved in `MainAppView`.
- The `Window("notes")` scene must be **deleted** entirely. The `openNotesWindow()` helper and `openWindow(id: "notes")` calls throughout `ContentView.swift` must be removed.

### Pattern 2: Sidebar Data Source — SessionIndex

`coordinator.sessionHistory` is `[SessionIndex]`, loaded via `coordinator.loadHistory()`. The `SessionIndex` struct has:

```swift
struct SessionIndex: Identifiable, Codable, Sendable {
    let id: String          // e.g. "session_2026-03-21_14-30-00"
    let startedAt: Date
    var endedAt: Date?
    var templateSnapshot: TemplateSnapshot?  // has .name, .icon
    var title: String?       // may be nil — often nil for manual sessions
    var utteranceCount: Int
    var hasNotes: Bool
    var meetingApp: String?  // "Zoom", "Microsoft Teams", nil for solo
    var engine: String?
}
```

**Display title assembly (in the view, not in the model):**
```swift
// MeetingSidebarView.swift — row title helper
func displayTitle(for session: SessionIndex) -> String {
    let timeString = timeFormatter.string(from: session.startedAt)
    if let app = session.meetingApp {
        return "\(app) — \(timeString)"
    } else if let template = session.templateSnapshot {
        return "\(template.name) — \(timeString)"
    }
    return "Meeting — \(timeString)"
}
```

**Duration:** `session.endedAt.map { $0.timeIntervalSince(session.startedAt) }` — format with `DateComponentsFormatter`.

**Meeting type badge SF Symbols:**
- `meetingApp == "Zoom"` or contains "Zoom": `"video.fill"`
- `meetingApp == nil` + template name contains "solo" / "memo" / "room": `"mic.fill"`
- Default fallback: `"waveform"`

(These are Claude's Discretion — planner can adjust.)

### Pattern 3: Date Grouping for Sidebar Sections

No library needed. A computed property on the list of sessions:

```swift
enum DateSection: String, CaseIterable {
    case today = "Today"
    case yesterday = "Yesterday"
    case lastWeek = "Last 7 Days"
    case earlier = "Earlier"
}

func section(for session: SessionIndex) -> DateSection {
    let cal = Calendar.current
    if cal.isDateInToday(session.startedAt) { return .today }
    if cal.isDateInYesterday(session.startedAt) { return .yesterday }
    if let sevenDaysAgo = cal.date(byAdding: .day, value: -7, to: Date()),
       session.startedAt >= sevenDaysAgo { return .lastWeek }
    return .earlier
}
```

Group with `Dictionary(grouping:)` then render as `Section` inside the `List`. Only show non-empty sections.

### Pattern 4: Activation Policy Flip (Reuse Verbatim)

`showMainWindow()` in `OpenOatsRootApp` already does this correctly:
```swift
private func showMainWindow() {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == Self.mainWindowID }) {
        window.makeKeyAndOrderFront(nil)
    } else {
        openWindow(id: Self.mainWindowID)
    }
}
```

`AppDelegate.windowShouldClose` already does the reverse:
```swift
sender.orderOut(nil)
NSApp.setActivationPolicy(.accessory)
return false
```

Both implementations are correct. **Reuse without modification.** The only change needed: update the background mode hint notification text from "OpenOats is still running" to "Papyrus is still running".

### Pattern 5: App Rename Scope

All user-facing strings to update:
- `OpenOatsApp.swift`: `Window("OpenOats", id: "main")` → `Window("Papyrus", id: "main")`
- `MenuBarPopoverView.swift`: "Show OpenOats" → "Show Papyrus", "Quit OpenOats" → "Quit Papyrus"
- `MenuBarController.swift`: `accessibilityDescription: "OpenOats"` → `"Papyrus"` (two occurrences in `updateIcon()` and the `init`)
- `AppDelegate.showBackgroundModeHintIfNeeded()`: notification body text
- Info.plist `CFBundleDisplayName` and `CFBundleName` (if not already "Papyrus")
- `README.md` headings — skip unless user requests docs update

Internal: Package name `OpenOats`, module name `OpenOatsKit`, class `OpenOatsRootApp`, `AppDelegate` references to `OpenOatsRootApp.mainWindowID` — leave as-is (locked decision: cosmetic rename only).

### Recommended File Changes

| File | Action | Notes |
|------|--------|-------|
| `OpenOatsApp.swift` | MODIFY | Replace Window("main") content, delete Window("notes"), update Papyrus strings |
| `MainAppView.swift` | CREATE | NavigationSplitView root |
| `MeetingSidebarView.swift` | CREATE | Date-grouped session list |
| `DetailRouter.swift` | CREATE | Placeholder only in Phase 2 — shows ContentUnavailableView |
| `MenuBarPopoverView.swift` | MODIFY | Update "Show OpenOats" / "Quit OpenOats" strings |
| `MenuBarController.swift` | MODIFY | Update accessibilityDescription strings |
| `AppDelegate` (in OpenOatsApp.swift) | MODIFY | Update notification body string |
| `ContentView.swift` | KEEP (for now) | Phase 2 scope: new MainAppView is the main Window content; ContentView.swift is deleted in Phase 4 (MENU-03) |
| `NotesView.swift` | KEEP (for now) | Phase 2 does not yet delete it — deleted in Phase 4 (MENU-03) |

**Important:** `ContentView.swift` and `NotesView.swift` are **not** deleted in Phase 2. The requirements mapping confirms both are removed in Phase 4 (MENU-03). Attempting to delete them now would require porting the live recording pipeline, onboarding logic, and notes generation — all Phase 4 work.

### Anti-Patterns to Avoid

- **Do not embed `ContentView` logic in `MainAppView`:** `ContentView` owns meeting detection setup, audio polling, onboarding — these are Phase 4 concerns.
- **Do not use `WindowGroup`:** The existing `Window` scene is correct. Don't change the scene type.
- **Do not call `openWindow(id: "notes")`:** Remove all such calls when removing the Notes window scene. Deep-link `.openNotes(sessionID:)` must be re-routed to set `selectedSessionID` on `MainAppView` instead.
- **Do not bind sidebar `List` without `selection:`:** The `selection:` parameter on `List` is required for macOS highlight behavior (Pitfall 3 in PITFALLS.md).
- **Do not use `.navigationSplitViewStyle(.prominentDetail)`:** Silent no-op on macOS (Pitfall 7 in PITFALLS.md). Use `columnVisibility = .detailOnly` instead.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Date section grouping | Custom date comparison tree | `Calendar.isDateInToday` + `isDateInYesterday` + `date(byAdding:)` | Standard library covers all edge cases including DST boundaries |
| Duration formatting | Manual minutes/seconds math | `DateComponentsFormatter` with `.abbreviated` units style | Handles localization, 0-seconds edge case |
| Sidebar persistence across launches | Manual `UserDefaults` writes for selection | `@AppStorage("selectedMeetingID")` on `MainAppView` | One line vs. 15 lines; automatic; tested |
| Sidebar column visibility persistence | `UserDefaults` writes | `@SceneStorage("sidebarColumnVisibility")` | SwiftUI-native per-window persistence |
| SF Symbol meeting type icon logic | Complex switch over meetingApp string | Simple computed var with String.contains checks | Sufficient for Phase 2; can be made data-driven in Phase 4 |

---

## Common Pitfalls

### Pitfall 1: ContentView Lifecycle Logic Lost During Migration

**What goes wrong:** `MainAppView` replaces `ContentView` as the window root. The `Window("main").onAppear` block in the current `OpenOatsApp.swift` sets up `appDelegate.coordinator`, `appDelegate.settings`, calls `setupMenuBarIfNeeded(...)`, and calls `settings.applyScreenShareVisibility()`. If `MainAppView` doesn't carry these forward, the menu bar never appears and the app launches broken.

**How to avoid:** Copy the entire `.onAppear` block from the current `Window("main")` scene into `MainAppView.onAppear` (or a `.task {}` modifier). Verify in build that `setupMenuBarIfNeeded` is still called.

**Warning signs:** Menu bar icon doesn't appear on launch; app has no menu bar presence.

### Pitfall 2: Deep Link Handler for `.openNotes` Breaks

**What goes wrong:** The `.onOpenURL` handler in the current `Window("main")` scene handles `.openNotes(sessionID:)` by calling `coordinator.queueSessionSelection(sessionID)` then `openNotesWindow()`. When `Window("notes")` is deleted, `openNotesWindow()` fails silently.

**How to avoid:** In `MainAppView`, handle the `.openNotes` deep link by setting `selectedSessionID` directly instead of opening the notes window. `coordinator.consumeRequestedSessionSelection()` already provides the session ID.

**Warning signs:** `openoats://notes?sessionID=...` deep links open the app but don't navigate to the session.

### Pitfall 3: Sidebar Selection Binding Wired Incorrectly

**What goes wrong:** Using `NavigationLink` inside the `List` instead of the `selection:` binding on the `List` itself produces a list that navigates the detail but shows no highlighted row.

**How to avoid:** Use `List(coordinator.sessionHistory, selection: $selectedSessionID)` with `session.id` as the selection type. The `tag:` modifier on each row is not needed when using `Identifiable` items with `List(_, selection:)`.

**Confirmed pattern from `NotesView.swift`:**
```swift
List(coordinator.sessionHistory, selection: $selectedSessionID) { session in
    // row content
}
.listStyle(.sidebar)
```
This is the exact pattern to migrate into `MeetingSidebarView`.

### Pitfall 4: Window Size and Style Not Updated

**What goes wrong:** Changing the `Window` content to `MainAppView` but leaving `.defaultSize(width: 320, height: 560)` and `.windowStyle(.hiddenTitleBar)` produces a tiny borderless window that looks wrong for the new layout.

**How to avoid:** Update to `.defaultSize(width: 900, height: 600)` and `.windowStyle(.titleBar)`. Also change `.windowResizability` from `.contentSize` to `.contentMinSize` to allow free resizing.

**Warning signs:** Window opens as a tiny floating panel instead of a full document-style window.

### Pitfall 5: `SessionIndex.title` Is Often Nil

**What goes wrong:** `session.title` is populated by `transcriptStore.conversationState.currentTopic` — which is empty for most sessions (it was populated by the now-removed knowledge base feature). Showing it as the primary title produces "Untitled" for most rows.

**How to avoid:** The locked decision specifies "app name + timestamp" as the display title format: `"Zoom — Mar 21, 2:00 PM"`. Build `displayTitle(for:)` from `session.meetingApp` + `session.startedAt` as the primary label. The `session.title` field can be shown as a secondary subtitle if non-nil (future rename feature).

### Pitfall 6: UI Tests Reference `app.pastMeetingsButton` and `notes.*` Identifiers

**What goes wrong:** `SmokeTests.swift` asserts on `app.pastMeetingsButton` (defined in `ContentView.swift`) and `notes.*` identifiers (defined in `NotesView.swift`). Phase 2 changes the window structure — if these identifiers disappear before the UI tests are updated, CI breaks.

**How to avoid:** Phase 2 does not delete `ContentView.swift` or `NotesView.swift`. The existing UI tests remain valid. New identifiers added to `MainAppView` and `MeetingSidebarView` should use a `papyrus.*` or `main.*` namespace to avoid conflicts. Update `SmokeTests.swift` for the new identifiers in Phase 4 when the old files are removed.

---

## Code Examples

### Window Scene Update (OpenOatsApp.swift)

```swift
// BEFORE
Window("OpenOats", id: "main") {
    ContentView(settings: settings)
        .environment(runtime)
        .environment(coordinator)
        .defaultAppStorage(defaults)
        .onAppear { /* setup */ }
        .onOpenURL { url in /* deep links */ }
}
.windowStyle(.hiddenTitleBar)
.windowResizability(.contentSize)
.defaultSize(width: 320, height: 560)

// AFTER
Window("Papyrus", id: "main") {
    MainAppView(settings: settings)
        .environment(runtime)
        .environment(coordinator)
        .defaultAppStorage(defaults)
        // onAppear and onOpenURL move into MainAppView
}
.windowStyle(.titleBar)
.windowResizability(.contentMinSize)
.defaultSize(width: 900, height: 600)
```

### MeetingSidebarView Selection Binding

```swift
// MeetingSidebarView.swift
struct MeetingSidebarView: View {
    @Binding var selectedSessionID: String?
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        List(coordinator.sessionHistory, selection: $selectedSessionID) { session in
            MeetingRowView(session: session)
                .tag(session.id)
        }
        .listStyle(.sidebar)
        .task {
            await coordinator.loadHistory()
        }
    }
}
```

### Date Section Grouping

```swift
// MeetingSidebarView.swift — sectioned variant
var groupedSessions: [(label: String, sessions: [SessionIndex])] {
    let cal = Calendar.current
    let groups: [(String, (SessionIndex) -> Bool)] = [
        ("Today",       { cal.isDateInToday($0.startedAt) }),
        ("Yesterday",   { cal.isDateInYesterday($0.startedAt) }),
        ("Last 7 Days", {
            guard let cutoff = cal.date(byAdding: .day, value: -7, to: Date()) else { return false }
            return $0.startedAt >= cutoff && !cal.isDateInToday($0.startedAt) && !cal.isDateInYesterday($0.startedAt)
        }),
        ("Earlier",     { _ in true })
    ]
    var remaining = coordinator.sessionHistory
    var result: [(String, [SessionIndex])] = []
    for (label, predicate) in groups {
        let matched = remaining.filter(predicate)
        remaining.removeAll(where: predicate)
        if !matched.isEmpty { result.append((label, matched)) }
    }
    return result
}
```

### DetailRouter — Phase 2 Placeholder

```swift
// DetailRouter.swift — Phase 2 version (no live view yet)
struct DetailRouter: View {
    @Binding var selectedSessionID: String?

    var body: some View {
        if let _ = selectedSessionID {
            // Phase 3 will replace this with PastMeetingDetailView
            ContentUnavailableView(
                "Meeting Selected",
                systemImage: "doc.text",
                description: Text("Transcript view coming in the next phase.")
            )
        } else {
            ContentUnavailableView(
                "Select a Meeting",
                systemImage: "waveform",
                description: Text("Choose a meeting from the sidebar.")
            )
        }
    }
}
```

### MenuBarPopoverView String Updates

```swift
// BEFORE
Button(action: onShowMainWindow) {
    Text("Show OpenOats")
}
Button(action: onQuit) {
    Text("Quit OpenOats")
}

// AFTER
Button(action: onShowMainWindow) {
    Text("Open Papyrus")
}
Button(action: onQuit) {
    Text("Quit Papyrus")
}
```

---

## Integration Map: What Changes in Phase 2

| File | Change Type | What Changes |
|------|-------------|--------------|
| `OpenOatsApp.swift` | MODIFY | Window title "Papyrus"; defaultSize 900x600; titleBar style; host MainAppView; remove Window("notes") scene; remove openNotesWindow() helper |
| `MainAppView.swift` | CREATE | NavigationSplitView; owns selectedSessionID @State; carries forward onAppear/onOpenURL logic from ContentView |
| `MeetingSidebarView.swift` | CREATE | Date-grouped List with selection binding; loads history on .task; MeetingRowView with type badge |
| `DetailRouter.swift` | CREATE | Phase 2 placeholder — ContentUnavailableView for both states |
| `MenuBarPopoverView.swift` | MODIFY | "Show OpenOats" → "Open Papyrus"; "Quit OpenOats" → "Quit Papyrus" |
| `MenuBarController.swift` | MODIFY | accessibilityDescription "OpenOats" → "Papyrus" (2 occurrences) |
| `AppDelegate` (inside OpenOatsApp.swift) | MODIFY | Notification body "OpenOats is still running" → "Papyrus is still running" |
| `ContentView.swift` | NO CHANGE | Stays until Phase 4; do not modify or delete |
| `NotesView.swift` | NO CHANGE | Stays until Phase 4; do not modify or delete |
| `AppCoordinator.swift` | NO CHANGE | No new state needed |
| `SessionIndex` (Models.swift) | NO CHANGE | All needed fields already exist |

---

## State of the Art

| Old Approach | Current Approach | Notes |
|--------------|------------------|-------|
| Separate "notes" window for history | NavigationSplitView unified sidebar+detail | This migration is Phase 2's core work |
| `NSApp.activate(ignoringOtherApps: true)` | Same — still valid in macOS 15; the non-deprecated overload `NSApp.activate()` is available macOS 14+ but ignoringOtherApps is not formally deprecated | Keep existing call; monitor deprecation |
| `NotesView` HStack manually managing sidebar width | `NavigationSplitView` with system-managed column widths | System handles resize, sidebar collapse, keyboard shortcut |

---

## Open Questions

1. **Where does meeting detection setup live after ContentView is removed (Phase 4)?**
   - What we know: `ContentView.task` calls `coordinator.setupMeetingDetection(settings:)` and `coordinator.evaluateImmediate()`. Phase 2 does not remove ContentView, so this is not a Phase 2 problem.
   - What's unclear: Phase 4 will need to find a new home for this (likely `AppRuntime` or `AppDelegate`).
   - Recommendation: Note in Phase 4 planning. Not a Phase 2 concern.

2. **Should `selectedSessionID` be persisted via `@AppStorage`?**
   - What we know: PITFALLS.md UX pitfall: "Sidebar selection resets to nil when window regains focus." `@AppStorage` persists across launches.
   - What's unclear: Whether remembering the last selection across cold launches is desired UX. The existing `NotesView` uses plain `@State` (does not persist).
   - Recommendation: Use `@AppStorage("selectedMeetingID")` for Phase 2 to match the "remember position" spirit of the locked decision for window position.

3. **Info.plist bundle display name update**
   - What we know: The rename to Papyrus should update user-visible app name.
   - What's unclear: Whether Info.plist is in the Swift Package's resources or in an Xcode project file.
   - Recommendation: Planner should include a task to locate and update `CFBundleDisplayName`; if not found, note it for the implementer.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (Swift Package unit tests + XCUITest UI tests) |
| Config file | `OpenOats/Package.swift` (test target: `OpenOatsTests`); `UITests/OpenOatsUITestHost.xcodeproj` (UI tests) |
| Quick run command | `swift test --filter OpenOatsTests 2>/dev/null` (from `OpenOats/` directory) |
| Full suite command | `swift test 2>/dev/null` (from `OpenOats/` directory) |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | Notes |
|--------|----------|-----------|-------------------|-------|
| WIN-01 | NavigationSplitView renders sidebar and detail columns | Manual smoke | Launch app, verify two-column layout | UI structure not unit-testable without simulator |
| WIN-02 | Sidebar shows date, title, duration, meeting type per row | Manual visual | Launch app with seeded sessions, inspect rows | Row rendering is visual |
| WIN-03 | Date section grouping (Today/Yesterday/Last 7 Days/Earlier) | Unit | `swift test --filter SidebarDateGroupingTests` | NEW test file needed — Wave 0 gap |
| WIN-05 | Detail pane shows meeting metadata | Manual visual | Click a meeting row, inspect placeholder | Phase 2 detail is a placeholder |
| WIN-06 | Single window — second "Open Papyrus" click brings existing window, not new one | Manual smoke | Click menu bar icon twice; count NSApp.windows | Not automatable without UI test harness changes |
| WIN-07 | Activation policy flips .accessory/.regular | Manual smoke | Verify dock icon appears/disappears with window | Requires running app |

### Sampling Rate

- **Per task commit:** `swift test --filter OpenOatsTests` (unit tests only, ~10s)
- **Per wave merge:** `swift test` (full unit suite)
- **Phase gate:** Unit suite green + manual smoke of WIN-01, WIN-06, WIN-07 before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `OpenOats/Tests/OpenOatsTests/SidebarDateGroupingTests.swift` — covers WIN-03 (date section grouping logic). The grouping function will live in `MeetingSidebarView.swift` as a computed property or a standalone helper; it can be tested by moving it to a testable helper type.

---

## Sources

### Primary (HIGH confidence — codebase)

- `/Users/vcartier/Desktop/OpenOats-fork/OpenOats/Sources/OpenOats/App/OpenOatsApp.swift` — Existing Window scene, showMainWindow(), AppDelegate, activation policy
- `/Users/vcartier/Desktop/OpenOats-fork/OpenOats/Sources/OpenOats/Views/NotesView.swift` — Working sidebar with List(selection:), context menus, loadSelectedSession pattern
- `/Users/vcartier/Desktop/OpenOats-fork/OpenOats/Sources/OpenOats/App/AppCoordinator.swift` — sessionHistory, lastEndedSession, isRecording, loadHistory()
- `/Users/vcartier/Desktop/OpenOats-fork/OpenOats/Sources/OpenOats/Models/Models.swift` — SessionIndex fields (id, startedAt, endedAt, meetingApp, templateSnapshot, utteranceCount)
- `/Users/vcartier/Desktop/OpenOats-fork/OpenOats/Sources/OpenOats/App/MenuBarController.swift` — onShowMainWindow callback, icon observation pattern
- `/Users/vcartier/Desktop/OpenOats-fork/OpenOats/Sources/OpenOats/Views/MenuBarPopoverView.swift` — Existing "Show OpenOats" / "Quit OpenOats" strings
- `/Users/vcartier/Desktop/OpenOats-fork/UITests/OpenOatsUITests/SmokeTests.swift` — Existing UI test identifiers that must not break

### Primary (HIGH confidence — architecture docs)

- `.planning/research/ARCHITECTURE.md` — NavigationSplitView patterns, DetailRouter design, MeetingListItem enum, build order, anti-patterns
- `.planning/research/PITFALLS.md` — WindowGroup vs Window, activation policy sequence, NavigationSplitView selection binding, .prominentDetail macOS no-op

### Secondary (MEDIUM confidence — external)

- [Apple Developer: NavigationSplitView](https://developer.apple.com/documentation/swiftui/navigationsplitview) — selection binding, columnVisibility
- [Fine-Tuning macOS App Activation Behavior — Art Lasovsky](https://artlasovsky.com/fine-tuning-macos-app-activation-behavior) — activation policy sequence
- [Scenes Types in a SwiftUI Mac App — NilCoalescing](https://nilcoalescing.com/blog/ScenesTypesInASwiftUIMacApp/) — Window vs WindowGroup singleton behavior

---

## Metadata

**Confidence breakdown:**
- Integration map (what changes): HIGH — based on direct codebase reading
- Standard stack: HIGH — all APIs are in the existing project; no new dependencies
- Architecture patterns: HIGH — confirmed against ARCHITECTURE.md and existing code
- Pitfalls: HIGH — confirmed against PITFALLS.md and direct code inspection
- SessionIndex fields for sidebar: HIGH — read directly from Models.swift
- Activation policy reuse: HIGH — existing implementation is correct; confirmed against PITFALLS.md

**Research date:** 2026-03-21
**Valid until:** 2026-04-21 (stable macOS API; no fast-moving dependencies)
