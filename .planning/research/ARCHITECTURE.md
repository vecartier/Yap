# Architecture Research

**Domain:** macOS main app window — sidebar + detail alongside existing menu bar app
**Researched:** 2026-03-21
**Confidence:** HIGH

## Standard Architecture

### System Overview

```
┌──────────────────────────────────────────────────────────────────┐
│                       Presentation Layer                          │
│                                                                    │
│  ┌──────────────────────┐   ┌──────────────────────────────────┐  │
│  │   Menu Bar Surface   │   │      Main App Window             │  │
│  │  ┌────────────────┐  │   │  ┌──────────┐  ┌─────────────┐  │  │
│  │  │MenuBarPopover  │  │   │  │ Sidebar  │  │ DetailPane  │  │  │
│  │  │ (minimal)      │  │   │  │  (list)  │  │(live/past)  │  │  │
│  │  └────────────────┘  │   │  └──────────┘  └─────────────┘  │  │
│  └──────────────────────┘   └──────────────────────────────────┘  │
├──────────────────────────────────────────────────────────────────┤
│                     Coordination Layer                             │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │  AppCoordinator (@Observable) — recording state, history    │   │
│  └────────────────────────────────────────────────────────────┘   │
├──────────────────────────────────────────────────────────────────┤
│                     Intelligence Layer                             │
│  ┌───────────────┐  ┌──────────────┐  ┌───────────────────────┐   │
│  │ SummaryEngine │  │ NotesEngine  │  │  OpenRouterClient     │   │
│  └───────────────┘  └──────────────┘  └───────────────────────┘   │
├──────────────────────────────────────────────────────────────────┤
│                     Capture Layer                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐     │
│  │  MicCapture  │  │SystemAudio   │  │ TranscriptionEngine   │     │
│  └──────────────┘  └──────────────┘  └──────────────────────┘     │
├──────────────────────────────────────────────────────────────────┤
│                     Persistence Layer                              │
│  ┌───────────────┐  ┌─────────────┐  ┌──────────────────────┐     │
│  │TranscriptStore│  │SessionStore │  │  TranscriptLogger    │     │
│  └───────────────┘  └─────────────┘  └──────────────────────┘     │
└──────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Implementation |
|-----------|---------------|----------------|
| MenuBarController | NSStatusItem ownership, popover lifecycle, icon pulse | Existing AppKit class |
| MenuBarPopoverView | Minimal recording status + start/stop + "Open MeetingScribe" | Existing SwiftUI view (stripped down) |
| MainWindowCoordinator | Window show/hide, activation policy flip, NSWindow lifecycle | New AppKit helper or extend AppDelegate |
| MainAppView | NavigationSplitView root — sidebar + detail router | New SwiftUI view (replaces ContentView role) |
| MeetingSidebarView | Chronological meeting list, live session row at top | New SwiftUI view |
| DetailRouter | Selects between LiveDetailView and PastMeetingDetailView based on selection | New SwiftUI view |
| LiveDetailView | Live transcript during recording, recording controls | New SwiftUI view |
| PastMeetingDetailView | Summary at top, full transcript below, Slack copy | New SwiftUI view |
| SettingsTab | LLM/transcription/audio settings — tab in main window | Refactored from existing SettingsView |

## Recommended Project Structure

```
Sources/OpenOats/
├── App/
│   ├── AppCoordinator.swift        # existing — no structure change needed
│   ├── AppRuntime.swift            # existing
│   ├── MenuBarController.swift     # existing — minor: strip transcript, add "Open" link
│   ├── OpenOatsApp.swift           # MODIFIED: replace Window("main") with new MainAppView
│   └── OpenOatsDeepLink.swift      # existing
├── Views/
│   ├── MainAppView.swift           # NEW: NavigationSplitView root
│   ├── MeetingSidebarView.swift    # NEW: sidebar list with live session row
│   ├── DetailRouter.swift          # NEW: live vs past meeting pane switch
│   ├── LiveDetailView.swift        # NEW: live transcript during recording
│   ├── PastMeetingDetailView.swift # NEW: summary + transcript + Slack copy
│   ├── MenuBarPopoverView.swift    # MODIFIED: stripped to status + stop + open link
│   ├── SettingsView.swift          # existing — embed in main window tab
│   ├── TranscriptView.swift        # existing — reused in LiveDetailView
│   └── ContentView.swift           # REMOVE or repurpose as live-only fallback
├── Intelligence/
│   ├── SummaryEngine.swift         # NEW: structured summary from transcript
│   └── [existing engines]
└── [existing layers unchanged]
```

### Structure Rationale

- **MainAppView.swift:** Single file owns the NavigationSplitView scaffold. Column widths and sidebar toggle state live here with `@SceneStorage` for persistence across launches.
- **DetailRouter.swift:** Keeps the sidebar list decoupled from what it shows. The router reads `coordinator.isRecording` + `selectedSessionID` to pick the right detail component.
- **LiveDetailView.swift / PastMeetingDetailView.swift:** Separate files per the global Swift rule ("break different types into separate files"). Live and past views share no structure — splitting avoids conditional sprawl in a single file.
- **MeetingSidebarView.swift:** Owns the live session row (pinned at top while recording) and the historical list below. Keeps selection binding and context menu logic local.

## Architectural Patterns

### Pattern 1: Single Window Scene with NavigationSplitView

**What:** Replace the current two-window approach (separate "main" + "notes" windows) with one `Window` scene containing a `NavigationSplitView`. Settings move into a tab inside the main window, not a separate `Settings {}` scene.

**When to use:** When the app has a primary browsing surface that should always be available. Granola, Apple Notes, and Mail all use this.

**Trade-offs:** Simpler (one window to manage) but loses the free macOS `Settings {}` window chrome. Accept this trade-off — Settings as a tab matches the v1 design spec.

**Example:**
```swift
// In OpenOatsApp.swift — MODIFIED
Window("MeetingScribe", id: "main") {
    MainAppView(settings: settings)
        .environment(coordinator)
        .environment(runtime)
}
.windowStyle(.titleBar)
.defaultSize(width: 900, height: 600)
.windowResizability(.contentMinSize)
```

```swift
// MainAppView.swift — NEW
struct MainAppView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Bindable var settings: AppSettings
    @SceneStorage("sidebarColumnVisibility") private var columnVisibility =
        NavigationSplitViewVisibility.all
    @State private var selectedSessionID: String?

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            MeetingSidebarView(selectedSessionID: $selectedSessionID)
        } detail: {
            DetailRouter(selectedSessionID: $selectedSessionID, settings: settings)
        }
        .navigationSplitViewStyle(.balanced)
    }
}
```

### Pattern 2: Live Session as a Synthetic Sidebar Row

**What:** During recording, inject a synthetic "Live Session" item at the top of the sidebar list. Selecting it shows `LiveDetailView`. When recording stops, replace it with the completed session entry (which auto-selects).

**When to use:** Any time a live process needs to be surfaced in a history-browsing UI without breaking the list data model.

**Trade-offs:** Requires a `MeetingListItem` enum (`.live` + `.session(SessionIndex)`) instead of passing `SessionIndex` directly. Small extra complexity, but the UX matches Granola exactly.

**Example:**
```swift
// MeetingSidebarView.swift
enum MeetingListItem: Identifiable, Hashable {
    case live
    case session(SessionIndex)

    var id: String {
        switch self {
        case .live: return "_live_"
        case .session(let s): return s.id
        }
    }
}
```

The list always prepends `.live` when `coordinator.isRecording == true`. When recording ends and `coordinator.lastEndedSession` is set, the sidebar selection transitions to that session ID automatically.

### Pattern 3: Detail Router (Computed View Selection)

**What:** A single `DetailRouter` view reads two signals — `coordinator.isRecording` and `selectedSessionID` — to pick what fills the detail pane. This is the single source of truth for what the user sees.

**When to use:** When the detail pane has multiple mutually exclusive states that depend on global app state, not just navigation selection.

**Trade-offs:** Adds one thin layer. Without it, every view embedding the split view would need the same branching logic.

**Example:**
```swift
// DetailRouter.swift
struct DetailRouter: View {
    @Binding var selectedSessionID: String?
    @Bindable var settings: AppSettings
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        switch resolvedContent {
        case .live:
            LiveDetailView(settings: settings)
        case .past(let sessionID):
            PastMeetingDetailView(sessionID: sessionID, settings: settings)
        case .empty:
            ContentUnavailableView("Select a Meeting", systemImage: "waveform",
                description: Text("Choose a meeting from the sidebar."))
        }
    }

    private enum Content { case live, past(String), empty }

    private var resolvedContent: Content {
        if coordinator.isRecording, selectedSessionID == "_live_" { return .live }
        if let id = selectedSessionID, id != "_live_" { return .past(id) }
        return .empty
    }
}
```

### Pattern 4: Window Lifecycle and Activation Policy Flip

**What:** The app runs as `.accessory` (no dock icon, menu bar only) when the main window is hidden. When the user clicks "Open MeetingScribe", the app switches to `.regular` and brings the window forward. Closing the main window switches back to `.accessory`.

**When to use:** Standard pattern for menu-bar-primary apps that also have a main window (Bartender, Granola, Reeder).

**Trade-offs:** The `.regular`/`.accessory` transition is visible to the user (dock icon appears/disappears). This is correct macOS behavior, not a bug.

**Implementation notes:**
- This pattern already exists in the codebase (`AppDelegate.windowShouldClose` and `showMainWindow()`)
- The new main window uses the same existing `id: "main"` window slot
- `openWindow(id: "main")` from SwiftUI or `window.makeKeyAndOrderFront(nil)` from AppKit both work
- On macOS Sonoma+, use `NSApp.activate()` (the non-deprecated overload) instead of `NSApp.activate(ignoringOtherApps: true)`

## Data Flow

### Recording Start → Live View

```
User clicks Start in MenuBarPopover or MainAppView
    ↓
coordinator.handle(.userStarted(metadata), settings: settings)
    ↓
AppCoordinator.startTranscription() — existing
    ↓
TranscriptionEngine emits utterances → TranscriptStore
    ↓
MeetingSidebarView observes coordinator.isRecording → prepends ".live" row
    ↓
DetailRouter sees .live selection → shows LiveDetailView
    ↓
LiveDetailView polls coordinator.transcriptStore.utterances (same as old ContentView)
```

### Recording Stop → Auto-navigate to Completed Session

```
User clicks Stop (in LiveDetailView or MenuBarPopover)
    ↓
coordinator.handle(.userStopped)
    ↓
AppCoordinator.finalizeCurrentSession() — writes sidecar, updates lastEndedSession
    ↓
coordinator.sessionHistory updated (loadHistory() called at end of finalize)
    ↓
MeetingSidebarView: coordinator.isRecording = false → removes .live row
    ↓
MainAppView.onChange(coordinator.lastEndedSession): selectedSessionID = lastEndedSession.id
    ↓
DetailRouter → PastMeetingDetailView for the just-completed session
```

### Session Selection → Past Meeting Detail

```
User clicks session in sidebar
    ↓
selectedSessionID binding updated
    ↓
DetailRouter resolves .past(id) → PastMeetingDetailView(sessionID: id)
    ↓
PastMeetingDetailView.task: load summary + transcript from SessionStore
    ↓
View shows: SummarySection (top) → TranscriptSection (below) → SlackCopyBar (bottom)
```

### State Management

```
AppCoordinator (@Observable)
    ↓ (environment injection, observed automatically)
MainAppView
    ├── MeetingSidebarView (reads: isRecording, sessionHistory, lastEndedSession)
    └── DetailRouter
        ├── LiveDetailView (reads: transcriptStore.utterances, isRecording)
        └── PastMeetingDetailView (reads: sessionStore async, notesEngine)
```

All views use `@Environment(AppCoordinator.self)` — no prop drilling of the coordinator. `selectedSessionID` is owned by `MainAppView` as `@State` and passed down as `@Binding`.

## Integration Points

### New vs Modified

| Component | Status | Integration Point |
|-----------|--------|-------------------|
| `MainAppView.swift` | NEW | Replaces role of `ContentView.swift` as the main window root |
| `MeetingSidebarView.swift` | NEW | Reads `coordinator.sessionHistory` + `coordinator.isRecording` |
| `DetailRouter.swift` | NEW | Reads `selectedSessionID` + coordinator state |
| `LiveDetailView.swift` | NEW | Extracts live transcript logic from `ContentView`; reuses `TranscriptView` |
| `PastMeetingDetailView.swift` | NEW | Merges `NotesView` logic + new summary section + Slack copy |
| `MenuBarPopoverView.swift` | MODIFIED | Strip live transcript section; add "Open MeetingScribe" link |
| `OpenOatsApp.swift` | MODIFIED | `Window("main")` now hosts `MainAppView`; remove `Window("notes")` scene |
| `ContentView.swift` | REMOVE | Logic migrates to `LiveDetailView` + `MainAppView` |
| `NotesView.swift` | REMOVE | Logic migrates to `PastMeetingDetailView` |
| `AppDelegate` | MINOR MOD | `windowShouldClose` targets new window; existing activation policy logic stays |
| `AppCoordinator` | UNCHANGED | No new state needed; `sessionHistory`, `isRecording`, `lastEndedSession` already exist |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| MainAppView ↔ MeetingSidebarView | `@Binding var selectedSessionID` | Sidebar updates selection; router reads it |
| DetailRouter ↔ LiveDetailView | Environment (coordinator) | Live view reads transcriptStore directly |
| DetailRouter ↔ PastMeetingDetailView | sessionID: String passed as prop | Past view owns its async load lifecycle |
| LiveDetailView ↔ AppCoordinator | `.handle(.userStopped)` call | Stop button in live view triggers coordinator |
| MenuBarPopoverView ↔ MainWindowCoordinator | `onShowMainWindow: () -> Void` callback | Existing pattern, no change needed |
| PastMeetingDetailView ↔ SummaryEngine | `coordinator.summaryEngine.generate()` async call | New path; same pattern as existing notesEngine |

## Build Order

Dependencies flow strictly downward — each step depends only on what came before.

```
Step 1: MainAppView + MeetingSidebarView (no detail content yet)
  - Scaffold NavigationSplitView
  - Sidebar shows session history list (existing data)
  - Detail pane shows empty state placeholder
  - Update OpenOatsApp.swift: Window("main") hosts MainAppView
  - Verify: app opens, sidebar populates, window lifecycle works

Step 2: PastMeetingDetailView (read-only — no summary yet)
  - Port transcript display from NotesView
  - Add meeting metadata header (date, duration, type)
  - Add copy-to-clipboard for transcript
  - DetailRouter wires selection → past view
  - Verify: clicking session shows transcript

Step 3: LiveDetailView (replaces ContentView live transcript)
  - Port live transcript display from ContentView
  - Add recording controls (start/stop, audio level)
  - MeetingListItem enum + .live row in sidebar
  - Auto-navigate to completed session on stop
  - Verify: full recording flow through main window

Step 4: Strip MenuBarPopover + remove ContentView/NotesView
  - Remove live transcript from popover
  - Add "Open MeetingScribe" link to popover
  - Delete ContentView.swift + NotesView.swift
  - Verify: menu bar popover is minimal; all flows go through main window

Step 5: SummaryEngine + PastMeetingDetailView summary section
  - Implement SummaryEngine actor
  - Add summary at top of PastMeetingDetailView
  - Wire generation to session end
  - Verify: summary appears after recording stops

Step 6: Slack copy + search
  - Add Slack-formatted copy button to PastMeetingDetailView
  - Add search bar to sidebar (NSSearchField or SwiftUI searchable)
  - Verify: copy produces Slack-friendly format; search filters list
```

## Anti-Patterns

### Anti-Pattern 1: Embedding Live State in NotesView

**What people do:** Add a "Live" tab or conditional to the existing NotesView/session history window.

**Why it's wrong:** NotesView is designed around completed sessions loaded from disk. Grafting live state onto it creates implicit mode switching and bugs where async loads race with live updates. The existing codebase separates live (ContentView) from history (NotesView) for this reason.

**Do this instead:** Keep the split: `LiveDetailView` owns live state, `PastMeetingDetailView` owns disk-loaded state. `DetailRouter` is the clean boundary between them.

### Anti-Pattern 2: Polling `coordinator.isRecording` in Every View

**What people do:** Each subview independently observes `coordinator.isRecording` and branches on it.

**Why it's wrong:** Duplicates the routing logic. When requirements change (e.g., add a "finalizing" state), every view needs updating.

**Do this instead:** `DetailRouter` is the single place that reads `coordinator.isRecording` for routing decisions. Subviews only see what they need (live views get the transcript store; past views get a session ID).

### Anti-Pattern 3: Using `Window("notes")` Alongside the New Main Window

**What people do:** Keep the separate Notes window and add a new main window on top.

**Why it's wrong:** Two overlapping windows with overlapping content (both show meeting history) confuse users and split the window management burden. The whole point of this milestone is consolidation.

**Do this instead:** Delete the `Window("notes")` scene from `OpenOatsApp.swift`. All history browsing moves into the main window's sidebar + detail layout. The `Settings {}` scene can stay (it's the macOS standard) or move to a tab — project spec says tab.

### Anti-Pattern 4: `openWindow(id:)` for Showing the Main Window After App Goes to Background

**What people do:** Call `openWindow(id: "main")` from inside a SwiftUI view to re-show the main window.

**Why it's wrong:** When the app is in `.accessory` activation policy (dock icon hidden), `openWindow` may not bring the window to front reliably. The window exists but isn't focused.

**Do this instead:** The existing `showMainWindow()` function in `OpenOatsRootApp` already does this correctly: `NSApp.setActivationPolicy(.regular)` → `NSApp.activate(ignoringOtherApps: true)` → `window.makeKeyAndOrderFront(nil)`. Keep this pattern and wire `MenuBarController.onShowMainWindow` to it.

## Scaling Considerations

This is a single-user local app. Scaling is not a concern. The only performance consideration relevant to the main window:

| Concern | Approach |
|---------|----------|
| Large session history (100+ meetings) | Use `List` (lazy by default on macOS) — sidebar already does this |
| Long transcripts in detail pane | Use `LazyVStack` inside `ScrollView` — existing `NotesView` already does this |
| Live transcript scroll performance | Existing `TranscriptView` works; auto-scroll to bottom on new utterances with `ScrollViewReader` |
| Summary generation blocking UI | `SummaryEngine` is an actor; call with `Task {}` from the view, show progress indicator |

## Sources

- [NavigationSplitView — Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/navigationsplitview)
- [Building and customizing the menu bar with SwiftUI — Apple Developer Documentation](https://developer.apple.com/documentation/SwiftUI/Building-and-customizing-the-menu-bar-with-SwiftUI)
- [Window management in SwiftUI — Swift with Majid](https://swiftwithmajid.com/2022/11/02/window-management-in-swiftui/)
- [Mastering NavigationSplitView in SwiftUI — Swift with Majid](https://swiftwithmajid.com/2022/10/18/mastering-navigationsplitview-in-swiftui/)
- [Showing Settings from macOS Menu Bar Items — Peter Steinberger](https://steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items)
- [Fine-Tuning macOS App Activation Behavior — Art Lasovsky](https://artlasovsky.com/fine-tuning-macos-app-activation-behavior)
- [Programmatically hide and show sidebar in split view — Nil Coalescing](https://nilcoalescing.com/blog/ProgrammaticallyHideAndShowSidebarInSplitView/)
- Existing codebase: `AppCoordinator.swift`, `MenuBarController.swift`, `OpenOatsApp.swift`, `NotesView.swift`, `ContentView.swift`

---
*Architecture research for: macOS main app window (Granola-style) alongside menu bar*
*Researched: 2026-03-21*
