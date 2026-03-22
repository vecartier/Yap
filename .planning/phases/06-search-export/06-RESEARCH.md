# Phase 6: Search + Export - Research

**Researched:** 2026-03-22
**Domain:** SwiftUI `.searchable` + in-memory text scanning + NSPrintOperation PDF export on macOS 15 / Swift 6.2
**Confidence:** HIGH (all decisions are native Apple frameworks; existing codebase verified directly)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **Search scope:** Titles + transcript text + summary text (all three)
- **Search bar:** SwiftUI `.searchable` modifier — native macOS search in sidebar toolbar
- **Filtering:** Real-time sidebar filtering as user types
- **Background thread with debounce** — don't block UI (locked from requirements)
- **No results:** Standard empty state in sidebar when search matches nothing
- **Content:** Metadata header + summary (if exists) + full transcript — complete meeting record
- **No user choice at export** — always exports the full record
- **Multi-page pagination** via NSPrintOperation (NOT ImageRenderer) — locked from research
- **Export trigger:** Button in the PastMeetingDetailView (alongside Slack copy button)

### Claude's Discretion
- Search debounce interval (200-500ms typical)
- How transcript/summary content is loaded for search (lazy load vs index on launch)
- PDF styling (fonts, margins, header formatting)
- Export button placement and icon
- "No results" empty state design
- Whether to highlight search matches in the sidebar rows

### Deferred Ideas (OUT OF SCOPE)
None — final v1 phase. All v2 features (calendar, templates, Slack auto-send) captured in PROJECT.md backlog.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SRCH-01 | Full-text search across all past transcripts and summaries | `localizedStandardContains` on in-memory `[SessionIndex]` titles + lazy-loaded transcript and summary text via a `SearchService` actor |
| SRCH-02 | Search runs on background thread with debounce (not blocking UI) | `Task.cancel()` + `Task.sleep(for: .milliseconds(250))` debounce pattern; all file I/O inside a detached actor |
| SRCH-03 | Search filters the sidebar meeting list in real-time | `.searchable(text: $searchQuery)` on `MeetingSidebarView`; `filteredSessions` replaces `coordinator.sessionHistory` as the data source for `groupedSessions()` |
| EXPRT-01 | User can export a meeting to PDF (summary + transcript) | `PDFExporter` struct: compose `NSAttributedString` from `SummaryEngine.PersistedSummary` + `[SessionRecord]`, write via `NSPrintOperation.pdfOperation`; `NSSavePanel` for user-chosen destination |
| EXPRT-02 | PDF uses NSPrintOperation for proper multi-page pagination (not ImageRenderer) | `NSPrintOperation.pdfOperation(with:inside:to:printInfo:)` on an off-screen `NSTextView`; `showsPrintPanel = false`, pagination automatic via `NSLayoutManager` |
</phase_requirements>

---

## Summary

Phase 6 adds two independent features — full-text search and PDF export — to a complete macOS app with 203 tests. Both features are self-contained and do not change any existing data models or coordination layer.

Search is wired through the existing `MeetingSidebarView` by adding SwiftUI `.searchable` and routing the query into a new `SearchService` actor. The actor loads transcript JSONL and summary Markdown files for matched sessions on a background thread, caches results, and debounces at 250ms. The only change to existing grouping logic is that `groupedSessions()` receives the filtered array rather than `coordinator.sessionHistory` directly.

PDF export is a new `PDFExporter` struct (pure function: inputs in, `NSAttributedString` out) paired with an `NSSavePanel` invocation in `PastMeetingDetailView`. The NSPrintOperation path writes a paginated PDF silently to a user-chosen URL with no print dialog. All content already exists in the view (`summaryState`, `rows`, `sessionHistory`); the exporter simply repackages it.

**Primary recommendation:** Implement `SearchService` as a Swift actor (background isolation for free), debounce with cancellable `Task`, and keep PDF composition fully separated from NSPrintOperation plumbing in a `PDFExporter` struct. Both features are independently testable free functions / structs following the Phase 2-5 pattern.

---

## Standard Stack

### Core
| Technology | Version | Purpose | Why Standard |
|------------|---------|---------|--------------|
| SwiftUI `.searchable(text:placement:prompt:)` | macOS 12+ / built-in | Native search field in sidebar toolbar | Already in project STACK.md as the locked choice. Renders as a Spotlight-style field in the sidebar column toolbar. Returns `@Binding<String>`. HIGH confidence — official docs. |
| `String.localizedStandardContains(_:)` | Foundation / built-in | Case-insensitive, locale-aware substring match | Correct choice over `.contains()` (case-sensitive) or NSPredicate (requires Core Data). Already identified in STACK.md. HIGH confidence. |
| `NSPrintOperation.pdfOperation(with:inside:to:printInfo:)` | AppKit / macOS 10.0+ | Multi-page PDF generation from NSTextView | Locked decision from prior research. Handles pagination via NSLayoutManager. `showsPrintPanel = false` writes silently. HIGH confidence — Apple Developer Forums + official docs. |
| `NSAttributedString` / `NSFont` / `NSParagraphStyle` | AppKit / Foundation | Styled text content for PDF body | Bridge between Swift strings and NSTextView. AppKit types (NSFont, NSColor) required on macOS — not UIKit equivalents. HIGH confidence. |
| `NSSavePanel` with `allowedContentTypes: [.pdf]` | AppKit / macOS 11+ (UTType) | User-facing "Save As" dialog | Standard macOS file save. Use `UTType.pdf` (requires `import UniformTypeIdentifiers`). `allowedFileTypes` (NSString-based) is deprecated — use `allowedContentTypes`. HIGH confidence. |
| `ContentUnavailableView` | SwiftUI / macOS 14+ | "No search results" empty state | App already targets macOS 15+. Correct empty state primitive for filtered lists. HIGH confidence. |

### Supporting
| Component | Purpose | When to Use |
|-----------|---------|-------------|
| `Task` cancellation + `Task.sleep` | Debounce search on each keystroke | Cancel the previous search task on every `onChange`, sleep 250ms, then proceed — standard Swift Concurrency debounce pattern. No Combine needed. |
| `actor SearchService` | Background isolation for file I/O during search | Owns the in-memory search cache (`[String: String]` sessionID → transcript text). All file reads happen on this actor, never on MainActor. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `NSPrintOperation.pdfOperation` | `WKWebView.createPDF` | WKWebView approach works but requires HTML generation, WKNavigationDelegate boilerplate, and off-main-thread timing. NSPrintOperation is more direct for plain-text content with known structure. CONTEXT.md locked NSPrintOperation. |
| In-memory search with file I/O on demand | Pre-index all transcripts at launch | Pre-indexing at launch adds startup latency. Lazy loading on search with a cache is O(searches) not O(all sessions). Appropriate for personal-tool session counts. |
| `Task` + `Task.sleep` debounce | Combine `.debounce` | Combine is not used elsewhere in the project. Swift Concurrency task cancellation achieves the same result without a new pattern. |

### Installation
No new Swift Package Manager dependencies required.
All APIs — `.searchable`, `NSPrintOperation`, `NSSavePanel`, `NSTextView`, `NSAttributedString` — are built into SwiftUI, AppKit, and Foundation which are already linked.

---

## Architecture Patterns

### Recommended Project Structure — New Files

```
Sources/OpenOats/
├── Search/
│   └── SearchService.swift          # actor; background text scanning + cache
├── Export/
│   └── PDFExporter.swift            # struct; NSAttributedString composition + NSPrintOperation
└── Views/
    └── MeetingSidebarView.swift     # MODIFIED: add .searchable + filteredSessions
    └── PastMeetingDetailView.swift  # MODIFIED: add "Export PDF" button
```

### Pattern 1: SearchService Actor + Debounced Task

The search query flows from `.searchable` → `@State var searchQuery` → `onChange` → a cancellable `Task` that debounces 250ms → `SearchService.search(query:sessions:)`.

```swift
// In MeetingSidebarView (or a lightweight SearchViewModel ObservableObject)
@State private var searchQuery = ""
@State private var searchTask: Task<Void, Never>?
@State private var filteredSessions: [SessionIndex] = []

// Source: Swift Concurrency task cancellation debounce pattern
.onChange(of: searchQuery) { _, query in
    searchTask?.cancel()
    guard !query.isEmpty else {
        filteredSessions = coordinator.sessionHistory
        return
    }
    searchTask = Task {
        try? await Task.sleep(for: .milliseconds(250))
        guard !Task.isCancelled else { return }
        let results = await searchService.search(query: query,
                                                 sessions: coordinator.sessionHistory,
                                                 store: coordinator.sessionStore,
                                                 notesFolderPath: settings.notesFolderPath)
        await MainActor.run { filteredSessions = results }
    }
}
```

**Key detail:** `filteredSessions` replaces `coordinator.sessionHistory` as the argument to `groupedSessions()`. When `searchQuery.isEmpty`, `filteredSessions == coordinator.sessionHistory`. This keeps `groupedSessions()` unchanged (existing free function, 9 tests passing).

### Pattern 2: SearchService Actor

```swift
// Source: Swift actor isolation; SessionStore.loadTranscript pattern
actor SearchService {
    // Cache: sessionID → concatenated searchable text (title + transcript + summary)
    private var cache: [String: String] = [:]

    func search(
        query: String,
        sessions: [SessionIndex],
        store: SessionStore,
        notesFolderPath: String
    ) async -> [SessionIndex] {
        return await withTaskGroup(of: (SessionIndex, Bool).self) { group in
            for session in sessions {
                group.addTask {
                    let text = await self.searchableText(for: session, store: store, notesFolderPath: notesFolderPath)
                    let matches = text.localizedStandardContains(query)
                    return (session, matches)
                }
            }
            var results: [SessionIndex] = []
            for await (session, matches) in group where matches {
                results.append(session)
            }
            // Re-sort to match original history order (by startedAt descending)
            return results.sorted { $0.startedAt > $1.startedAt }
        }
    }

    private func searchableText(
        for session: SessionIndex,
        store: SessionStore,
        notesFolderPath: String
    ) async -> String {
        if let cached = cache[session.id] { return cached }

        var parts: [String] = []
        // Title
        if let title = session.title { parts.append(title) }
        // Transcript (via SessionStore actor — already actor-isolated)
        let records = await store.loadTranscript(sessionID: session.id)
        let transcriptText = records.map { $0.refinedText ?? $0.text }.joined(separator: " ")
        parts.append(transcriptText)
        // Summary Markdown
        let summaryURL = URL(fileURLWithPath: notesFolderPath)
            .appendingPathComponent("\(session.id)-summary.md")
        if let summaryText = try? String(contentsOf: summaryURL, encoding: .utf8) {
            parts.append(summaryText)
        }

        let combined = parts.joined(separator: " ")
        cache[session.id] = combined
        return combined
    }

    /// Evict cache entry when a new summary is generated.
    func evictCache(sessionID: String) {
        cache.removeValue(forKey: sessionID)
    }

    /// Full cache clear (e.g., on memory pressure or app background).
    func clearCache() {
        cache.removeAll()
    }
}
```

**Cache eviction:** After `SummaryEngine` finishes generating a summary, call `searchService.evictCache(sessionID:)` so the next search picks up the new summary text. The `AppCoordinator` already sets `summaryCache[sessionID]` — hook eviction there.

### Pattern 3: PDFExporter + NSPrintOperation

```swift
// Source: STACK.md, NSPrintOperation.pdfOperation official docs
struct PDFExporter {

    struct Content {
        let session: SessionIndex
        let summary: SummaryEngine.PersistedSummary?
        let records: [SessionRecord]
    }

    /// Compose content and write to fileURL. Call from a background Task.
    @discardableResult
    static func export(_ content: Content, to fileURL: URL) -> Bool {
        let attrStr = compose(content)

        let printInfo = NSPrintInfo.shared.mutableCopy() as! NSPrintInfo
        printInfo.paperSize = NSSize(width: 612, height: 792)   // US Letter points
        printInfo.leftMargin = 72
        printInfo.rightMargin = 72
        printInfo.topMargin = 72
        printInfo.bottomMargin = 72
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .auto
        printInfo.jobDisposition = .save

        let pageWidth = 612 - 72 - 72   // 468pt
        let pageHeight = 792 - 72 - 72  // 648pt
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        textView.textStorage?.setAttributedString(attrStr)

        let op = NSPrintOperation.pdfOperation(
            with: textView,
            inside: textView.bounds,
            to: fileURL,
            printInfo: printInfo
        )
        op.showsPrintPanel = false
        op.showsProgressPanel = false
        return op.run()
    }

    // MARK: - Content composition

    private static func compose(_ content: Content) -> NSAttributedString {
        let result = NSMutableAttributedString()

        // --- Header: Title ---
        let titleFont = NSFont.boldSystemFont(ofSize: 20)
        let title = content.session.title ?? "Meeting"
        result.append(NSAttributedString(
            string: title + "\n\n",
            attributes: [.font: titleFont, .foregroundColor: NSColor.labelColor]
        ))

        // --- Metadata badges ---
        let metaFont = NSFont.systemFont(ofSize: 12)
        let metaColor = NSColor.secondaryLabelColor
        var meta = formattedDate(content.session.startedAt)
        if let endedAt = content.session.endedAt {
            meta += "   " + formattedDuration(from: content.session.startedAt, to: endedAt)
        }
        meta += "   " + meetingType(for: content.session)
        result.append(NSAttributedString(
            string: meta + "\n\n",
            attributes: [.font: metaFont, .foregroundColor: metaColor]
        ))

        // --- Summary sections (if available) ---
        if let summary = content.summary {
            let sectionFont = NSFont.boldSystemFont(ofSize: 13)
            let bodyFont = NSFont.systemFont(ofSize: 13)
            for (heading, items) in [
                ("Key Decisions", summary.decisions),
                ("Action Items", summary.actionItems),
                ("Discussion Points", summary.discussionPoints),
                ("Open Questions", summary.openQuestions)
            ] {
                result.append(NSAttributedString(
                    string: heading + "\n",
                    attributes: [.font: sectionFont, .foregroundColor: NSColor.labelColor]
                ))
                if items.isEmpty {
                    result.append(NSAttributedString(
                        string: "  None recorded\n",
                        attributes: [.font: bodyFont, .foregroundColor: metaColor]
                    ))
                } else {
                    for item in items {
                        result.append(NSAttributedString(
                            string: "  \u{2022} \(item)\n",
                            attributes: [.font: bodyFont, .foregroundColor: NSColor.labelColor]
                        ))
                    }
                }
                result.append(NSAttributedString(string: "\n"))
            }
        }

        // --- Divider (em-dashes) ---
        result.append(NSAttributedString(
            string: String(repeating: "\u{2014}", count: 40) + "\n\n",
            attributes: [.font: NSFont.systemFont(ofSize: 10), .foregroundColor: metaColor]
        ))

        // --- Transcript ---
        let transcriptTitleFont = NSFont.boldSystemFont(ofSize: 14)
        result.append(NSAttributedString(
            string: "Transcript\n\n",
            attributes: [.font: transcriptTitleFont, .foregroundColor: NSColor.labelColor]
        ))
        let lineFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        for record in content.records {
            let speaker = speakerLabel(for: record.speaker)
            let text = record.refinedText ?? record.text
            result.append(NSAttributedString(
                string: "[\(speaker)]  \(text)\n",
                attributes: [.font: lineFont, .foregroundColor: NSColor.labelColor]
            ))
        }

        return result
    }

    // Helpers (mirror PastMeetingDetailView private helpers)
    private static func formattedDate(_ date: Date) -> String { ... }
    private static func formattedDuration(from: Date, to: Date) -> String { ... }
    private static func meetingType(for session: SessionIndex) -> String { ... }
    private static func speakerLabel(for speaker: Speaker) -> String { ... }
}
```

### Pattern 4: Export Button in PastMeetingDetailView

```swift
// Add alongside the existing slackActionsRow
private var exportActionsRow: some View {
    HStack(spacing: 8) {
        // Existing Slack button (unchanged)
        Button("Copy for Slack", systemImage: "doc.on.clipboard") { copyForSlack() }
            .buttonStyle(.bordered)
            .disabled(!canCopySlack)
            .help(canCopySlack ? "Copy Slack-formatted summary" : "Summary required")

        // New export button
        Button("Export PDF", systemImage: "arrow.down.doc") { exportPDF() }
            .buttonStyle(.bordered)
    }
}

private func exportPDF() {
    guard let session = coordinator.sessionHistory.first(where: { $0.id == sessionID }) else { return }

    // Extract summary if ready
    let summary: SummaryEngine.PersistedSummary?
    if case .ready(let persisted) = summaryState { summary = persisted } else { summary = nil }

    // Snapshot transcript rows (already loaded)
    let records = rows.map { $0.0 }

    Task { @MainActor in
        // Show save panel on main thread
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        let filename = (session.title ?? "Meeting")
            .replacingOccurrences(of: "/", with: "-")
        panel.nameFieldStringValue = "\(filename).pdf"
        panel.directoryURL = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first

        guard await panel.beginSheetModal(for: NSApp.keyWindow ?? NSWindow()) == .OK,
              let url = panel.url else { return }

        let content = PDFExporter.Content(session: session, summary: summary, records: records)
        // Run export off main thread
        Task.detached(priority: .userInitiated) {
            PDFExporter.export(content, to: url)
        }
    }
}
```

### Pattern 5: .searchable Modifier Placement

`.searchable` must be placed on the `NavigationSplitView` sidebar column or on the `List` inside it. In `MeetingSidebarView`, attaching it to the `List` is the correct target — it places the search field in the column's toolbar:

```swift
// In MeetingSidebarView.body — inside List modifier chain
List(selection: $selectedSessionID) { ... }
    .listStyle(.sidebar)
    .searchable(text: $searchQuery, placement: .sidebar, prompt: "Search meetings")
    .task { await coordinator.loadHistory() }
```

`searchQuery` can live in `MeetingSidebarView` as `@State` with a `searchTask` cancellation handle. `filteredSessions` is a local `@State` updated asynchronously.

### Anti-Patterns to Avoid

- **Synchronous search in onChange:** Never call `SessionStore.loadTranscript` synchronously inside `onChange(of: searchQuery)`. It is a blocking file read on the main thread. Always wrap in `Task`.
- **ImageRenderer for PDF:** Clips to one page. Env isolation breaks custom fonts. Not under consideration — locked to NSPrintOperation.
- **Storing WKWebView in @State for PDF:** Memory leak. Not applicable (using NSPrintOperation), documented here for completeness.
- **Searching sessionHistory directly without filteredSessions state:** If `filteredSessions` is a computed `var` re-evaluated on every render, it will trigger on every coordinator observation change. Use `@State` updated asynchronously.
- **Passing NSSavePanel URL across actor boundaries without Sendable check:** `URL` is `Sendable`. Safe to capture in `Task.detached`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Text pagination in PDF | Manual page-height tracking with CTFrame/CTLine | `NSTextView` + `NSPrintOperation` | NSLayoutManager handles wrapping, pagination, line metrics automatically. Manual pagination is 300+ lines and still has edge cases. |
| Case-insensitive search | `.lowercased().contains()` | `localizedStandardContains` | `.lowercased()` is not locale-aware. `localizedStandardContains` handles diacritics (café vs cafe), is case-insensitive, and matches user expectations. |
| Search debounce timer | `DispatchSourceTimer` | `Task.cancel()` + `Task.sleep` | Swift Concurrency task cancellation is the idiomatic pattern in a Swift 6.2 codebase. DispatchSourceTimer requires manual invalidation and is error-prone under actor isolation. |
| PDF file type restriction in save panel | Custom file extension string | `UTType.pdf` from `UniformTypeIdentifiers` | `allowedFileTypes = ["pdf"]` is the deprecated API. `allowedContentTypes = [.pdf]` is the macOS 11+ standard. |

**Key insight:** The NSPrintOperation + NSTextView combination is a mature AppKit text layout system. The complexity of multi-page text export is fully handled by `NSLayoutManager` once the `NSAttributedString` content is assembled. The custom work is only the content composition (pure string/attribute logic) — testable in isolation.

---

## Common Pitfalls

### Pitfall 1: Full-Text Search Blocks Main Thread (from PITFALLS.md)
**What goes wrong:** `SessionStore.loadTranscript` reads JSONL files from disk. Calling it inside `onChange(of: searchQuery)` directly blocks the main thread. With 100+ past meetings this freezes the search field.
**Why it happens:** It looks like a simple filter. File size is invisible in dev with 3 test meetings.
**How to avoid:** All text loading inside `SearchService` actor. Debounce 250ms with Task cancellation. `filteredSessions` updated via `MainActor.run` only after async work completes.
**Warning signs:** Search results appear instantly in testing (only 3 test files exist). No `Task { }` wrapper around file reads.

### Pitfall 2: PDF Clips at One Page (from PITFALLS.md)
**What goes wrong:** Any attempt to use `ImageRenderer` produces a single-page PDF. A 60-minute meeting transcript (hundreds of lines) appears truncated.
**Why it happens:** `ImageRenderer` renders a view once into one CGContext page. Not applicable if NSPrintOperation is used — documenting because the pitfall exists project-wide.
**How to avoid:** NSPrintOperation path is locked. Do not deviate.
**Warning signs:** Not applicable here — NSPrintOperation is the locked choice.

### Pitfall 3: NSSavePanel Must Run on MainActor
**What goes wrong:** `NSSavePanel.runModal()` or `beginSheetModal(for:)` called from a detached Task (off main thread) causes AppKit assertion failure.
**Why it happens:** AppKit UI components require main thread. `Task.detached` does not inherit MainActor.
**How to avoid:** Show `NSSavePanel` inside `Task { @MainActor in ... }`. After getting the URL, spawn `Task.detached` for the actual PDF write (NSPrintOperation is thread-safe for PDF file output).
**Warning signs:** `beginSheetModal` called directly inside `Task.detached`.

### Pitfall 4: NSPrintOperation Mutates NSPrintInfo.shared
**What goes wrong:** `NSPrintInfo.shared` is a global object. Mutating it directly (setting paper size, margins) affects any subsequent print operations in the session.
**Why it happens:** Convenience — it's the first API surface developers reach for.
**How to avoid:** Always call `NSPrintInfo.shared.mutableCopy() as! NSPrintInfo` and configure the copy. Pass that copy to `NSPrintOperation.pdfOperation(with:inside:to:printInfo:)`.
**Warning signs:** `printInfo.paperSize = ...` without a prior `mutableCopy()`.

### Pitfall 5: .searchable Text Clears on NavigationSplitView Column Switch
**What goes wrong:** If `searchQuery` is stored as `@State` inside a view that gets re-created when sidebar selection changes, the search text resets.
**Why it happens:** SwiftUI destroys and recreates views when their identity changes. `@State` inside `MeetingSidebarView` tied to selection identity may clear.
**How to avoid:** Store `searchQuery` as `@State` in `MeetingSidebarView` directly (which is always present in the sidebar column) — not in the detail view or in any view that depends on `selectedSessionID`. The sidebar column is persistent; `@State` there survives selection changes.
**Warning signs:** Search text resets when the user clicks a different meeting.

### Pitfall 6: Search Cache Returns Stale Results After Summary Generation
**What goes wrong:** A search for a keyword in a newly generated summary finds no results because the cache entry was built before the summary file existed.
**Why it happens:** Summary is generated asynchronously after session end. The cache entry for that session was built before the file was written.
**How to avoid:** When `AppCoordinator` sets `summaryCache[sessionID] = .ready(...)`, also call `searchService.evictCache(sessionID: sessionID)`. Next search for that session will re-read the fresh summary file.
**Warning signs:** Search doesn't find words from a summary that was just generated. Manual app restart fixes it (cache is in-memory only).

---

## Code Examples

Verified patterns from existing codebase and official sources:

### Debounced Search Task (Swift Concurrency)
```swift
// Pattern verified in PITFALLS.md (danielsaidi.com debounce, 2025)
@State private var searchTask: Task<Void, Never>?

.onChange(of: searchQuery) { _, query in
    searchTask?.cancel()
    guard !query.isEmpty else {
        filteredSessions = coordinator.sessionHistory
        return
    }
    searchTask = Task {
        try? await Task.sleep(for: .milliseconds(250))
        guard !Task.isCancelled else { return }
        let results = await searchService.search(
            query: query,
            sessions: coordinator.sessionHistory,
            store: coordinator.sessionStore,
            notesFolderPath: settings.notesFolderPath
        )
        await MainActor.run { self.filteredSessions = results }
    }
}
```

### .searchable Modifier on macOS List
```swift
// Source: Apple Developer Documentation — searchable modifier (macOS 12+)
List(selection: $selectedSessionID) { ... }
    .listStyle(.sidebar)
    .searchable(text: $searchQuery, placement: .sidebar, prompt: "Search meetings")
```

### NSPrintOperation PDF Write (from STACK.md, verified pattern)
```swift
// Source: Apple Developer Documentation — NSPrintOperation.pdfOperation
// Source: Apple Developer Forums thread/129642 — showsPrintPanel = false confirmed
let printInfo = NSPrintInfo.shared.mutableCopy() as! NSPrintInfo
printInfo.paperSize = NSSize(width: 612, height: 792)
printInfo.leftMargin = 72; printInfo.rightMargin = 72
printInfo.topMargin = 72;  printInfo.bottomMargin = 72
printInfo.horizontalPagination = .fit
printInfo.verticalPagination = .auto

let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 468, height: 648))
textView.textStorage?.setAttributedString(attributedContent)

let op = NSPrintOperation.pdfOperation(
    with: textView,
    inside: textView.bounds,
    to: fileURL,
    printInfo: printInfo
)
op.showsPrintPanel = false
op.showsProgressPanel = false
op.run()
```

### NSSavePanel on MainActor
```swift
// Source: Apple Developer Documentation — NSSavePanel
// Must run on main thread; UTType.pdf requires: import UniformTypeIdentifiers
import UniformTypeIdentifiers

let panel = NSSavePanel()
panel.allowedContentTypes = [.pdf]
panel.nameFieldStringValue = "Meeting.pdf"
panel.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
let response = await panel.beginSheetModal(for: NSApp.keyWindow ?? NSWindow())
guard response == .OK, let url = panel.url else { return }
```

### ContentUnavailableView for No Results
```swift
// Source: Apple Developer Documentation — ContentUnavailableView (macOS 14+)
// App targets macOS 15+ — safe to use
if filteredSessions.isEmpty && !searchQuery.isEmpty {
    ContentUnavailableView.search(text: searchQuery)
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `allowedFileTypes = ["pdf"]` (NSString array) | `allowedContentTypes = [.pdf]` (UTType) | macOS 11 / Xcode 12 | Old API deprecated; compiler warning if used |
| `NSPrintInfo.shared` mutation directly | `NSPrintInfo.shared.mutableCopy()` then configure | Always best practice | Prevents global print state corruption |
| Combine `.debounce` for search | `Task.cancel()` + `Task.sleep` | Swift 5.5+ concurrency | Idiomatic in Swift 6.2; no Combine dependency needed |

---

## Open Questions

1. **SearchService ownership: MeetingSidebarView @State vs AppCoordinator property**
   - What we know: The search service needs to be alive for the duration of the sidebar. `MeetingSidebarView` is always present while the main window is open.
   - What's unclear: Should `SearchService` be a property on `AppCoordinator` (accessible everywhere) or an `@State` on `MeetingSidebarView`?
   - Recommendation: `@State private var searchService = SearchService()` on `MeetingSidebarView`. It doesn't need to be shared — only the sidebar consumes it. If cache eviction after summary generation is needed, pass `searchService` into `AppCoordinator` via a protocol or just call `searchService.evictCache` from `MeetingSidebarView.onChange(of: coordinator.summaryCache)`.

2. **PDF export button enabled state: always enabled vs requires summary?**
   - What we know: CONTEXT.md says "always exports full record." The transcript is always present once a session exists. Summary is optional.
   - What's unclear: Should the button be disabled if only a transcript exists (no summary), or enabled always?
   - Recommendation: Always enabled. The PDF includes "No summary" placeholder text when `summaryState == nil`. This matches the "no user choice at export" decision.

3. **filteredSessions sync with coordinator.sessionHistory changes**
   - What we know: New sessions can appear in `sessionHistory` mid-search if a recording ends while search is active.
   - What's unclear: Should an in-progress search be re-triggered when `sessionHistory` changes?
   - Recommendation: On `onChange(of: coordinator.sessionHistory)`, if `searchQuery` is non-empty, re-trigger the debounced search task. This ensures new sessions are searchable immediately.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (Swift Testing not yet adopted in this project) |
| Config file | `OpenOats/Package.swift` — target `OpenOatsTests` at `Tests/OpenOatsTests` |
| Quick run command | `cd /Users/vcartier/Desktop/OpenOats-fork/OpenOats && swift test --filter SearchServiceTests 2>&1` |
| Full suite command | `cd /Users/vcartier/Desktop/OpenOats-fork/OpenOats && swift test 2>&1` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SRCH-01 | `SearchService.search` returns sessions matching query in title | unit | `swift test --filter SearchServiceTests/testSearchMatchesTitle` | ❌ Wave 0 |
| SRCH-01 | `SearchService.search` returns sessions matching query in transcript text | unit | `swift test --filter SearchServiceTests/testSearchMatchesTranscript` | ❌ Wave 0 |
| SRCH-01 | `SearchService.search` returns sessions matching query in summary text | unit | `swift test --filter SearchServiceTests/testSearchMatchesSummary` | ❌ Wave 0 |
| SRCH-01 | `SearchService.search` is case-insensitive | unit | `swift test --filter SearchServiceTests/testSearchCaseInsensitive` | ❌ Wave 0 |
| SRCH-02 | Search does not execute until 250ms after last keystroke | unit | `swift test --filter SearchServiceTests/testDebounceDelays` | ❌ Wave 0 — timing test, may need manual verification |
| SRCH-03 | Empty query returns all sessions unfiltered | unit | `swift test --filter SearchServiceTests/testEmptyQueryReturnsAll` | ❌ Wave 0 |
| SRCH-03 | Query with no matches returns empty array | unit | `swift test --filter SearchServiceTests/testNoMatchReturnsEmpty` | ❌ Wave 0 |
| EXPRT-01 | `PDFExporter.compose` includes meeting title in output | unit | `swift test --filter PDFExporterTests/testCompositeContainsTitle` | ❌ Wave 0 |
| EXPRT-01 | `PDFExporter.compose` includes summary sections when summary present | unit | `swift test --filter PDFExporterTests/testCompositeIncludesSummary` | ❌ Wave 0 |
| EXPRT-01 | `PDFExporter.compose` omits summary section gracefully when nil | unit | `swift test --filter PDFExporterTests/testCompositeHandlesNoSummary` | ❌ Wave 0 |
| EXPRT-01 | `PDFExporter.compose` includes transcript lines | unit | `swift test --filter PDFExporterTests/testCompositeIncludesTranscript` | ❌ Wave 0 |
| EXPRT-02 | `PDFExporter.export` writes a non-empty file to the given URL | unit | `swift test --filter PDFExporterTests/testExportWritesFile` | ❌ Wave 0 |
| EXPRT-02 | Exported file begins with PDF magic bytes `%PDF` | unit | `swift test --filter PDFExporterTests/testExportIsPDFFormat` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `swift test --filter SearchServiceTests && swift test --filter PDFExporterTests`
- **Per wave merge:** `cd /Users/vcartier/Desktop/OpenOats-fork/OpenOats && swift test`
- **Phase gate:** Full suite green (203 existing + new tests) before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `Tests/OpenOatsTests/SearchServiceTests.swift` — covers SRCH-01, SRCH-03
- [ ] `Tests/OpenOatsTests/PDFExporterTests.swift` — covers EXPRT-01, EXPRT-02
- [ ] `Sources/OpenOats/Search/SearchService.swift` — new actor
- [ ] `Sources/OpenOats/Export/PDFExporter.swift` — new struct

*(SRCH-02 debounce timing test: unit test can verify the 250ms sleep value is configured correctly; actual timing behavior is manual-only since XCTest async timing is flaky at sub-second granularity.)*

---

## Integration Checklist for Planner

The following existing files need targeted changes. No existing logic is deleted or restructured.

| File | Change | Risk |
|------|--------|------|
| `MeetingSidebarView.swift` | Add `@State searchQuery`, `@State filteredSessions`, `searchTask`, `SearchService` instance; attach `.searchable`; replace `coordinator.sessionHistory` with `filteredSessions` in `groupedSessions()` call; add `ContentUnavailableView` for empty results | LOW — `groupedSessions` free function unchanged; List binding unchanged |
| `PastMeetingDetailView.swift` | Add `exportPDF()` method; add "Export PDF" button in `slackActionsRow` (rename to `actionsRow`) | LOW — no existing logic changed |
| `AppCoordinator.swift` | No changes required. `SearchService` is owned by the sidebar. Optional: evict cache entry when summary completes (minor hook). | NONE / LOW |
| `MainAppView.swift` | No changes required | NONE |

---

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation — `.searchable` modifier (macOS 12+): https://developer.apple.com/documentation/swiftui/view/searchable(text:placement:prompt:)-18a8f
- Apple Developer Documentation — `NSPrintOperation.pdfOperation`: https://developer.apple.com/documentation/appkit/nsprintoperation/1529269-pdfoperation
- Apple Developer Documentation — `NSSavePanel`: https://developer.apple.com/documentation/appkit/nssavepanel
- Apple Developer Documentation — `ContentUnavailableView.search`: https://developer.apple.com/documentation/swiftui/contentunavailableview/search(text:)
- Existing codebase (`MeetingSidebarView.swift`, `PastMeetingDetailView.swift`, `SessionStore.swift`, `SummaryEngine.swift`, `Models.swift`) — verified directly
- `.planning/research/STACK.md` — full NSPrintOperation flow, localizedStandardContains rationale
- `.planning/research/PITFALLS.md` — search main-thread pitfall, ImageRenderer pitfall

### Secondary (MEDIUM confidence)
- Apple Developer Forums thread/129642 — `showsPrintPanel = false` pattern confirmed for silent PDF write
- danielsaidi.com "Creating a Debounced Search Context for Performant SwiftUI Searches" (2025) — `Task.cancel()` + `Task.sleep` debounce pattern

### Tertiary (LOW confidence)
- None identified for this phase

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all APIs are native Apple frameworks, verified in STACK.md and official docs
- Architecture: HIGH — integration points verified against actual source files; patterns follow existing Phase 2–5 conventions (free functions, actor isolation, one-type-per-file)
- Pitfalls: HIGH — derived from PITFALLS.md (verified research) plus two new AppKit-specific pitfalls found by code inspection

**Research date:** 2026-03-22
**Valid until:** 2026-09-22 (stable Apple framework APIs; no expiry risk for 6 months)
