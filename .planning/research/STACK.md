# Stack Research

**Domain:** macOS meeting companion — main app window, meeting history, search, PDF export, settings
**Researched:** 2026-03-21
**Confidence:** HIGH (all core decisions are native Apple frameworks with stable APIs)

---

## Context: What Already Exists (Do NOT Re-Introduce)

This milestone extends an existing Swift 6.2 / macOS 15+ app. The existing stack is locked:

- **Audio capture:** FluidAudio 0.7.9 + Core Audio process taps
- **Transcription:** WhisperKit 0.9.0 + FluidAudio (Parakeet, Whisper, Qwen3)
- **LLM client:** Custom `OpenRouterClient` — OpenAI-compatible streaming via URLSession
- **Notes / Summary layer:** `NotesEngine` + `SummaryEngine` (structured JSON summaries)
- **Storage:** JSONL session logs (`SessionStore`) + plain text transcripts (`TranscriptLogger`) + Markdown notes files — all file-system, no database
- **Session index:** `SessionIndex` / `SessionSidecar` Codable structs, list maintained in `AppCoordinator.sessionHistory`
- **Settings model:** `AppSettings` with Keychain-backed API keys
- **App lifecycle:** `OpenOatsRootApp` with `Window("main")` + `Window("notes")` + `Settings` scenes
- **History window:** `NotesView` — basic HStack(sidebar + detail), separate `Window("notes")` scene
- **Dependencies:** FluidAudio, Sparkle 2.7.0, WhisperKit, LaunchAtLogin-Modern
- **Constraint from PROJECT.md:** "No new dependencies" — URLSession for network, existing Keychain for secrets

The research below covers **only what the milestone adds**: main window redesign, history browsing, search, PDF export, and settings consolidation.

---

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| SwiftUI `NavigationSplitView` | macOS 13+ / built-in | Sidebar + detail layout for main window | Native two-column layout primitive. Automatically provides collapsible sidebar, system list selection style, and proper macOS window chrome. Replaces the current manual `HStack(sidebar + Divider() + detail)` in `NotesView` with a first-class API. Available since macOS 13, well-tested on macOS 15. No new dependencies. HIGH confidence. |
| SwiftUI `Window` scene (existing) | macOS 13+ / built-in | Main app window scene | The app already uses `Window("notes", id: "notes")` and `Window("main", id: "main")`. The milestone replaces the current "notes" window layout with `NavigationSplitView` inside the existing `Window` scene — no new scene type needed. HIGH confidence. |
| SwiftUI `.searchable(text:)` modifier | macOS 12+ / built-in | Search bar in sidebar | Native modifier that integrates a system search field into the toolbar of the column it is applied to. Returns a `@Binding<String>` search query. On macOS, renders as a standard Spotlight-style search field in the toolbar. HIGH confidence. |
| `String.localizedStandardContains(_:)` | Foundation / built-in | Case-insensitive, locale-aware substring matching | The existing `SessionStore` persists JSONL and plain-text transcript files on disk. There is no database to query. Search must scan in-memory `[SessionRecord]` arrays loaded from disk. `localizedStandardContains` is case-insensitive and diacritic-insensitive — the correct choice over `.contains()` (which is case-sensitive) or NSPredicate (which requires Core Data). Confirmed supported in `#Predicate` on SwiftData and works on plain Swift strings. HIGH confidence. |
| AppKit `NSTextView` + `NSPrintOperation.pdfOperation(with:inside:to:)` | macOS 10.0+ / AppKit / built-in | PDF generation from transcript + summary | The canonical macOS approach for generating a paginated PDF from text content. Build an off-screen `NSTextView` with `NSAttributedString` content, configure `NSPrintInfo` with page size and margins, then call `NSPrintOperation.pdfOperation(with:inside:to:)` to write the PDF directly to a file URL — no print dialog shown. Handles text pagination automatically via `NSLayoutManager`. No UIKit, no third-party libraries. HIGH confidence from Apple developer forum confirmations. |
| AppKit `NSSavePanel` | macOS 10.0+ / AppKit / built-in | "Save As" dialog for PDF export | Standard macOS save dialog. Call from SwiftUI via a `Button` action that runs on `MainActor`. Configure with `allowedContentTypes: [.pdf]`, default filename (meeting title + date), and `directoryURL` to `~/Documents`. Bridges naturally from SwiftUI with `@MainActor` task. HIGH confidence. |
| `AttributedString` / `NSAttributedString` | Foundation / AppKit / built-in | Styled text for PDF content | Compose the PDF body as `NSAttributedString` with `NSFont`, `NSParagraphStyle`, and `NSColor` attributes — title, section headings, summary bullets, transcript lines. This is the bridge between Swift string data and `NSTextView` rendering. HIGH confidence. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| None required | — | Search | String scanning with `localizedStandardContains` on loaded `[SessionRecord]` arrays is sufficient for hundreds of sessions. Only add a search index (SQLite FTS, or a lightweight index library) if search latency becomes perceptible at >5,000 sessions — unlikely for a personal meeting app. |
| None required | — | PDF export | `NSPrintOperation.pdfOperation` + `NSTextView` is the full solution. Third-party PDF libs (PSPDFKit, etc.) are enterprise-licensed and overkill. |
| None required | — | Main window layout | `NavigationSplitView` and `.searchable` are built-in SwiftUI. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Xcode Instruments (Time Profiler) | Profile search scan time on large session datasets | Run against a synthetic dataset of 500+ sessions to validate search latency before shipping |
| Xcode Preview with macOS destination | Test `NavigationSplitView` sidebar/detail layout | Use `#Preview` in Swift 6.2 with `.previewLayout(.sizeThatFits)` on macOS to iterate on layout without launching the full app |

---

## Installation

No new Swift Package Manager dependencies required for this milestone.

All capabilities — `NavigationSplitView`, `.searchable`, `NSPrintOperation`, `NSSavePanel`, `NSTextView`, `NSAttributedString` — are built into SwiftUI, AppKit, and Foundation which are already part of the project.

---

## Feature-by-Feature Architecture Decisions

### 1. Main App Window — NavigationSplitView

**Decision:** Replace `NotesView`'s manual `HStack(sidebar + Divider() + detail)` with `NavigationSplitView`.

```swift
NavigationSplitView {
    // Sidebar: meeting list
    List(sessions, selection: $selectedID) { session in
        MeetingRowView(session: session)
    }
    .navigationSplitViewColumnWidth(min: 220, ideal: 260)
    .searchable(text: $searchQuery)
} detail: {
    if let id = selectedID {
        MeetingDetailView(sessionID: id)
    } else {
        ContentUnavailableView("Select a Meeting", systemImage: "doc.text")
    }
}
```

Why this over the existing `HStack` approach:
- System sidebar toggle button for free
- Correct resizing behavior — sidebar collapses, detail expands
- System list selection highlight style (matches Notes, Mail, Finder)
- The `Window("notes")` scene can stay; its root content becomes `NavigationSplitView`

**Settings tab integration:** PROJECT.md specifies "Settings as a tab in main window, not a separate preferences window." Implement this as a tab in the sidebar or as a top-level navigation item using `List` with an enum-backed selection that includes `.settings` as one case. The SwiftUI `Settings` scene (existing) can remain for users who trigger it via keyboard shortcut — it does not conflict.

### 2. Meeting History Persistence

**Decision:** No change to storage layer. `SessionStore` (JSONL) + `TranscriptLogger` (plain text) + Markdown notes files are the source of truth. `AppCoordinator.sessionHistory: [SessionIndex]` is already an in-memory list.

**What needs adding:** A `MeetingHistoryLoader` (or extend `AppCoordinator.loadHistory()`) that reads `SessionSidecar` files from disk to populate the sidebar list. The `SessionIndex` struct already has `title`, `startedAt`, `endedAt`, `utteranceCount`, `hasNotes`, `meetingApp`.

**No SwiftData, no Core Data.** Introducing a database for a file-based app at this stage would require a migration path for existing users and adds complexity with no performance benefit at the scale of a personal tool (hundreds, not millions, of sessions).

### 3. Search

**Decision:** In-memory scan with `localizedStandardContains`.

**How it works:**
1. User types in `.searchable` search field — updates `@State var searchQuery: String`
2. Filter `coordinator.sessionHistory` array using a computed property:
   ```swift
   var filteredSessions: [SessionIndex] {
       guard !searchQuery.isEmpty else { return coordinator.sessionHistory }
       return coordinator.sessionHistory.filter { session in
           (session.title ?? "").localizedStandardContains(searchQuery)
               || session.id.localizedStandardContains(searchQuery)
       }
   }
   ```
3. For full-text search across transcript content: load transcript text lazily on demand (already available via `TranscriptLogger`'s plain `.txt` files). Search the loaded text string with `localizedStandardContains`.

**Performance:** `localizedStandardContains` on in-memory strings for 500 sessions of ~5KB each (2.5MB total) completes in < 5ms. Acceptable with no index. Load transcript files lazily when the user opens a session — do not preload all transcript content at startup.

**Case sensitivity:** `localizedStandardContains` is case-insensitive and locale-aware. Correct default for a search bar. Do not use plain `.contains()` (case-sensitive) or NSPredicate (unnecessary indirection for plain Swift arrays).

### 4. PDF Export

**Decision:** `NSPrintOperation.pdfOperation(with:inside:to:)` with an off-screen `NSTextView`.

**Full flow:**

```swift
// Step 1: Compose NSAttributedString from session content
let attrStr = PDFComposer.compose(session: session, summary: summary, transcript: records)

// Step 2: Build off-screen NSTextView sized to US Letter
let printInfo = NSPrintInfo.shared.copy() as! NSPrintInfo
printInfo.paperSize = NSSize(width: 612, height: 792)  // US Letter in points
printInfo.leftMargin = 72; printInfo.rightMargin = 72
printInfo.topMargin = 72; printInfo.bottomMargin = 72
printInfo.horizontalPagination = .fit
printInfo.verticalPagination = .auto
printInfo.jobDisposition = .save

let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 468, height: 648))
textView.textStorage?.setAttributedString(attrStr)

// Step 3: Write PDF silently to a temp URL, then prompt user to save
let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(title).pdf")
let op = NSPrintOperation.pdfOperation(with: textView, inside: textView.bounds, to: tempURL, printInfo: printInfo)
op.showsPrintPanel = false
op.showsProgressPanel = false
op.run()

// Step 4: NSSavePanel for user-facing save location
let panel = NSSavePanel()
panel.allowedContentTypes = [.pdf]
panel.nameFieldStringValue = "\(title).pdf"
panel.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
panel.runModal()  // or use beginSheetModal for sheet presentation
```

**`PDFComposer` struct** (new, ~100 lines): pure function taking `SessionIndex`, `EnhancedNotes?`, and `[SessionRecord]` — returns `NSAttributedString`. Sections: title (large bold), metadata (date, duration, meeting app), summary bullets (if available), divider, transcript lines (monospace or readable font, speaker labels).

**Why not PDFKit `PDFDocument`:** PDFKit is for reading/annotating existing PDFs, not generating from text. It has no concept of text layout or pagination. `NSPrintOperation` handles pagination automatically.

**Why not Core Graphics directly:** Drawing text with Core Graphics requires manual line breaking, page height tracking, and CTLine / CTFrame management — hundreds of lines of layout code. `NSTextView` + `NSPrintOperation` delegates this to the mature AppKit text system.

### 5. Granola-Style Detail View (Summary Flowing into Transcript)

**Decision:** Single `ScrollView` in the detail pane, no tabs. Sections: metadata header, summary card (if available), full transcript.

This replaces the existing `DetailViewMode` enum (`.transcript` / `.notes` tabs) in `NotesView`. The Granola-style view is a vertical scroll — summary at top, then transcript below. No tab switching needed.

```swift
ScrollView {
    VStack(alignment: .leading, spacing: 24) {
        MeetingMetadataHeader(session: session)
        if let summary = summary {
            SummaryCard(summary: summary)
        }
        Divider()
        TranscriptSection(records: transcript)
    }
    .padding(24)
}
```

### 6. Settings Panel in Main Window

**Decision:** Implement as a navigation destination in the sidebar, not a separate window or macOS `Settings` scene replacement.

Add a `.settings` case to the sidebar's selection enum. When selected, the detail pane shows `SettingsView` (the existing SwiftUI view). The `Settings` scene (accessible via `Cmd+,`) can remain for users who prefer it — it renders the same `SettingsView`.

This matches the PROJECT.md decision: "Settings as tab in main window — not a separate preferences window, Granola-style."

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| `NavigationSplitView` | Manual `HStack(sidebar + Divider() + detail)` (existing) | Never — the existing approach loses sidebar toggle, correct resize behavior, and system selection style |
| `NavigationSplitView` | `HSplitView` (AppKit-style) | Only if granular split handle drag control is needed (e.g., pixels-exact resize). Not needed here. |
| In-memory `localizedStandardContains` scan | SQLite FTS5 (via GRDB or raw sqlite3) | Only if session count exceeds ~5,000 or search must return ranked results across full transcript body. At personal-tool scale, a database adds migration complexity with no perceptible benefit. |
| `NSPrintOperation.pdfOperation` | Core Graphics `CGContext` PDF drawing | Never for text-heavy export — CGContext requires manual line breaking, page tracking, and text metrics. NSPrintOperation + NSTextView handles all of this. |
| `NSPrintOperation.pdfOperation` | PDFKit `PDFDocument` | Never for generation from text. PDFKit is a reader/annotator. It cannot lay out and paginate text. |
| `NSSavePanel` | `fileExporter` SwiftUI modifier | `fileExporter` works for document-based apps with `FileDocument`. This app is not document-based. `NSSavePanel` via `@MainActor` task is cleaner here. |
| Single scrolling detail view (Granola-style) | Tabbed transcript/notes view (existing) | Only if users need to focus on one view at a time and the combined view is too long. User research would inform this, but the Granola app demonstrates the combined view is effective for meeting notes. |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| SwiftData / Core Data for session storage | Introduces a database migration layer on top of an already-working file-based system. Breaking change for existing users. No query performance benefit at personal-tool scale. | Keep `SessionStore` (JSONL) + `TranscriptLogger` (plain text) + in-memory `[SessionIndex]` |
| `NSMetadataQuery` / Spotlight for search | The existing `SessionStore` explicitly places a `.metadata_never_index` sentinel in session directories to prevent Spotlight indexing. Spotlight queries would return empty results by design. | In-memory `localizedStandardContains` scan |
| Third-party PDF libraries (PSPDFKit, etc.) | Enterprise-licensed, heavy dependencies, inappropriate for a personal tool. Violates "no new dependencies" constraint. | `NSPrintOperation.pdfOperation` + `NSTextView` |
| `UIGraphicsPDFRenderer` / `UISimpleTextPrintFormatter` | UIKit-only APIs. Not available on macOS. | `NSPrintOperation.pdfOperation` (AppKit) |
| Multiple `Window` scenes for the redesigned app | Current app has `Window("main")` for recording controls and `Window("notes")` for history. Post-milestone, the main window absorbs history + settings — avoid adding a third window scene. | Consolidate into `Window("main")` with `NavigationSplitView` |
| `TabView` for main navigation | `TabView` on macOS renders as a tab bar at the bottom (or top), which is an iOS pattern. macOS apps use sidebar navigation for top-level sections. | `NavigationSplitView` with sidebar list |
| `.searchable` with async search delay | For in-memory string scanning, async debounce is unnecessary complexity. | Synchronous computed `filteredSessions` property driven by `@State var searchQuery` |

---

## Stack Patterns by Scenario

**If transcript + summary content is too long for a single NSTextView page:**
- `NSTextView` + `NSPrintOperation` handles multi-page automatically via `NSLayoutManager`. No manual pagination needed.

**If search needs to span full transcript text (not just titles/metadata):**
- Load each session's `.txt` transcript file on a background actor when results are needed.
- Cache loaded transcript strings in a `[String: String]` dictionary (sessionID → transcript text) on `AppCoordinator`.
- Filter with `localizedStandardContains`. Evict cache when memory pressure notification fires (`UIApplication.didReceiveMemoryWarningNotification` equivalent on macOS: `NSApplication.willTerminateNotification` is not the right signal — use `DispatchSource` or limit cache to last 100 sessions).

**If Settings view needs to be shown both from sidebar and `Cmd+,`:**
- Keep the `Settings { SettingsView(...) }` scene in `OpenOatsRootApp`.
- Also render `SettingsView(...)` in the detail pane when the sidebar selection is `.settings`.
- Both render the same view with the same environment injections — no duplication of logic.

---

## Version Compatibility

| Component | Minimum macOS | Notes |
|-----------|---------------|-------|
| `NavigationSplitView` | macOS 13.0 | App targets macOS 15+ — no back-deployment concern |
| `.searchable(text:placement:prompt:)` | macOS 12.0 | Stable on macOS 15 |
| `NSPrintOperation.pdfOperation(with:inside:to:printInfo:)` | macOS 10.0+ | Long-stable API. `showsPrintPanel = false` suppresses dialog silently. |
| `NSSavePanel` with `allowedContentTypes: [.pdf]` | macOS 11.0+ (UTType) | Use `UTType.pdf` (requires `import UniformTypeIdentifiers`). `allowedFileTypes = ["pdf"]` is the deprecated NSString-based API — avoid. |
| `String.localizedStandardContains` | macOS 10.11+ | Stable |
| `NSAttributedString` with `NSFont`, `NSParagraphStyle` | macOS 10.0+ | Stable. Use AppKit types (`NSFont`, `NSColor`) not UIKit types (`UIFont`, `UIColor`) on macOS. |
| `ContentUnavailableView` (empty state placeholder) | macOS 14.0+ (Sonoma) | App targets macOS 15+. Use for "no meeting selected" and "no search results" states. |

---

## Sources

- [Apple Developer Documentation — NavigationSplitView](https://developer.apple.com/documentation/swiftui/navigationsplitview) — HIGH confidence (official)
- [Apple Developer Documentation — NSPrintOperation](https://developer.apple.com/documentation/appkit/nsprintoperation/) — HIGH confidence (official)
- [Apple Developer Documentation — pdfOperation(with:inside:to:)](https://developer.apple.com/documentation/appkit/nsprintoperation/1529269-pdfoperation) — HIGH confidence (official)
- [Apple Developer Documentation — NSSavePanel](https://developer.apple.com/documentation/appkit/nssavepanel) — HIGH confidence (official)
- [Apple Developer Forums — NSPrintOperation PDF without print panel](https://developer.apple.com/forums/thread/129642) — HIGH confidence (confirmed pattern works, multiple dev confirmations)
- [Apple Developer Forums — SwiftData #Predicate string contains](https://developer.apple.com/forums/thread/747226) — MEDIUM confidence (community + docs)
- [HackingWithSwift — SwiftData filtering with predicates](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-filter-swiftdata-results-with-predicates) — HIGH confidence (`localizedStandardContains` recommendation confirmed)
- [Eleclectic Light — SwiftUI on macOS: text, rich text, markdown, PDF views (2024)](https://eclecticlight.co/2024/05/07/swiftui-on-macos-text-rich-text-markdown-html-and-pdf-views/) — MEDIUM confidence (recent community source confirming NSTextView + NSPrintOperation approach)
- [Create With Swift — NavigationSplitView exploration](https://www.createwithswift.com/exploring-the-navigationsplitview/) — MEDIUM confidence (confirmed macOS sidebar behavior)
- Existing codebase review (`OpenOatsApp.swift`, `NotesView.swift`, `SessionStore.swift`, `Models.swift`) — HIGH confidence (architecture integration verified directly)

---

*Stack research for: MeetingScribe macOS — main app window, meeting history, search, PDF export, settings milestone*
*Researched: 2026-03-21*
