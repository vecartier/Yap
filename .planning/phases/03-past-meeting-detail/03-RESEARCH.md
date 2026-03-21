# Phase 3: Past Meeting Detail - Research

**Researched:** 2026-03-21
**Domain:** SwiftUI macOS detail pane — transcript display, Slack formatting, NSPasteboard
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Detail Pane Layout**
- Single continuous scroll — metadata, summary card, and transcript all in one scrollable view (Granola-style)
- No split panes — everything flows together, not fixed header + scrolling body
- Order top to bottom: Meeting metadata → Summary card (placeholder) → Transcript
- Action buttons (Slack copy, future export) sit inline below the summary card — not in a toolbar or floating bar

**Summary Section (Placeholder)**
- Empty card placeholder with subtle outline — "Summary will appear here" message
- Card shows where the summary will eventually render (Phase 5)
- Slack copy button exists below the card but is disabled/greyed out with tooltip "Summary required"
- When Phase 5 adds the summary engine, it populates this card and enables the button

**Transcript Display**
- Labeled lines format: `[timestamp] Speaker: text` — clean, scannable, like meeting minutes
- Timestamps: show timestamps every few minutes as subtle section markers, not on every utterance. Exact cadence is Claude's discretion.
- Speaker labels: "You", "Them", or "Room" — consistent with existing Speaker enum
- Speaker labels should be visually distinct (bold or colored) to scan quickly

**Slack Message Format (Template for Phase 5)**
- Structured sections with bold headers and bullet points using Slack mrkdwn syntax (`*bold*`, `•` bullets)
- Sections: header, key decisions, action items, discussion points, open questions
- The `SlackFormatter` should be a separate utility — not embedded in the view

**Slack Copy Button (Pre-Summary)**
- Button exists in the UI but is disabled until Phase 5 provides a summary
- Tooltip: "Summary required" when disabled
- When enabled (Phase 5): copies the Slack-formatted message to NSPasteboard

### Claude's Discretion
- Exact timestamp cadence for transcript (every 2-3 minutes or similar)
- Speaker label colors/styling
- Summary placeholder card visual design
- Transcript line spacing and font sizing
- Loading state while transcript data fetches from SessionStore
- Whether to use `LazyVStack` vs `List` for transcript performance

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| WIN-04 | Clicking a meeting shows Granola-style unified detail: summary at top, transcript below | Established by existing DetailRouter placeholder + SessionStore.loadTranscript; PastMeetingDetailView replaces the placeholder branch |
| SLCK-01 | Summary is formatted as a Slack-ready message (Markdown with clear sections) | SlackFormatter utility producing mrkdwn string; no external dependency needed |
| SLCK-02 | Slack message includes header, key decisions, action items, discussion points, open questions | Fixed template structure in SlackFormatter; pre-populated with placeholder sections in Phase 3 |
| SLCK-03 | Copy-to-clipboard button for Slack message in meeting detail pane | NSPasteboard.general pattern already used in NotesView.copyCurrentContent(); button disabled until Phase 5 |
</phase_requirements>

---

## Summary

Phase 3 replaces the `DetailRouter` placeholder branch with a real `PastMeetingDetailView`. All required data access patterns, color tokens, and clipboard mechanics already exist in the codebase — this phase is primarily composition and new view construction, not new infrastructure.

The core integration work is: (1) wire `PastMeetingDetailView(sessionID:settings:)` into `DetailRouter`, (2) port transcript loading from `NotesView.loadSelectedSession()`, (3) render transcript in labeled-line format with periodic timestamp markers, (4) add a summary placeholder card, and (5) add a disabled Slack copy button backed by a new `SlackFormatter` utility in `Intelligence/`.

`SlackFormatter` is a pure Swift struct with no async behavior — it takes a session title and structured summary sections and returns a `String`. In Phase 3 it formats a placeholder message (disabled button); in Phase 5 the button is enabled when a real summary is wired in.

**Primary recommendation:** Build `PastMeetingDetailView` as a single `ScrollView` + `LazyVStack` (matching the pattern in `NotesView`), load transcript via `.task {}` using the existing `coordinator.sessionStore.loadTranscript(sessionID:)` actor call, and place `SlackFormatter` in `Intelligence/`.

## Standard Stack

### Core (no new dependencies required)

| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| SwiftUI | macOS 15 (Swift 6.2) | View composition | Already the project stack |
| `SessionStore` (actor) | existing | Async transcript + notes loading | Already wires through `AppCoordinator` |
| `NSPasteboard` | AppKit | Copy to clipboard | Already used in `NotesView.copyCurrentContent()` |
| `LazyVStack` inside `ScrollView` | SwiftUI | Transcript row rendering | Already used in `NotesView.transcriptView` — performs well for 100s of rows |

### No New Package Dependencies
All building blocks exist. Do not introduce third-party packages for this phase.

**Installation:** none required.

## Architecture Patterns

### Recommended File Structure (new files only)

```
Sources/OpenOats/
├── Views/
│   └── PastMeetingDetailView.swift   # NEW — replaces DetailRouter placeholder
└── Intelligence/
    └── SlackFormatter.swift          # NEW — pure formatting utility
```

`SlackFormatter` belongs in `Intelligence/` alongside `NotesEngine` — it is a formatting concern, not a view concern.

### Pattern 1: Async Transcript Load in `.task {}`

**What:** Load transcript on view appearance using the `SessionStore` actor, guarding against stale loads if `sessionID` changes before the load completes.

**When to use:** Any time a detail view loads disk-backed data on selection.

**Example (modeled on `NotesView.loadSelectedSession()`):**
```swift
// PastMeetingDetailView.swift
@State private var transcript: [SessionRecord] = []
@State private var isLoading = true

var body: some View {
    // ... scroll content
    .task(id: sessionID) {
        isLoading = true
        transcript = []
        let loaded = await coordinator.sessionStore.loadTranscript(sessionID: sessionID)
        transcript = loaded
        isLoading = false
    }
}
```

The `.task(id: sessionID)` overload automatically cancels and restarts when `sessionID` changes — no manual guard needed.

### Pattern 2: Single Continuous ScrollView Layout

**What:** One `ScrollView` containing a `LazyVStack` with all sections. No nested scroll views. Sections are just `@ViewBuilder` sub-views within the same stack.

**When to use:** Granola-style unified view where the user scrolls through metadata → summary → transcript without visual breaks.

**Example:**
```swift
ScrollView {
    LazyVStack(alignment: .leading, spacing: 0) {
        MetadataHeaderSection(session: session)
        SummaryPlaceholderCard()
        SlackActionsRow(isEnabled: false)
        TranscriptSection(records: transcript)
    }
    .padding(20)
}
```

Note: `LazyVStack` inside `ScrollView` is the correct pattern for variable-length transcript content (existing `NotesView` uses this). Do NOT use `List` — it adds row separators and sidebar-style selection behavior that is wrong for a detail pane.

### Pattern 3: Timestamp Marker Cadence

**What:** Show a subtle timestamp label every N minutes within the transcript, not on every utterance. Claude's discretion: use 2-minute buckets (i.e., insert a marker when the elapsed time since the last marker crosses 120 seconds).

**When to use:** Long transcripts where the reader wants to orient themselves in time without timestamp clutter on every line.

**Implementation approach:**
```swift
// In TranscriptSection, compute markers during ForEach pass
struct TranscriptRow: View {
    let record: SessionRecord
    let showTimestamp: Bool   // true when this row starts a new 2-min bucket

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showTimestamp {
                Text(record.timestamp, style: .time)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 8)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                speakerLabel(for: record.speaker)
                Text(record.refinedText ?? record.text)
                    .font(.system(size: 13))
                    .textSelection(.enabled)
            }
        }
    }
}
```

Compute `showTimestamp` in the parent with a free function over `[SessionRecord]` so it is unit-testable (same rationale as `groupedSessions` in Phase 2).

### Pattern 4: Summary Placeholder Card

**What:** A rounded-rectangle card with `.stroke` border and centered placeholder text. Uses the same visual language as `ContentUnavailableView` but inline within the scroll.

**When to use:** When a content section will exist in a future phase but the layout space must be reserved now.

**Example:**
```swift
private var summaryPlaceholderCard: some View {
    RoundedRectangle(cornerRadius: 12)
        .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
        .frame(maxWidth: .infinity)
        .frame(height: 96)
        .overlay {
            Text("Summary will appear here")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
        }
}
```

### Pattern 5: Disabled Button with `.help()` Tooltip

**What:** The Slack copy button is always rendered but disabled with a descriptive tooltip. This preserves layout stability across Phase 3 and Phase 5.

**When to use:** Any time a feature is scaffolded before its enabling condition exists.

**Example:**
```swift
Button {
    copySlackMessage()
} label: {
    Label("Copy for Slack", systemImage: "doc.on.clipboard")
        .font(.system(size: 12))
}
.buttonStyle(.bordered)
.disabled(true)   // Phase 5: disabled(summary == nil)
.help("Summary required")
```

### Pattern 6: NSPasteboard Copy

**What:** Standard AppKit pasteboard write. Already used in `NotesView`.

**When to use:** Copying any string to the macOS clipboard.

**Example (from `NotesView.copyCurrentContent()`):**
```swift
NSPasteboard.general.clearContents()
NSPasteboard.general.setString(slackText, forType: .string)
```

### Pattern 7: SlackFormatter Utility

**What:** A pure `struct` (or `enum` with static method) that accepts summary data and returns a formatted mrkdwn string. No async, no SwiftUI import.

**When to use:** Any time Slack-formatted text needs to be produced. Keeping it outside the view makes it independently testable.

**Example:**
```swift
// Intelligence/SlackFormatter.swift
struct SlackFormatter {
    struct Summary {
        let meetingTitle: String
        let date: Date
        let decisions: [String]
        let actionItems: [String]
        let discussionPoints: [String]
        let openQuestions: [String]
    }

    static func format(_ summary: Summary) -> String {
        var lines: [String] = []
        lines.append("*Meeting: \(summary.meetingTitle) — \(Self.dateString(summary.date))*")
        lines.append("")
        lines.append("*Key Decisions*")
        summary.decisions.isEmpty
            ? lines.append("• _None recorded_")
            : summary.decisions.forEach { lines.append("• \($0)") }
        // ... repeat for each section
        return lines.joined(separator: "\n")
    }

    private static func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}
```

In Phase 3, `SlackFormatter` exists and is tested, but the UI button is disabled. Phase 5 enables it when a real `Summary` value is available.

### Anti-Patterns to Avoid

- **Embedding Slack formatting logic in `PastMeetingDetailView`:** Makes it untestable and creates coupling between formatting rules and view lifecycle. Use `SlackFormatter` as a separate utility.
- **Using `List` for the transcript:** Adds row selection, separators, and sidebar chrome that is wrong for a detail view. Use `LazyVStack` inside `ScrollView`.
- **Putting `showTimestamp` logic inline in the `ForEach` body:** Makes it untestable. Extract as a free function that maps `[SessionRecord]` → `[(SessionRecord, Bool)]` and lives alongside the view or in a helper file.
- **Using `.task {}` without the `id:` parameter:** Without `id: sessionID`, the task does not restart when a different session is selected. Always use `.task(id: sessionID)`.
- **Showing a timestamp on every utterance:** This was explicitly rejected. Show markers every ~2 minutes.
- **Accessing `Speaker.room` as "Them":** The existing `transcriptRow` in `NotesView` only handles `.you` / `.them`. Phase 3 must handle `.room` — display as "Room" with a neutral color (e.g., `Color.secondary`).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Clipboard write | Custom pasteboard wrapper | `NSPasteboard.general` directly | Already used in the project, no wrapper needed |
| Async actor call from view | Manual `Task` + `@State` busy flag | `.task(id:)` modifier | Automatic cancellation on id change; proper SwiftUI lifecycle integration |
| Markdown rendering for summary placeholder | Custom Markdown parser | `AttributedString(markdown:)` or plain `Text` | Placeholder is static text; no parsing needed in Phase 3 |
| Timestamp formatting | Custom date math | `DateFormatter` static instance | Already pattern-matched in `NotesView.transcriptTimeFormatter` |

## Common Pitfalls

### Pitfall 1: `.task {}` Without `id:` — Stale Data on Fast Navigation
**What goes wrong:** User clicks session A, then quickly clicks session B. The task for A completes after B is shown, overwriting B's transcript with A's data.
**Why it happens:** `.task {}` without an `id:` runs once on view appear and does not restart on re-render.
**How to avoid:** Always use `.task(id: sessionID) { ... }`. SwiftUI cancels the previous task when `sessionID` changes.
**Warning signs:** Transcript content flickers or shows wrong meeting's data.

### Pitfall 2: `Speaker.room` Not Handled
**What goes wrong:** A `.room` utterance hits the `you ? "You" : "Them"` ternary and renders as "Them" — incorrect.
**Why it happens:** `NotesView.transcriptRow` predates solo/room mode and only checks `.you`. Phase 3 must be exhaustive.
**How to avoid:** Use a `switch` or a helper on `Speaker` that returns `(label: String, color: Color)` for all three cases. Add `.room` → "Room" with `Color.secondary`.
**Warning signs:** Solo mode recordings show "Them" for single-speaker content.

### Pitfall 3: LazyVStack Timestamp Computation in Body
**What goes wrong:** Timestamp marker logic computed inside the `body` property causes O(n) work on every redraw.
**Why it happens:** SwiftUI calls `body` frequently; putting non-trivial computation there is expensive.
**How to avoid:** Compute `[(SessionRecord, Bool)]` pairs in a separate function called from `.task {}` and store in `@State`. Only recompute when transcript changes.
**Warning signs:** CPU spikes when scrolling in long transcripts.

### Pitfall 4: Summary Placeholder Card Height Too Small or Too Large
**What goes wrong:** Card looks like a divider (too short) or consumes half the screen (too tall) depending on the content area.
**Why it happens:** Fixed-height cards don't adapt.
**How to avoid:** Use `frame(minHeight: 80, idealHeight: 96)` with `.fixedSize(horizontal: false, vertical: true)` so the card has a sensible default but can grow. In Phase 3 the content is static, so a fixed 96pt height is fine.

### Pitfall 5: Calling `coordinator.sessionStore.loadTranscript` on Main Actor Without `await`
**What goes wrong:** Compile error or deadlock — `SessionStore` is an `actor`.
**Why it happens:** Actor isolation requires `await` on all calls from outside the actor.
**How to avoid:** Always call inside an async context: `.task(id: sessionID) { transcript = await coordinator.sessionStore.loadTranscript(sessionID: sessionID) }`.

### Pitfall 6: Colors Extension Scoped to TranscriptView
**What goes wrong:** `Color.youColor` / `Color.themColor` are currently defined in `TranscriptView.swift` as a `private extension Color`. Using them in `PastMeetingDetailView` will fail to compile if they remain private.
**Why it happens:** The extension is `// MARK: - Colors` inside `TranscriptView.swift` with no access modifier, but it lives in the same file as the `private` types — check actual access level.
**How to avoid:** Verify at implementation time: if `Color.youColor` is not `internal` or `public`, either promote access level in `TranscriptView.swift` or add a `.room` color directly in `PastMeetingDetailView.swift`. Do NOT duplicate the definition — move the extension to a shared `Colors.swift` file.

## Code Examples

### Loading Transcript (Verified Pattern — from `NotesView.loadSelectedSession()`)
```swift
// PastMeetingDetailView.swift
.task(id: sessionID) {
    isLoading = true
    transcript = []
    let loaded = await coordinator.sessionStore.loadTranscript(sessionID: sessionID)
    // guard for cancellation (task auto-cancels on id change but check remains defensive)
    transcript = loaded
    isLoading = false
}
```

### NSPasteboard Write (Verified Pattern — from `NotesView.copyCurrentContent()`)
```swift
NSPasteboard.general.clearContents()
NSPasteboard.general.setString(slackText, forType: .string)
```

### Reusing Metadata Helpers from DetailRouter
```swift
// These private helpers in DetailRouter.swift should become internal or be moved/
// duplicated into PastMeetingDetailView. The simplest approach: move them to a
// shared SessionIndex+Formatting.swift extension.

// formattedDate(_:)  → DateFormatter with .long + .short
// formattedDuration(from:to:)  → DateComponentsFormatter
// meetingType(for:)  → reads meetingApp ?? templateSnapshot.name ?? "Recording"
```

### DetailRouter Integration Point
```swift
// DetailRouter.swift — replace the placeholder branch:
// BEFORE:
if let sessionID = selectedSessionID {
    // Phase 3 placeholder VStack
}

// AFTER:
if let sessionID = selectedSessionID {
    PastMeetingDetailView(sessionID: sessionID, settings: settings)
}
```

### Speaker Label Exhaustive Switch
```swift
// Handle all three Speaker cases
private func speakerLabel(for speaker: Speaker) -> some View {
    let (label, color): (String, Color) = switch speaker {
    case .you:  ("You",  Color.youColor)
    case .them: ("Them", Color.themColor)
    case .room: ("Room", Color.secondary)
    }
    return Text(label)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(color)
        .frame(width: 36, alignment: .trailing)
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `.task {}` without `id:` | `.task(id:)` for selection-driven loads | SwiftUI on macOS 14+ | Automatic task cancellation on id change |
| `NSApp.activate(ignoringOtherApps: true)` | `NSApp.activate()` | macOS Sonoma | Non-deprecated API (already adopted in Phase 2) |
| `@StateObject` + `ObservableObject` | `@Observable` + `@Environment` | Swift 5.9 / iOS 17 | Already adopted in this project |

**Deprecated/outdated:**
- `NSPasteboard.setString(_:forType:)` preceded by `.clearContents()` — this is the correct pattern. Do not use `NSPasteboard.writeObjects(_:)` unless writing multiple types.

## Open Questions

1. **`Color.youColor` / `Color.themColor` access level**
   - What we know: Defined in `TranscriptView.swift` as a `Color` extension at file scope (no explicit access modifier = `internal` by default in Swift)
   - What's unclear: Whether the build system or linter enforces anything that would require them to be in a shared file
   - Recommendation: Verify at implementation time. If they are `internal`, they are accessible from `PastMeetingDetailView` without changes. If unexpectedly scoped, move to `Colors.swift`.

2. **`room` color choice**
   - What we know: `Color.youColor` (blue) and `Color.themColor` (amber) are established. `.room` has no color.
   - What's unclear: Whether a neutral gray or a third accent is better
   - Recommendation: Use `Color.secondary` (system adaptive gray) for `.room` — avoids introducing a third brand color.

3. **Timestamp cadence exact threshold**
   - What we know: "Every few minutes" is the requirement; Claude's discretion for exact cadence
   - Recommendation: 2-minute buckets (120 seconds since last shown marker). This matches Granola's density for typical meeting transcripts. Implement as a free function for testability.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (Swift Package Manager) |
| Config file | `OpenOats/Package.swift` — target `OpenOatsTests` |
| Quick run command | `cd /Users/vcartier/Desktop/OpenOats-fork/OpenOats && swift test --filter OpenOatsTests 2>&1 \| tail -20` |
| Full suite command | `cd /Users/vcartier/Desktop/OpenOats-fork/OpenOats && swift test 2>&1 \| tail -30` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| WIN-04 | `PastMeetingDetailView` renders metadata header, summary placeholder, and transcript section | unit (view logic) | Tested via `SlackFormatterTests` + `TranscriptTimestampTests` (pure logic); SwiftUI view rendering is manual-only | ❌ Wave 0 |
| WIN-04 | Transcript loads from `SessionStore` without crashing when no JSONL file exists | unit | `swift test --filter PastMeetingDetailTests/testEmptyTranscriptDoesNotCrash` | ❌ Wave 0 |
| WIN-04 | Timestamp marker computed correctly (2-min cadence) | unit | `swift test --filter TranscriptTimestampTests` | ❌ Wave 0 |
| SLCK-01 | `SlackFormatter.format(_:)` produces mrkdwn with correct section headers | unit | `swift test --filter SlackFormatterTests` | ❌ Wave 0 |
| SLCK-02 | All five sections present in formatted output | unit | `swift test --filter SlackFormatterTests/testAllSectionsPresent` | ❌ Wave 0 |
| SLCK-03 | Copy button is disabled in Phase 3 UI (no summary) | manual | n/a — launch app, select a meeting, verify button greyed | manual-only |

Note: SwiftUI view structure tests (does the button exist, is it in the right place) are not automatable with XCTest on macOS without a UI test host. The smoke tests in `UITests/OpenOatsUITests/SmokeTests.swift` exist but require Xcode — out of scope for `swift test` runs. Logic that can be extracted (timestamp bucketing, Slack formatting) must be unit-tested.

### Sampling Rate
- **Per task commit:** `swift test --filter SlackFormatterTests && swift test --filter TranscriptTimestampTests`
- **Per wave merge:** full `swift test` run
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `OpenOats/Tests/OpenOatsTests/SlackFormatterTests.swift` — covers SLCK-01, SLCK-02
- [ ] `OpenOats/Tests/OpenOatsTests/TranscriptTimestampTests.swift` — covers WIN-04 timestamp cadence logic
- [ ] `OpenOats/Tests/OpenOatsTests/PastMeetingDetailTests.swift` — covers WIN-04 empty transcript / no crash

## Sources

### Primary (HIGH confidence)
- Direct codebase inspection:
  - `OpenOats/Sources/OpenOats/Views/DetailRouter.swift` — placeholder to replace, metadata helpers to reuse
  - `OpenOats/Sources/OpenOats/Views/NotesView.swift` — reference implementation for transcript loading, clipboard, `LazyVStack` pattern
  - `OpenOats/Sources/OpenOats/Views/TranscriptView.swift` — `Color.youColor`, `Color.themColor` definitions and speaker label pattern
  - `OpenOats/Sources/OpenOats/Storage/SessionStore.swift` — `loadTranscript(sessionID:)` actor method signature
  - `OpenOats/Sources/OpenOats/Models/Models.swift` — `SessionRecord`, `Speaker`, `SessionIndex` struct shapes
  - `OpenOats/Package.swift` — test target structure, `@testable import OpenOatsKit`

### Secondary (MEDIUM confidence)
- SwiftUI `.task(id:)` behavior: cancellation on `id` change is documented Apple behavior (macOS 14+, iOS 17+)
- `NSPasteboard.general.clearContents()` + `setString(_:forType:)` pattern: matches AppKit documentation and existing project use in `NotesView`

### Tertiary (LOW confidence)
- None — all claims are grounded in direct codebase inspection or documented framework behavior.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all components already exist in the codebase with working examples
- Architecture: HIGH — patterns directly lifted from `NotesView` and `TranscriptView` which are already production-quality
- Pitfalls: HIGH — `.task(id:)` and `Speaker.room` gaps are directly visible in the code; `Color` access level is a minor uncertainty flagged
- SlackFormatter: HIGH — pure function with no async or framework dependencies; straightforward to implement and test

**Research date:** 2026-03-21
**Valid until:** This research is stable until Phase 5 changes the summary data model. Re-check `SlackFormatter.Summary` struct shape before Phase 5 planning.
