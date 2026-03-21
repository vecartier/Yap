# Pitfalls Research

**Domain:** macOS app window milestone — adding main window + NavigationSplitView + full-text search + PDF export to an existing menu-bar-only Swift 6.2 app
**Researched:** 2026-03-21
**Confidence:** HIGH (macOS window management and SwiftUI pitfalls verified across Apple Developer Forums, 2025 developer post-mortems, and official documentation)

---

## Critical Pitfalls

### Pitfall 1: WindowGroup Spawns Multiple Main Window Instances

**What goes wrong:**
`WindowGroup` — the default SwiftUI scene for macOS content windows — allows the user (and the `openWindow` action) to create multiple independent instances of the window. Clicking "Open MeetingScribe" from the menu bar popover a second time opens a second window rather than bringing the existing one to the front. By the third invocation the app has three identical windows with no clear primary.

**Why it happens:**
`WindowGroup` is designed for document-based apps where multiple instances make sense. It is the first example in every SwiftUI-for-macOS tutorial, so developers reach for it without recognizing the multi-instance behavior.

**How to avoid:**
Use the `Window` scene type (not `WindowGroup`) for the main app window. `Window` guarantees a single unique instance. When `openWindow(id:)` is called and the window already exists, macOS brings the existing window to the front instead of creating a new one. This matches the Granola/Apple Notes model precisely.

```swift
// Correct — singleton window
Window("MeetingScribe", id: "main") {
    ContentView()
}

// Wrong — multiple instances possible
WindowGroup("MeetingScribe") {
    ContentView()
}
```

**Warning signs:**
- Using `WindowGroup` without a `handlesExternalEvents(matching:)` guard
- The "Open MeetingScribe" button in the popover never checks if a window is already on screen
- Two windows appear when the menu bar item is clicked twice

**Phase to address:**
Main window phase — choose `Window` scene type at the outset; retrofitting later requires data-model surgery.

---

### Pitfall 2: Main Window Appears Behind Other App Windows (Focus and Activation Policy)

**What goes wrong:**
macOS apps running as menu bar accessories use `NSApplication.ActivationPolicy.accessory`, which tells the OS "this is a background utility." Windows created by accessory-policy apps are not automatically brought to the front and focused when shown — they often appear hidden behind the front-most application. The user clicks "Open MeetingScribe," nothing visibly happens, and they assume the app is broken.

**Why it happens:**
Menu bar apps are background utilities. The OS does not steal focus on behalf of a background app. The developer tests with their own app in the foreground and never notices the bug. The app must explicitly activate itself before showing the window.

**How to avoid:**
When opening the main window, call `NSApp.activate(ignoringOtherApps: true)` immediately before showing the window, and temporarily switch the activation policy to `.regular` if a dock icon is required for reliable focus. The sequence is:

1. `NSApp.setActivationPolicy(.regular)` — allows the window to receive focus
2. `NSApp.activate(ignoringOtherApps: true)` — brings app to front
3. `window.makeKeyAndOrderFront(nil)` — shows and focuses the window

When the window closes, optionally restore `.accessory` if a dock icon is not desired.

Additionally: the `openSettings` environment action broken in macOS 26 Tahoe is a known regression that requires a workaround (hidden window trick). Monitor Apple release notes before shipping on macOS 26.

**Warning signs:**
- "Open MeetingScribe" link in the popover calls `openWindow(id:)` without any activation call
- Window appears but keyboard focus remains in the previously active app
- Users on MacBooks report the window "appeared somewhere" but cannot see it

**Phase to address:**
Main window phase — the activation sequence must be wired into the menu bar "Open" action from day one; it cannot be deferred.

---

### Pitfall 3: NavigationSplitView Selection State Not Bound — Sidebar Shows No Selection

**What goes wrong:**
`NavigationSplitView` requires an explicit `@State` binding for the selected sidebar item. When the selection binding is not wired into the `List` — for example, when the developer uses a `NavigationLink` inside the list without connecting it to the split view's selection — the sidebar never highlights the current item. Clicking a meeting in the list navigates the detail pane correctly but the list shows no selection. On macOS the visual feedback is critical — without it the UI looks broken.

**Why it happens:**
Most NavigationSplitView tutorials show the two-column layout but omit the `selection:` parameter on the outer `NavigationSplitView` and the `tag:` modifier on each `List.ForEach` item. It compiles and partially works, making the missing binding invisible until QA.

**How to avoid:**
Wire the selection binding explicitly:

```swift
@State private var selectedMeeting: MeetingSession?

NavigationSplitView(columnVisibility: $columnVisibility) {
    List(meetings, selection: $selectedMeeting) { meeting in
        MeetingRowView(meeting: meeting)
            .tag(meeting)
    }
} detail: {
    if let meeting = selectedMeeting {
        MeetingDetailView(meeting: meeting)
    } else {
        ContentUnavailableView("Select a meeting", systemImage: "list.bullet.rectangle")
    }
}
```

**Warning signs:**
- `List` inside the sidebar column uses `NavigationLink` without `selection:` on the `List` itself
- Clicking a row navigates correctly but no row is highlighted in the sidebar
- Programmatic selection (e.g., "open most recent meeting") has no visible effect

**Phase to address:**
Main window / sidebar phase — establish the selection binding pattern before building any meeting row views.

---

### Pitfall 4: Live Transcript Updates Block the Main Thread

**What goes wrong:**
The existing transcription pipeline publishes utterances from background audio processing tasks. When the main app window shows a live transcript view, developers wire these updates directly into a `@State` array on a `@MainActor` view. Frequent utterance arrivals (every 0.5–2 seconds during active speech) cause continuous `@MainActor` context-switches from the audio pipeline. Under heavy transcription load this produces visible jank in the sidebar list scrolling and detail pane rendering.

**Why it happens:**
`@Observable` and `@Published` properties updated from background threads still require main-thread dispatch for UI rendering. The existing menu bar popover is simple enough (one label, two buttons) that this never manifested as a problem. The full window with a live-updating transcript list and sidebar is far more sensitive.

**How to avoid:**
- The transcription engine already publishes utterances via an `AsyncStream` or `@Observable` property. Ensure updates are coalesced before reaching the view: batch utterances with a 1-second debounce when the window is open.
- Mark `AppCoordinator` (already `@Observable`) as `@MainActor`-isolated so all mutations happen on the main actor; do not push work from within the view's `onReceive` handler.
- Avoid updating a live-scroll `ScrollView` on every utterance — use a `.onChange` with a debounce or animate only on paragraph boundaries.

**Warning signs:**
- The live transcript view calls `scrollTo` on every new utterance
- Sidebar list becomes unresponsive during active recording
- Instruments shows frequent main thread activity during transcription with no user interaction

**Phase to address:**
Main window / live transcript phase — establish the update throttling strategy before wiring the transcript stream to the view.

---

### Pitfall 5: Full-Text Search Blocks the Main Thread on Every Keystroke

**What goes wrong:**
The search feature requires scanning all past transcript and summary Markdown files in `~/Documents/OpenOats/`. A naive implementation reads every file synchronously inside the `onChange(of: searchText)` handler. With 200+ past meetings each averaging 50KB, this is 10MB+ of disk I/O on the main thread. The result: the search field lags, the sidebar freezes, and the app feels broken.

**Why it happens:**
File I/O on the main thread is the classic macOS bug. It is invisible during development with 3 test meetings and an SSD. It emerges in production with 6 months of accumulated meetings.

**How to avoid:**
- Run all search I/O on a background `Task` (detached or using a dedicated actor).
- Debounce the search query: do not start a search until the user has paused typing for 250ms (use `Task.sleep` or Combine's `.debounce` operator).
- Cache search index in memory: on app launch, build an in-memory index of meeting metadata (title, date, first 200 chars) in a background Task. Full transcript content is only loaded for the selected meeting.
- For long-term scale (hundreds of meetings), use `NSMetadataQuery` or a simple SQLite FTS5 index, but an in-memory `[String: String]` map loaded once at launch is sufficient for v1.

```swift
// Wrong — synchronous on main thread
.onChange(of: searchText) { query in
    results = allMeetings.filter { meeting in
        (try? String(contentsOf: meeting.transcriptURL)) // blocks main thread
            .map { $0.contains(query) } ?? false
    }
}

// Correct — background task with debounce
.onChange(of: searchText) { query in
    searchTask?.cancel()
    searchTask = Task {
        try await Task.sleep(for: .milliseconds(250))
        let results = await searchService.search(query: query)
        await MainActor.run { self.results = results }
    }
}
```

**Warning signs:**
- `onChange(of: searchText)` directly calls file I/O APIs without `Task { }` wrapping
- Search results appear instantaneously in testing (because only 3 test meetings exist)
- No debounce on the search text binding

**Phase to address:**
Search phase — establish the background search actor and debounce strategy before wiring the searchable modifier.

---

### Pitfall 6: PDF Export Produces a Single Page (Content Clipped) or Blank Output

**What goes wrong:**
`ImageRenderer` — the easiest SwiftUI-native PDF generation path — renders the view at its natural size in a single CGContext page. For a meeting transcript longer than one screen, the rendered content is clipped to one page. Worse, `ImageRenderer` renders with a "default" environment detached from the app's SwiftUI environment: `@EnvironmentObject`, custom fonts, and dynamic colors do not apply. The resulting PDF looks nothing like the in-app view and is cut off after one page.

**Why it happens:**
`ImageRenderer` is prominently documented for PDF generation and works perfectly for screenshots and short content. The single-page limitation and environment isolation are buried footnotes. Developers discover the clipping only when testing with a 90-minute meeting transcript.

**How to avoid:**
Use `NSAttributedString` + `NSPrintOperation` for macOS PDF generation. This is the reliable multi-page path:

1. Build an `NSAttributedString` from the transcript and summary (Markdown → `NSAttributedString` is supported via `AttributedString` bridging in macOS 15+).
2. Use `NSPrintOperation` with `NSPrintInfo` configured for PDF output (`PMPrintSettings` destination set to file).
3. Alternatively, use the HTML-to-PDF path: generate a simple HTML string from the summary/transcript and use `WKWebView.createPDF(configuration:)` (available macOS 11+) which handles pagination natively.

For v1, the `WKWebView.createPDF` approach is the most reliable and requires the least AppKit ceremony:

```swift
let webView = WKWebView()
webView.loadHTMLString(htmlContent, baseURL: nil)
// Wait for load, then:
let pdfData = try await webView.pdf(configuration: WKPDFConfiguration())
```

Avoid `ImageRenderer` for anything longer than a single screen.

**Warning signs:**
- PDF export uses `ImageRenderer` with a `GeometryReader` to "fix" the single-page issue
- Exported PDF looks correct for 5-minute test meetings but clips at page 1 for real meetings
- Custom fonts or dark mode colors do not appear in the exported PDF

**Phase to address:**
PDF export phase — choose the export strategy at the outset; `ImageRenderer` is a trap that looks correct in short tests.

---

### Pitfall 7: NavigationSplitView `.prominentDetail` Does Not Work on macOS

**What goes wrong:**
`NavigationSplitViewStyle.prominentDetail` — which hides the sidebar and expands the detail pane to fill the window — does not work on macOS. Using it causes the layout to silently fall back to the default balanced split view. Developers who test on iOS/iPad and then run on macOS find their carefully designed full-detail presentation mode never activates.

**Why it happens:**
Apple's documentation does not prominently flag that `.prominentDetail` is iOS/iPadOS-only. Cross-platform SwiftUI code that uses it "just works" on iOS but silently degrades on macOS.

**How to avoid:**
On macOS, control sidebar visibility via `NavigationSplitViewVisibility` binding and `columnVisibility` instead of `prominentDetail`. To expand the detail pane, set `columnVisibility = .detailOnly`. This is the supported macOS path for collapsing the sidebar programmatically (e.g., when entering full-transcript reading mode).

```swift
@State private var columnVisibility: NavigationSplitViewVisibility = .automatic

NavigationSplitView(columnVisibility: $columnVisibility) {
    SidebarView()
} detail: {
    DetailView()
}

// To collapse sidebar:
Button("Focus") { columnVisibility = .detailOnly }
```

**Warning signs:**
- `.navigationSplitViewStyle(.prominentDetail)` in any view that targets macOS
- A "full reading mode" button that works on simulator (iOS) but has no effect when run on macOS
- Documentation references that say "prominentDetail" without an OS qualifier

**Phase to address:**
Main window / navigation phase — audit all NavigationSplitView style modifiers for macOS compatibility before implementing the detail pane.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Use `WindowGroup` instead of `Window` for main window | Works immediately, familiar API | Multiple window instances appear; "bring to front" logic breaks | Never — use `Window` scene from the start |
| Call `openWindow` without activating the app first | One-line open action | Window appears behind other apps; users assume app is broken | Never for the primary window action |
| Search executes synchronously on `onChange` | Instant results in dev with 3 meetings | Freezes on main thread with 100+ real meetings | Never — always background search |
| Use `ImageRenderer` for PDF export | 10-line implementation | Clips at one page; no environment access; fails on long transcripts | Only for single-screen screenshots, not transcripts |
| Wire live transcript stream directly to view `@State` with no debounce | Simple data binding | Main thread congestion during heavy transcription | Only for prototyping; debounce before shipping |
| In-memory search index only (no SQLite FTS) | Zero extra infrastructure | Adequate for ~500 meetings but sluggish above that | Acceptable for v1; document the threshold |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| `NSApp.activate` from SwiftUI | Calling from a SwiftUI `Button` action that runs on MainActor in `.accessory` policy | Switch activation policy to `.regular` first, then `activate(ignoringOtherApps: true)`, then show window; restore policy if needed on close |
| `WKWebView.createPDF` | Calling before `webView.loadHTMLString` completes navigation | Implement `WKNavigationDelegate.webView(_:didFinish:)` and call `createPDF` only from there |
| `NSMetadataQuery` for spotlight search | Running query on main thread; missing `NSMetadataQueryDidFinishGatheringNotification` observer setup | Schedule query on a background queue; observe both `DidUpdate` and `DidFinishGathering` notifications |
| `NavigationSplitView` on macOS 15 | Using `NavigationPath` (for stack navigation) inside the detail column | `NavigationPath` is for `NavigationStack`, not for split view detail columns; use `@State` selection binding on the split view itself |
| FileManager directory enumeration | Enumerating `~/Documents/OpenOats/` synchronously on the main thread at app launch | Load meeting list in a background `Task` on first appear; cache results in a `@MainActor` observable store |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Loading all transcript files at app launch | Slow launch with 6+ months of meetings; spinning beach ball | Lazy-load transcript content only when a meeting row is selected | At ~50 meetings on slow HDDs; immediate on network volumes |
| Re-filtering entire meeting list on every search keystroke with no debounce | Search field lags; sidebar flickers on every character | 250ms debounce + background Task for all file I/O | Immediately visible with >20 meetings |
| Live transcript `ScrollView` scrolls on every utterance | Visible scroll jank; sidebar list stutters during recording | Scroll only when the last utterance's id changes (not on every append) and only if auto-scroll is enabled | With fast speech and >50 utterances on screen |
| `PDFView` (from PDFKit) inside a SwiftUI `ScrollView` | PDFView disappears inside ScrollView; scrolling stops working | PDFKit's `PDFView` cannot be placed inside a SwiftUI `ScrollView` — use `NSViewRepresentable` with its own scroll behavior | Always — this is a structural incompatibility |
| `WKWebView` for PDF generation holds a strong reference in a `@State` | Memory never freed after export | Store WKWebView in a local variable, not in `@State`; let it dealloc after PDF data is captured | In apps that export many PDFs in a session |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Exposing the full transcript file path in URL scheme or pasteboard | Another app could read raw audio transcripts containing PII | Share only the meeting ID or a bookmark; resolve paths only within the app sandbox |
| PDF saved to a world-readable tmp directory | Other apps can read exported PDFs before user saves them | Use `NSSavePanel` to let the user choose the destination; avoid writing to `/tmp` as an intermediate step |
| Displaying raw file paths in the UI | Users see absolute paths like `/Users/vcartier/Documents/...`; leaks home directory username | Display relative or display-name paths only in the UI |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Main window opens but keyboard focus stays in the previously active app | User starts typing a search query and nothing happens | Always call `NSApp.activate` + `makeKeyAndOrderFront` in sequence when opening the window |
| No `ContentUnavailableView` when meeting list is empty | Blank white sidebar on first launch looks like a loading failure | Show a "No meetings yet — start recording to see transcripts here" empty state in both the list and the detail pane |
| Sidebar selection resets to nil when window regains focus | User loses their place every time they switch apps | Persist `selectedMeetingID` in `@AppStorage` or `@State` at the app coordinator level, not locally in the view |
| Search clears when switching away and back to the window | User loses their search context | Store `searchText` in a `@State` tied to the window's scene, not embedded deep in the list view |
| PDF export saves to an undiscoverable location | User cannot find the exported PDF | Always use `NSSavePanel` — never silently export to Documents or Desktop without confirmation |
| Live transcript appends cause the whole detail pane to re-render | Text flickers during active recording | Use `id:` on `ForEach` with stable meeting-line IDs, not array indices |

---

## "Looks Done But Isn't" Checklist

- [ ] **Window singleton:** Open the main window, switch to another app, click the menu bar "Open MeetingScribe" link again — verify only one window exists and it comes to the front (not a second window)
- [ ] **Window focus:** Open the main window while Safari is in the foreground — verify the window actually has keyboard focus and search works immediately
- [ ] **Live transcript in window:** Start a recording with the main window open — verify the sidebar list stays responsive and scrolls to the latest utterance without visual jank
- [ ] **Search with real data:** Test search with 50+ synthetic meeting files — verify the UI does not freeze and results appear within 500ms
- [ ] **PDF export length:** Export a PDF from a 90-minute meeting — verify it is multi-page and not clipped at page 1
- [ ] **PDF export content:** Open the exported PDF and verify it contains both the summary and the full transcript, not a screenshot of the current view
- [ ] **NavigationSplitView selection:** Click a meeting in the sidebar — verify the row is highlighted and remains highlighted when switching focus to the detail pane
- [ ] **Empty state:** Launch the app with no meetings (clean Documents folder) — verify both sidebar and detail pane show informative empty states, not blank white

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| `WindowGroup` used instead of `Window` — multiple windows ship | MEDIUM | Replace scene type; add "close extra windows" logic on app activate; single-release migration |
| Main thread search freeze discovered post-ship | LOW | Wrap search in background Task with debounce; ships as a patch; no data model change |
| `ImageRenderer` PDF single-page clipping discovered post-ship | MEDIUM | Replace export implementation with `WKWebView.createPDF`; no data model change, but UX flow may need updating |
| Live transcript jank discovered during demo | LOW | Add debounce/batching to transcript update path; isolated change in one view |
| Window activation policy misconfiguration causing windows not to focus | LOW | Correct activation sequence in the "Open" button action; isolated fix |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| WindowGroup spawns multiple instances (Pitfall 1) | Main window phase — scene type selection | Open window twice; confirm only one window exists |
| Window appears behind other apps (Pitfall 2) | Main window phase — menu bar open action | Open window while another app is focused; confirm window receives focus |
| NavigationSplitView selection not bound (Pitfall 3) | Main window / sidebar phase — List setup | Click any meeting row; confirm row is highlighted and stays highlighted |
| Live transcript blocks main thread (Pitfall 4) | Main window / live transcript phase | Profile in Instruments during active recording; confirm no main thread spikes |
| Full-text search blocks main thread (Pitfall 5) | Search phase — SearchService architecture | Run search with 50 meetings; confirm UI stays responsive |
| PDF export clips at one page (Pitfall 6) | PDF export phase — export strategy selection | Export 90-min meeting PDF; confirm multi-page output |
| `.prominentDetail` silent no-op on macOS (Pitfall 7) | Main window / navigation phase — style modifier audit | Test detail-only mode on macOS; confirm sidebar actually collapses |

---

## Sources

- [Peter Steinberger: Showing Settings from macOS Menu Bar Items — A 5-Hour Journey (2025)](https://steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items) — activation policy juggling, timing issues, `openSettings` regression on macOS 26
- [SwiftUI for Mac 2025 — TrozWare](https://troz.net/post/2025/swiftui-mac-2025/) — current state of SwiftUI macOS, `List` performance with 10K+ items
- [Apple Developer Forums: SwiftUI NavigationSplitView on macOS](https://developer.apple.com/forums/thread/746611) — selection binding requirements and known issues
- [Why Every NavigationSplitView Tutorial Failed Me — Medium](https://medium.com/@careful_celadon_goldfish_904/why-every-navigation-split-view-tutorial-failed-me-and-how-i-fixed-it-32a0bbeb16c2) — missing selection binding, layout vertical-space bug
- [Apple Developer Forums: Multipage PDF with PDFKit on macOS](https://developer.apple.com/forums/thread/712377) — pagination management, NSPrintOperation path
- [Eclectic Light: SwiftUI on macOS — text, rich text, markdown, HTML and PDF views (2024)](https://eclecticlight.co/2024/05/07/swiftui-on-macos-text-rich-text-markdown-html-and-pdf-views/) — `PDFView` inside ScrollView incompatibility
- [Apple Developer Forums: In macOS App, ImageRenderer writes…](https://developer.apple.com/forums/thread/736400) — `ImageRenderer` single-page and environment isolation limitations
- [Creating a Debounced Search Context for Performant SwiftUI Searches (2025)](https://danielsaidi.com/blog/2025/01/08/creating-a-debounced-search-context-for-performant-swiftui-searches) — debounce implementation pattern
- [Exploring SwiftUI Learnings and Bugs with .searchable — Medium](https://medium.com/@snowham/exploring-swiftui-learnings-and-bugs-with-searchable-c5110995c80e) — `.searchable` resource leak and cancellation issues
- [Scenes Types in a SwiftUI Mac App — NilCoalescing](https://nilcoalescing.com/blog/ScenesTypesInASwiftUIMacApp/) — `Window` vs `WindowGroup` single-instance behavior
- [Fine-Tuning macOS App Activation Behavior — artlasovsky.com](https://artlasovsky.com/fine-tuning-macos-app-activation-behavior) — activation policy `.accessory` vs `.regular` window focus behavior

---
*Pitfalls research for: macOS app window milestone — main window, NavigationSplitView, full-text search, PDF export (OpenOats fork / MeetingScribe)*
*Researched: 2026-03-21*
