# Phase 4: Live Recording + Menu Bar Cleanup - Research

**Researched:** 2026-03-22
**Domain:** SwiftUI macOS — live transcript view, synthetic sidebar row, state-driven detail routing, menu bar minimal mode, legacy file deletion
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **Live View Layout:** Granola-style — live transcript in detail pane, auto-scrolling. Same labeled-lines format as PastMeetingDetailView. Recording controls at top of detail pane: red dot indicator, duration timer, Stop button. Partial/in-progress utterances in distinct style (lighter or italic).
- **Recording Transition:** Brief "Finalizing..." loading state when recording stops (while transcript saves). Then auto-swap to PastMeetingDetailView for completed session. Sidebar: live row disappears, completed session row appears and auto-selects. If main window is closed during recording: stay hidden — no auto-open. User gets a notification from menu bar instead.
- **Sidebar Live Row:** Synthetic "Live Session" row pinned at top during recording. Shows pulsing dot + meeting type + duration timer. Auto-selects on recording start. When recording stops: row transitions to completed session entry.
- **Start Buttons:** Both places — in menu bar popover (existing, keep as-is) AND in main window (empty/onboarding state or toolbar actions). Both trigger the same AppCoordinator flow.
- **Menu Bar Popover (During Recording):** Status + Stop. Red dot + duration timer + Stop button. "Open Papyrus" link always visible. No live transcript in popover.
- **Menu Bar Popover (Idle):** Three start buttons (Start Call / Solo memo / Solo room) + "Open Papyrus" link + Quit Papyrus.
- **Legacy File Deletion:** Delete ContentView.swift and NotesView.swift after migration. Verify no remaining references.

### Claude's Discretion
- LiveDetailView internal layout details (spacing, fonts, animation for new utterances)
- How partial utterances are styled (italic, lighter color, etc.)
- "Finalizing..." loading state design
- Start button placement in main window (toolbar vs onboarding empty state vs both)
- Whether to show audio level meter in the recording header

### Deferred Ideas (OUT OF SCOPE)
- Calendar integration via EventKit
- Templates system
- Slack Bot Token
- Meeting series mapping
- Preview modal
- Week recap
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| LIVE-01 | During recording, live transcript appears in the main window detail pane (not menu bar) | LiveDetailView created from ContentView migration; TranscriptView is directly reusable |
| LIVE-02 | Sidebar shows synthetic "Live Session" row pinned at top during recording | MeetingListItem enum (.live / .session) + conditional prepend in MeetingSidebarView |
| LIVE-03 | When recording stops, detail auto-navigates to the completed session | onChange(coordinator.lastEndedSession) in MainAppView sets selectedSessionID |
| LIVE-04 | DetailRouter routes between live view and past meeting view based on state | DetailRouter already exists; add .live case routing to coordinator.isRecording + selectedSessionID == "_live_" |
| MENU-01 | Menu bar popover shows only: recording status, start/stop buttons, "Open MeetingScribe" link | MenuBarPopoverView already has this shape — add three idle start buttons, remove any remnant transcript references |
| MENU-02 | Live transcript is removed from menu bar popover | ContentView live transcript is in a separate window; MenuBarPopoverView currently has no transcript section — confirm no accidental remnant |
| MENU-03 | ContentView.swift and NotesView.swift are removed (logic migrated to main window) | ContentView live logic migrates to LiveDetailView; NotesView history logic already migrated in Phase 2/3 |
</phase_requirements>

---

## Summary

Phase 4 is primarily a **migration and wiring phase** — almost all required logic already exists in the codebase. ContentView.swift contains the live recording logic (utterances, volatileYouText/volatileThemText, start/stop flow, consent gate, utterance persistence side effects); this migrates to a new LiveDetailView.swift. PastMeetingDetailView.swift already provides the labeled-line transcript format that the live view must match. The existing AppCoordinator exposes `isRecording`, `lastEndedSession`, `transcriptStore.utterances`, and `state` — no new coordinator state is required.

The two primary engineering challenges are: (1) **the "Finalizing..." state window** between `userStopped` and `finalizationComplete` — the MeetingState machine already models this as `.ending`; LiveDetailView must detect and display it; (2) **the synthetic live sidebar row** — MeetingSidebarView needs a `MeetingListItem` enum and conditional logic to prepend a `.live` entry when `coordinator.isRecording == true`, then auto-select it on start and transition to the completed session ID on stop.

MenuBarPopoverView already has the correct minimal shape (status line, primary action button, Open Papyrus, Quit). The only required change is expanding the idle `primaryAction` from a single "Start Recording" button to three buttons (Start Call / Solo memo / Solo room) matching the ContentView/ControlBar pattern. ContentView.swift and NotesView.swift can be deleted once references are cleaned; the `Window("notes")` scene was already removed in Phase 2/3.

**Primary recommendation:** Build in four discrete steps — (1) LiveDetailView + DetailRouter .live routing, (2) MeetingSidebarView MeetingListItem enum + live row, (3) MainAppView auto-navigate on stop, (4) MenuBarPopoverView idle start buttons + legacy file deletion.

---

## Standard Stack

### Core (all already in project — no new dependencies)

| Component | Version | Purpose | Status |
|-----------|---------|---------|--------|
| SwiftUI | iOS 26 / macOS 26 | Views, state binding, environment | In use |
| `@Observable` | Swift 5.9+ | AppCoordinator observation | In use |
| `ScrollViewReader` | SwiftUI | Auto-scroll to bottom on new utterances | Already in TranscriptView |
| `withAnimation` | SwiftUI | Pulsing dot, live row transition | Available |
| `Task.sleep` | Swift concurrency | Duration timer loop in live header | Pattern from MenuBarPopoverView |

### No New Dependencies

This phase introduces zero new packages. All building blocks exist:
- `TranscriptView.swift` — reuse directly in LiveDetailView (utterances + volatile text auto-scroll)
- `ControlBar.swift` — reference for start/stop button pattern; start buttons in main window can reuse
- `AppCoordinator.transcriptStore` — direct source for live utterances

---

## Architecture Patterns

### Recommended Project Structure (delta from current)

```
Sources/OpenOats/
├── Views/
│   ├── LiveDetailView.swift        # NEW — extracted from ContentView
│   ├── DetailRouter.swift          # MODIFIED — add .live routing case
│   ├── MeetingSidebarView.swift    # MODIFIED — MeetingListItem enum + live row
│   ├── MainAppView.swift           # MODIFIED — onChange(lastEndedSession)
│   ├── MenuBarPopoverView.swift    # MODIFIED — three idle start buttons
│   ├── ContentView.swift           # DELETE
│   └── NotesView.swift             # DELETE
```

### Pattern 1: MeetingListItem Enum for Synthetic Row

**What:** Replace bare `String?` sidebar selection with a typed enum that has a `.live` case and a `.session(SessionIndex)` case. The `_live_` sentinel string becomes the `.live` case id.

**When to use:** When a list model needs a pinned synthetic item that is not backed by persistent data.

**Implementation notes:**
- Declare as `enum MeetingListItem: Identifiable, Hashable` — follows the `groupedSessions` free-function pattern (testable via `@testable import OpenOatsKit`)
- Keep the `var id: String` property returning `"_live_"` for `.live` — this is the value bound to `selectedSessionID: String?` in MainAppView
- The sidebar `List(selection: $selectedSessionID)` binding does not change; the live row just supplies `"_live_"` as its tag

```swift
// MeetingSidebarView.swift — new enum (top-level, testable)
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

### Pattern 2: LiveDetailView Layout

**What:** A detail pane view with a fixed recording header and a scrollable transcript body.

**When to use:** During `coordinator.isRecording == true` and `selectedSessionID == "_live_"`.

**Key properties to read from coordinator:**
- `coordinator.transcriptStore.utterances` — committed utterances
- `coordinator.transcriptStore.volatileYouText` — in-progress you speech
- `coordinator.transcriptStore.volatileThemText` — in-progress them speech
- `coordinator.isRecording` — controls whether recording header shows or "Finalizing..." shows
- `coordinator.state` — check for `.ending` to show "Finalizing..." state

**Transcript rendering:** Reuse `TranscriptView` directly — it already handles auto-scroll, volatile indicators, and labeled lines. The live view wraps it with the recording header above.

**The Finalizing state:** When `userStopped` fires, `coordinator.state` transitions to `.ending`. The coordinator does NOT set `isRecording = false` yet (that only happens on `finalizationComplete`). Therefore `isRecording` stays `true` during finalization. The live view should detect `.ending` state and show "Finalizing..." in place of the stop button:

```swift
// LiveDetailView.swift — recording header state logic
private var isFinalizing: Bool {
    if case .ending = coordinator.state { return true }
    return false
}
```

**Important:** `coordinator.isRecording` returns `true` during `.recording` AND `false` during `.ending` (see AppCoordinator line 70-73: `if case .recording = state { return true }`). So `.ending` means `isRecording == false` but `state == .ending`. The live row should stay visible and the live detail view should show "Finalizing..." until `lastEndedSession` is set. The DetailRouter's `.live` routing condition must check `selectedSessionID == "_live_"` — not just `isRecording` — so the "Finalizing..." state still shows LiveDetailView.

**Revised DetailRouter logic:**
```swift
// DetailRouter.swift — updated resolvedContent
private var resolvedContent: Content {
    if selectedSessionID == "_live_" {
        // Show live view whether actively recording or finalizing
        return .live
    }
    if let id = selectedSessionID, id != "_live_" {
        return .past(id)
    }
    return .empty
}
```

### Pattern 3: Auto-Navigate on Recording Stop

**What:** When `coordinator.lastEndedSession` changes from nil to a SessionIndex, MainAppView updates `selectedSessionID` to the completed session's id.

**Where to put it:** `onChange(of: coordinator.lastEndedSession)` in `MainAppView.body` — consistent with how NotesView previously did it (NotesView lines 40-47).

**Window-closed guard:** The CONTEXT.md decision says: if main window is closed during recording, stay hidden. The auto-navigate logic already satisfies this — `selectedSessionID` is stored as `@AppStorage` and will update regardless of window visibility. When the user later opens the window, it will show the completed session. No special guard needed in the onChange handler.

```swift
// MainAppView.swift — add to body or as modifier
.onChange(of: coordinator.lastEndedSession) { _, newSession in
    guard let session = newSession else { return }
    selectedSessionID = session.id
}
```

### Pattern 4: Sidebar Auto-Select on Recording Start

**What:** When `coordinator.isRecording` transitions to `true`, sidebar must auto-select `"_live_"`.

**Where to put it:** `onChange(of: coordinator.isRecording)` in `MainAppView.body`.

```swift
.onChange(of: coordinator.isRecording) { _, isRecording in
    if isRecording {
        selectedSessionID = "_live_"
    }
}
```

**Note:** Only set when `isRecording` becomes true. When it becomes false (finalization starts), do NOT clear — the "Finalizing..." state in LiveDetailView relies on `selectedSessionID` still being `"_live_"`.

### Pattern 5: MenuBarPopoverView Idle State — Three Start Buttons

**What:** Replace single "Start Recording" button with three buttons matching the existing ControlBar pattern.

**Current state of MenuBarPopoverView:** Already minimal — status line, primary action, Open Papyrus, Quit. The `primaryAction` @ViewBuilder shows either a Stop button (recording) or a single Start Recording button (idle). The CONTEXT.md requires three start buttons in idle mode.

**Implementation:** Expand the idle branch of `primaryAction` to show three bordered buttons — Start Call, Solo (memo), Solo (room) — consistent with `ControlBar.swift` callbacks.

**Consent gate:** ContentView's `startSession()` gates recording behind `settings.hasAcknowledgedRecordingConsent`. The menu bar popover currently calls `onShowMainWindow()` if consent not acknowledged. Keep this pattern — don't duplicate the consent sheet logic in the popover.

### Pattern 6: Utterance Side Effects Stay in LiveDetailView

**What:** ContentView currently handles utterance persistence side effects (transcriptLogger, refinementEngine, sessionStore) in `handleNewUtterance`. This logic must migrate to LiveDetailView.

**How:** LiveDetailView owns a polling loop (same pattern as ContentView's `.task` with `Task.sleep`) or uses `onChange(of: coordinator.transcriptStore.utterances.count)` to detect new utterances and dispatch persistence side effects.

**Recommendation:** Use `onChange(of: coordinator.transcriptStore.utterances.count)` instead of the polling loop — cleaner, reactive, less CPU overhead during live recording.

```swift
// LiveDetailView.swift
.onChange(of: coordinator.transcriptStore.utterances.count) { old, new in
    guard new > old else { return }
    handleNewUtterances(startingAt: old)
}
```

### Anti-Patterns to Avoid

- **Duplicate isRecording checks in every view:** DetailRouter is the single routing decision point. Subviews do not branch on `isRecording` for routing.
- **Using isRecording to detect "Finalizing..." state:** `isRecording` returns false during `.ending`. Check `coordinator.state` directly for the `.ending` case.
- **Removing "_live_" from selectedSessionID on stop:** Let `onChange(of: lastEndedSession)` replace it. Premature clearing causes the detail pane to flash to empty state.
- **Polling loop in LiveDetailView for every property:** Use `onChange` handlers for discrete events (utterance count, isRecording). Only use a polling loop for continuous values like `audioLevel` if the audio meter is shown.
- **Putting MeetingListItem inside MeetingSidebarView struct body:** Declare it as a top-level type in MeetingSidebarView.swift for `@testable import` access (consistent with `groupedSessions` free-function pattern).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Auto-scroll transcript | Custom scroll tracker | `ScrollViewReader` + existing `TranscriptView` | Already handles utterances + volatile text |
| Recording duration timer | NSTimer / DispatchQueue timer | `Task.sleep` loop (pattern from MenuBarPopoverView `startTimer()`) | Concurrency-safe, cancellable |
| Pulsing recording indicator | CAAnimation layer | SwiftUI `withAnimation(.easeInOut.repeatForever())` on Circle opacity | No AppKit needed |
| Utterance persistence | Re-implement | Port `handleNewUtterance` + `handleNewUtterances` verbatim from ContentView | These are correct and tested-in-practice |
| Consent gate | New sheet logic | Port existing `showConsentSheet` + `RecordingConsentView` pattern from ContentView | Already handles the state machine correctly |

---

## Common Pitfalls

### Pitfall 1: isRecording is False During Finalization

**What goes wrong:** LiveDetailView checks `coordinator.isRecording` to decide whether to show stop button vs "Finalizing...". But `isRecording` returns `false` during `.ending` state (see AppCoordinator implementation). The view disappears instead of showing the loading state.

**Why it happens:** `isRecording` is a computed property that only returns `true` for `.recording` state, not `.ending`.

**How to avoid:** Check `coordinator.state` directly: `if case .ending = coordinator.state { ... }`. Do not use `isRecording` for the "Finalizing..." detection.

**Warning signs:** Live view flashes to empty/past state immediately on Stop click, before the completed session appears.

### Pitfall 2: selectedSessionID Clears Too Early

**What goes wrong:** If any code sets `selectedSessionID = nil` when `isRecording` becomes false, the DetailRouter routes to `.empty` during the finalization window, creating a visible flash.

**Why it happens:** Reactively tying `selectedSessionID` cleanup to `isRecording == false`.

**How to avoid:** Only update `selectedSessionID` in response to `lastEndedSession` changing. Let the live row/live view stay selected during finalization.

### Pitfall 3: Live Row Not Auto-Selected When Recording Starts from Menu Bar

**What goes wrong:** User clicks Start in menu bar popover. Recording starts. Main window is open. Sidebar does not select the live row automatically.

**Why it happens:** `onChange(of: coordinator.isRecording)` is not wired in MainAppView, or the main window is not visible.

**How to avoid:** Wire `onChange(of: coordinator.isRecording)` in MainAppView unconditionally. The `selectedSessionID = "_live_"` assignment is harmless if the window is hidden — it will just be the selection when the window next opens.

### Pitfall 4: Utterance Persistence Not Wired in LiveDetailView

**What goes wrong:** Transcript shows on screen but nothing is written to disk. Session ends with 0 utterances.

**Why it happens:** ContentView's `handleNewUtterance` (transcriptLogger, refinementEngine, sessionStore.appendRecord) is not ported to LiveDetailView.

**How to avoid:** The entire `handleNewUtterance` + `handleNewUtterances` block from ContentView must migrate verbatim to LiveDetailView. This is the single most critical content migration.

### Pitfall 5: onHover Crash (Pre-existing Issue)

**What goes wrong:** Adding `.onHover` modifiers to buttons in LiveDetailView triggers EXC_BAD_ACCESS in `swift_getObjectType` on macOS 26 / Swift 6.2.

**Why it happens:** `onHover` closures trigger view body re-evaluation outside MainActor executor context (documented in ContentView with reference `b9625e7`).

**How to avoid:** Never use `.onHover` in LiveDetailView. Use `.help("...")` for hover tooltip text instead. This constraint is already documented in ContentView — carry it forward.

### Pitfall 6: ContentView/NotesView References After Deletion

**What goes wrong:** Build fails after deleting files because references remain in OpenOatsApp.swift (`Window("notes")`), AppDelegate, or test files.

**How to avoid:** Before deleting, grep for all references to `ContentView`, `NotesView`, `Window("notes")`, and `openWindow(id: "notes")`. The `openNotes` ExternalCommand case in AppCoordinator also calls `openWindow(id: "notes")` — this must be redirected to `selectedSessionID` assignment (same pattern already implemented in MainAppView.onOpenURL).

---

## Code Examples

### LiveDetailView Recording Header

```swift
// Source: CONTEXT.md + ContentView.swift patterns
private var recordingHeader: some View {
    HStack(spacing: 12) {
        // Pulsing red dot
        Circle()
            .fill(.red)
            .frame(width: 10, height: 10)
            .opacity(pulseOpacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulseOpacity = 0.3
                }
            }

        // Duration timer
        Text(formattedElapsed)
            .font(.system(size: 13, weight: .medium).monospacedDigit())
            .foregroundStyle(.primary)

        Spacer()

        // Stop button or Finalizing state
        if isFinalizing {
            ProgressView()
                .controlSize(.small)
            Text("Finalizing…")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        } else {
            Button("Stop") {
                coordinator.handle(.userStopped, settings: settings)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.small)
        }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
}

private var isFinalizing: Bool {
    if case .ending = coordinator.state { return true }
    return false
}
```

### MeetingSidebarView — Live Row

```swift
// Source: ARCHITECTURE.md + MeetingSidebarView.swift patterns
// Free function for testability
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

// In MeetingSidebarView.body — updated List
List(selection: $selectedSessionID) {
    if coordinator.isRecording {
        LiveSessionRowView()
            .tag("_live_")
    }
    ForEach(groupedSessions(coordinator.sessionHistory), id: \.label) { group in
        Section(group.label) {
            ForEach(group.sessions) { session in
                MeetingRowView(session: session)
                    .tag(session.id)
            }
        }
    }
}
```

### MainAppView — Auto-Navigate on Stop

```swift
// Source: ARCHITECTURE.md data flow diagram + NotesView onChange pattern
.onChange(of: coordinator.isRecording) { _, isRecording in
    if isRecording {
        selectedSessionID = "_live_"
    }
}
.onChange(of: coordinator.lastEndedSession) { _, session in
    guard let session else { return }
    selectedSessionID = session.id
}
```

### DetailRouter — Updated Routing

```swift
// Source: ARCHITECTURE.md Pattern 3
struct DetailRouter: View {
    @Binding var selectedSessionID: String?
    @Bindable var settings: AppSettings
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        switch resolvedContent {
        case .live:
            LiveDetailView(settings: settings)
        case .past(let id):
            PastMeetingDetailView(sessionID: id, settings: settings)
        case .empty:
            if coordinator.sessionHistory.isEmpty {
                // First launch onboarding
                emptyOnboardingView
            } else {
                ContentUnavailableView("Select a Meeting",
                    systemImage: "waveform",
                    description: Text("Choose a meeting from the sidebar."))
            }
        }
    }

    private enum Content { case live, past(String), empty }

    private var resolvedContent: Content {
        if selectedSessionID == "_live_" { return .live }
        if let id = selectedSessionID { return .past(id) }
        return .empty
    }
}
```

### ExternalCommand .openNotes Redirect

```swift
// In MainAppView.onOpenURL — already handles openNotes:
// Replace the remaining openWindow(id: "notes") call in ContentView
// with this pattern (also used in handlePendingExternalCommandIfPossible):
case .openNotes(let sessionID):
    selectedSessionID = sessionID
    // No openWindow call — already in main window
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Live transcript in menu bar popover (ContentView) | Live transcript in main window detail pane (LiveDetailView) | Phase 4 | Cleaner separation; popover minimal |
| Separate Window("notes") for history | Sidebar + detail in main Window | Phase 2 | Already done |
| `openWindow(id: "notes")` calls | `selectedSessionID` assignment | Phase 4 | All openNotes references must be updated |

**Deprecated/outdated after this phase:**
- `ContentView.swift`: All logic migrates out. File is deleted.
- `NotesView.swift`: All logic was already migrated in Phase 2/3. File is deleted.
- `openWindow(id: "notes")` call pattern: Replaced by selectedSessionID assignment everywhere.

---

## Open Questions

1. **Start buttons placement in main window (Claude's Discretion)**
   - What we know: CONTEXT.md says "empty/onboarding state, or as toolbar actions." The current DetailRouter already shows an onboarding view when `sessionHistory.isEmpty`.
   - What's unclear: Whether start buttons also appear in toolbar when sessions exist (so user can start a new recording without going to menu bar).
   - Recommendation: Show the three start buttons in the empty onboarding state (DetailRouter's `emptyOnboardingView`). Optionally add them as `.toolbar` items on MainAppView. The planner can decide; both work.

2. **Audio meter in recording header (Claude's Discretion)**
   - What we know: ContentView reads `coordinator.transcriptionEngine?.audioLevel` via a polling loop.
   - What's unclear: Whether to show it in LiveDetailView header.
   - Recommendation: Omit it in v1 for simplicity. The pulsing red dot provides sufficient visual feedback. The polling loop required for `audioLevel` adds complexity with low user value.

3. **"Notification instead" when window closed during recording stops**
   - What we know: CONTEXT.md says user gets a notification from menu bar when window is closed and recording stops.
   - What's unclear: Does this require a new `UserNotifications` call, or does existing `notificationService` cover it?
   - Recommendation: Check if `NotificationService` already has a "session ended" notification. If not, a simple `UNUserNotificationCenter` request with a static message is sufficient. This is a small addition to the `finalizeCurrentSession` flow if window is not visible.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (existing) |
| Config file | Package.swift targets OpenOatsTests |
| Quick run command | `swift test --filter OpenOatsTests 2>&1 | tail -5` |
| Full suite command | `swift test 2>&1 | tail -20` |

Run from: `/Users/vcartier/Desktop/OpenOats-fork/OpenOats/`

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| LIVE-02 | MeetingListItem.live has id "_live_" | unit | `swift test --filter MeetingListItemTests` | ❌ Wave 0 |
| LIVE-02 | MeetingListItem.session(s) has id matching session | unit | `swift test --filter MeetingListItemTests` | ❌ Wave 0 |
| LIVE-03 | selectedSessionID transitions from "_live_" to session.id on stop | unit (logic) | `swift test --filter LiveRecordingTransitionTests` | ❌ Wave 0 |
| LIVE-04 | DetailRouter resolvedContent == .live when selectedSessionID == "_live_" | unit (logic) | `swift test --filter DetailRouterTests` | ❌ Wave 0 |
| LIVE-04 | DetailRouter resolvedContent == .past when selectedSessionID is real ID | unit (logic) | `swift test --filter DetailRouterTests` | ❌ Wave 0 |
| LIVE-04 | DetailRouter resolvedContent == .empty when selectedSessionID is nil | unit (logic) | `swift test --filter DetailRouterTests` | ❌ Wave 0 |
| MENU-03 | Build succeeds with no references to ContentView or NotesView | build | `swift build 2>&1 | grep -E "error:"` | N/A — build check |

**Note:** LIVE-01, MENU-01, MENU-02 are visual/behavioral and verified manually or via build success.

### Sampling Rate

- **Per task commit:** `swift test --filter OpenOatsTests 2>&1 | tail -5`
- **Per wave merge:** `swift test 2>&1 | tail -20`
- **Phase gate:** Full suite green (192+ tests) before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `Tests/OpenOatsTests/MeetingListItemTests.swift` — covers LIVE-02 (MeetingListItem enum id values)
- [ ] `Tests/OpenOatsTests/DetailRouterTests.swift` — covers LIVE-04 (resolvedContent logic; extract as free function or test the enum logic in isolation)
- [ ] `Tests/OpenOatsTests/LiveRecordingTransitionTests.swift` — covers LIVE-03 (selectedSessionID transition logic; test the onChange logic using AppCoordinator state transitions)

---

## Sources

### Primary (HIGH confidence)

- Codebase: `ContentView.swift` — live transcript logic, utterance persistence, start/stop flow, onHover crash comment
- Codebase: `AppCoordinator.swift` — `isRecording` computed property, `lastEndedSession`, `finalizeCurrentSession`, `MeetingState.ending`
- Codebase: `MeetingState.swift` — `.recording`, `.ending`, `.idle` state machine
- Codebase: `TranscriptView.swift` — auto-scroll, volatile indicators, labeled lines
- Codebase: `MenuBarPopoverView.swift` — current minimal shape, timer pattern
- Codebase: `DetailRouter.swift` — current routing logic (to be extended)
- Codebase: `MeetingSidebarView.swift` — `groupedSessions` free function pattern, List selection binding
- Codebase: `PastMeetingDetailView.swift` — `TranscriptRow` labeled-lines format to match in live view
- Codebase: `NotesView.swift` — `onChange(of: coordinator.lastEndedSession)` pattern (lines 40-47)
- `.planning/research/ARCHITECTURE.md` — MeetingListItem enum spec, DetailRouter pattern, build order, data flow diagrams

### Secondary (MEDIUM confidence)

- Phase 3 accumulated decisions (STATE.md) — `@State` for NavigationSplitViewVisibility, free function pattern for testability

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependencies; all components in codebase
- Architecture: HIGH — ARCHITECTURE.md specifies exact patterns; code confirms feasibility
- Pitfalls: HIGH — `isRecording` vs `.ending` state bug verified by reading AppCoordinator source; onHover crash documented in ContentView comments
- Test map: HIGH — follows exact same patterns as SidebarDateGroupingTests and PastMeetingDetailTests

**Research date:** 2026-03-22
**Valid until:** 2026-04-22 (stable domain — all internal code, no external APIs)
