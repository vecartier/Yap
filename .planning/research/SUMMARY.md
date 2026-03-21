# Project Research Summary

**Project:** OpenOats Fork — MeetingScribe main app window milestone
**Domain:** macOS meeting companion — main window, meeting history, search, PDF export, settings
**Researched:** 2026-03-21
**Confidence:** HIGH

## Executive Summary

This milestone transforms OpenOats from a menu-bar-only recording utility into a full macOS companion app with a Granola-style main window. The app already has a solid foundation — Swift 6.2, WhisperKit transcription, an `AppCoordinator` observable, file-based session storage (JSONL + plain text), and `OpenRouterClient` for LLM summaries. The milestone builds entirely on these existing primitives. No new Swift Package Manager dependencies are required; every new capability (NavigationSplitView, NSPrintOperation PDF export, in-memory search) is available in Apple's existing built-in frameworks. The architectural change is primarily additive: new SwiftUI views replace two existing views (`ContentView`, `NotesView`) and consolidate into a single `Window` scene with a `NavigationSplitView` root.

The recommended approach mirrors how Granola is built: a single-window app with a sidebar meeting list (date-grouped, chronological), a detail pane that switches between a live transcript view during recording and a summary-then-transcript view for completed sessions, and settings embedded as a sidebar tab rather than a separate Preferences window. Competitive analysis confirms this is the best UX pattern for the category. Granola's one clear differentiator gap — no in-transcript keyword search (users must query the AI chatbot instead) — is a concrete feature advantage the fork can claim immediately with a Cmd+F inline search.

The primary risks are macOS-specific integration subtleties rather than architectural complexity. Three issues will kill the experience if unaddressed from day one: using `WindowGroup` instead of `Window` (spawns multiple windows), failing to activate the app before showing the window (window appears behind other apps), and using `ImageRenderer` for PDF export (clips to a single page). All three have documented solutions and must be locked in during the first implementation phase — they cannot be retrofitted cheaply.

---

## Key Findings

### Recommended Stack

The entire milestone uses frameworks already linked into the project. `NavigationSplitView` (SwiftUI, macOS 13+) replaces the manual `HStack(sidebar + Divider() + detail)` in `NotesView` and delivers sidebar toggle, correct resize behavior, and system selection highlight for free. Full-text search uses `String.localizedStandardContains` scanning an in-memory `[SessionIndex]` array — no database, no search index, no new infrastructure — sufficient for hundreds of sessions. PDF export uses `NSPrintOperation.pdfOperation(with:inside:to:)` with an off-screen `NSTextView` and `NSAttributedString` composition; this handles multi-page pagination automatically and is the canonical macOS approach. All search file I/O must run on a background `Task` with a 250ms debounce.

**Core technologies:**
- `NavigationSplitView` (SwiftUI built-in): two-column sidebar + detail layout — replaces manual HStack, delivers system chrome for free
- `Window` scene (SwiftUI built-in): single-instance main window — mandatory over `WindowGroup` to prevent duplicate window spawning
- `String.localizedStandardContains` (Foundation built-in): case-insensitive in-memory search — sufficient for personal-tool scale without any database
- `NSPrintOperation.pdfOperation` + `NSTextView` (AppKit built-in): multi-page PDF export — the only correct path for text-heavy paginated documents on macOS
- `NSSavePanel` (AppKit built-in): save dialog for PDF export — use `UTType.pdf`, not the deprecated `allowedFileTypes` NSString API
- `ContentUnavailableView` (SwiftUI, macOS 14+): empty states for no meetings and no search results
- `@SceneStorage` (SwiftUI built-in): persist sidebar column visibility across launches

### Expected Features

The competitor landscape (Granola, Otter, Fathom, Fireflies) defines what users consider table stakes for a meeting notes app. The gap analysis confirms one clear differentiator: inline transcript keyword search, which Granola explicitly lacks (users must use the AI chatbot as a workaround).

**Must have (table stakes — P1):**
- Sidebar meeting list with date-grouped sections ("Today / Yesterday / Last 7 days / Earlier") — users expect Apple Notes-style grouping
- Detail pane: summary at top, full transcript below (Granola-style unified view, no tabs)
- Live transcript in detail pane during active recording (not the menu bar popover)
- Full-text search filtering the sidebar list — primary use case: "when did we discuss X?"
- Rename meeting — all major competitors support editable titles
- Slack-formatted copy button in detail pane toolbar
- Settings as a tab in the sidebar (not a separate Preferences window)
- Empty state with `ContentUnavailableView` on first launch
- Meeting type badge in sidebar row (Zoom / Teams / Meet / Solo / Room)

**Should have (competitive differentiators — P2, add after core layout is validated):**
- PDF export (transcript + summary) — Granola has no PDF export; this is a concrete gap to fill
- Inline transcript Cmd+F search with highlights — explicit differentiator vs Granola
- "Currently recording" pinned live entry at top of sidebar
- Global keyboard shortcut to open main window

**Defer (v2+):**
- Tags / folder organization — full-text search covers 95% of retrieval needs at personal scale
- AI chat per meeting — structured summary already answers key questions; chat adds marginal value
- Audio playback with transcript seek — significant storage and AV complexity
- Calendar integration for participant names — requires a separate calendar permissions milestone

### Architecture Approach

The architecture follows a strict consolidation pattern: merge the existing two-window design (`Window("main")` for recording controls + `Window("notes")` for history) into one `Window("main")` scene containing a `NavigationSplitView`. The critical design decision is that the detail pane has two mutually exclusive states — live (during recording) and past (completed session) — which must be separated into distinct views (`LiveDetailView`, `PastMeetingDetailView`) with a `DetailRouter` as the single branching point. This prevents live recording state from polluting the disk-loaded session state that `PastMeetingDetailView` manages. `AppCoordinator` requires no new state; `sessionHistory`, `isRecording`, and `lastEndedSession` already exist and are sufficient.

**Major components:**
1. `MainAppView` — `NavigationSplitView` root; owns `selectedSessionID: @State` and `columnVisibility: @SceneStorage`
2. `MeetingSidebarView` — chronological meeting list with live session row pinned at top during recording; uses `MeetingListItem` enum (`.live` + `.session(SessionIndex)`)
3. `DetailRouter` — reads `coordinator.isRecording` + `selectedSessionID` to select between `LiveDetailView`, `PastMeetingDetailView`, and empty state; single source of truth for detail pane content
4. `LiveDetailView` — live transcript during recording; ports existing `ContentView` logic
5. `PastMeetingDetailView` — summary (Markdown rendered) + full transcript + Slack copy button; replaces `NotesView`
6. `AppCoordinator` (unchanged) — environment-injected into all views; no new properties needed

### Critical Pitfalls

1. **`WindowGroup` spawns multiple windows** — use `Window` (not `WindowGroup`) for the main window scene from day one; retroactively fixing this requires surgery on the scene management layer

2. **Window appears behind other apps after activation policy flip** — always call `NSApp.setActivationPolicy(.regular)` then `NSApp.activate(ignoringOtherApps: true)` then `window.makeKeyAndOrderFront(nil)` in sequence; the existing `showMainWindow()` function already does this correctly — wire to it, do not reimplement

3. **`ImageRenderer` clips PDF to one page** — use `NSPrintOperation.pdfOperation` + `NSTextView` instead; `ImageRenderer` is prominently documented but fundamentally broken for multi-page text export; `WKWebView.createPDF` is an acceptable alternative

4. **Full-text search freezes the main thread** — all file I/O in the search path must run on a background `Task` with a 250ms debounce; search title/metadata only in v1; load transcript content lazily on demand

5. **`NavigationSplitView` selection binding missing** — the `selection:` parameter on `List` must be wired explicitly; without it the sidebar shows no selection highlight on macOS (looks broken) even though navigation works

6. **Live transcript updates congest `@MainActor`** — batch utterance updates; do not call `scrollTo` on every utterance; scroll only when the latest utterance ID changes

7. **`.prominentDetail` is a silent no-op on macOS** — use `columnVisibility = .detailOnly` to collapse the sidebar programmatically; `.prominentDetail` is iOS/iPadOS-only and silently degrades on macOS

---

## Implications for Roadmap

Based on the combined research, the architecture's explicit build-order dependency chain maps directly to 6 phases. Each phase produces a shippable, testable increment. This ordering eliminates the most expensive integration risks first before higher-level features are layered on.

### Phase 1: Window Scaffold

**Rationale:** All subsequent work lives inside the `NavigationSplitView` layout. Three of the 7 critical pitfalls (WindowGroup, window focus, selection binding) must be addressed here — they cannot be deferred without invalidating work built on top. Choosing the wrong scene type now means multi-window surgery later.
**Delivers:** `Window("main")` with `NavigationSplitView`, sidebar list populated from existing `coordinator.sessionHistory`, empty state in detail pane, correct window lifecycle (activation policy, singleton enforcement, `showMainWindow()` wired to menu bar).
**Addresses:** Sidebar meeting list (date-grouped), empty state, meeting type badge in rows (all P1 features).
**Avoids:** Pitfall 1 (WindowGroup), Pitfall 2 (window focus/activation), Pitfall 3 (selection binding), Pitfall 7 (prominentDetail).

### Phase 2: Past Meeting Detail (Read-Only)

**Rationale:** The detail pane is the core value surface. Building the static (past meeting) view first establishes the async data loading pattern (`SessionStore` load) and the Granola-style summary-then-transcript layout without the complexity of real-time updates. The summary section must handle graceful empty state (no `.md` file yet) before the `SummaryEngine` is built.
**Delivers:** `PastMeetingDetailView` with metadata header, summary section (graceful "not yet generated" state if no `.md` file), full transcript, Slack copy button. `DetailRouter` wired for past sessions and empty state.
**Uses:** `SessionStore` JSONL + `TranscriptLogger` plain text files (both existing); lazy load per selection.
**Avoids:** Loading all transcripts at launch; detail pane crashing on missing summary files.

### Phase 3: Live Recording Flow

**Rationale:** Once the past-meeting detail pane is solid, the live view follows naturally — both share `DetailRouter`. This is where Pitfall 4 (live transcript main-thread congestion) must be addressed. Keeping `LiveDetailView` separate from `PastMeetingDetailView` is the key design discipline; the existing codebase already separates these concerns (`ContentView` vs `NotesView`) and the milestone must preserve that separation in the new architecture.
**Delivers:** `LiveDetailView` (ports existing `ContentView` logic), `MeetingListItem` enum with `.live` synthetic row pinned at top, auto-navigation to completed session on recording stop.
**Avoids:** Pitfall 4 (live transcript main thread congestion); Anti-Pattern 1 (embedding live state in the past-meeting view).

### Phase 4: MenuBar Cleanup + Legacy View Removal

**Rationale:** With both detail views working, the old `ContentView.swift` and `NotesView.swift` can be safely deleted. The `MenuBarPopoverView` shrinks to status + stop + "Open MeetingScribe" link only. Deleting dead code at this checkpoint prevents it from confusing later phases and keeps the diff clean.
**Delivers:** Stripped menu bar popover; `ContentView.swift` and `NotesView.swift` deleted; `Window("notes")` scene removed from `OpenOatsApp.swift`.
**Avoids:** Anti-Pattern 3 (keeping `Window("notes")` alongside the new main window, creating two overlapping history surfaces).

### Phase 5: SummaryEngine + Settings

**Rationale:** Summary generation (new `SummaryEngine` actor) enriches `PastMeetingDetailView` without requiring structural changes — the detail pane already has a graceful empty state for missing summaries. Settings tab is a sidebar destination in the existing `NavigationSplitView` — low risk, isolated change that reuses the existing `SettingsView`.
**Delivers:** Structured AI summary at top of detail pane, auto-generated on session end; Settings pane as sidebar tab (reusing existing `SettingsView`). The `Cmd+,` shortcut can remain pointing to the `Settings {}` scene or the sidebar tab — both render the same view.
**Uses:** Existing `OpenRouterClient` for LLM calls; `SummaryEngine` actor following the existing `NotesEngine` pattern.

### Phase 6: Search + PDF Export

**Rationale:** Both features are additive and independent of each other and of Phases 1-5. Search requires a background search actor with debounce (Pitfall 5). PDF export requires `NSPrintOperation` + `NSAttributedString` (Pitfall 6). Neither changes any existing data models. Placing these last means the core experience is fully stable before the most AppKit-bridge-heavy work begins.
**Delivers:** `.searchable` modifier on sidebar with background `Task` debounce, filtering by title and transcript content; PDF export via `NSPrintOperation.pdfOperation` with `NSSavePanel` save dialog; `PDFComposer` struct for `NSAttributedString` composition.
**Avoids:** Pitfall 5 (search main-thread freeze); Pitfall 6 (ImageRenderer single-page clipping).

### Phase Ordering Rationale

- Phases 1-4 follow the explicit build-order dependency chain from ARCHITECTURE.md — each step depends only on what came before it, allowing confident verification at each checkpoint.
- Summary generation (Phase 5) is separated from Phase 2's read-only detail pane because `SummaryEngine` is a net-new component; the detail pane must handle "no summary yet" gracefully before the engine exists.
- Search and PDF (Phase 6) are deliberately last because they are pure enhancements — the core experience is complete after Phase 5, and both features introduce the most AppKit-bridge complexity.
- The "no new dependencies" constraint from PROJECT.md is satisfied throughout — every phase uses existing Apple frameworks.

### Research Flags

Phases with well-documented patterns (research-phase optional):
- **Phase 1:** `Window` scene + `NavigationSplitView` + activation policy are extensively documented; ARCHITECTURE.md contains ready-to-use Swift code patterns
- **Phase 2:** File-based session loading is already established in `SessionStore`; no new APIs introduced
- **Phase 3:** Live transcript pattern already exists in `ContentView` — this is a port, not a rewrite
- **Phase 4:** Deletions only; no research needed

Phases that may benefit from targeted research during planning:
- **Phase 5 (SummaryEngine):** The structured JSON summary schema and prompt engineering for `OpenRouterClient` are not covered in the current research. The prior milestone's SUMMARY.md (auto-summary milestone) contains relevant findings — reference it when planning Phase 5. Confirm the desired summary format and schema before implementation begins.
- **Phase 6 (PDF):** PITFALLS.md notes `WKWebView.createPDF` as an alternative to `NSPrintOperation`; STACK.md recommends `NSPrintOperation`. Choose one approach definitively before Phase 6 begins and document the rationale — they have different tradeoffs (NSPrintOperation: pure AppKit, no web engine, synchronous; WKWebView: HTML-based, easier rich styling, async navigation delegate required).

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All technologies are built-in Apple frameworks with official documentation; no new dependencies means no version compatibility unknowns; existing codebase reviewed directly |
| Features | HIGH | Cross-referenced 5 direct competitors (Granola, Otter, Fathom, Fireflies, tl;dv) with official and editorial sources; MVP feature set is well-validated against market |
| Architecture | HIGH | Build-order derived directly from existing codebase review; component boundaries match established patterns already in the project; no speculative layering |
| Pitfalls | HIGH | All 7 critical pitfalls confirmed across Apple Developer Forums, 2025 developer post-mortems, and official documentation; recovery costs are documented with concrete prevention strategies |

**Overall confidence:** HIGH

### Gaps to Address

- **SummaryEngine schema:** The milestone adds a `SummaryEngine` for structured summaries. The current research covers architecture patterns but not the JSON schema or prompt structure. The prior milestone's SUMMARY.md and FEATURES.md contain directly relevant findings. Define the schema before Phase 5 begins.
- **WKWebView vs NSPrintOperation for PDF:** Two valid approaches are documented with different tradeoffs. Pick one strategy and commit to it before Phase 6 — switching mid-phase is expensive.
- **Search index threshold:** In-memory `localizedStandardContains` is validated for ~500 sessions. For heavy users recording many short meetings daily, this threshold could be reached within 1-2 years. Document the threshold in code and note SQLite FTS5 as the v2 upgrade path.
- **macOS 26 Tahoe `openSettings` regression:** PITFALLS.md flags a known regression in macOS 26 where the `openSettings` environment action is broken. The Settings tab-in-sidebar approach sidesteps this for the main UI. If `Cmd+,` must also open Settings, verify the workaround before shipping on macOS 26.

---

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation — NavigationSplitView
- Apple Developer Documentation — NSPrintOperation / pdfOperation(with:inside:to:)
- Apple Developer Documentation — NSSavePanel
- Apple Developer Forums — NSPrintOperation PDF without print panel
- Apple Developer Forums — NavigationSplitView on macOS (selection binding requirements)
- Apple Developer Forums — Multipage PDF with PDFKit on macOS
- Existing codebase review (AppCoordinator.swift, NotesView.swift, SessionStore.swift, OpenOatsApp.swift, ContentView.swift)
- Granola official documentation and changelog
- Otter.ai features overview (official)
- Apple HIG — Lists and Tables (date-grouping pattern)

### Secondary (MEDIUM confidence)
- Eclectic Light — SwiftUI on macOS: text, rich text, markdown, PDF views (2024)
- Peter Steinberger — Showing Settings from macOS Menu Bar Items (2025)
- Art Lasovsky — Fine-Tuning macOS App Activation Behavior
- Swift with Majid — Mastering NavigationSplitView in SwiftUI
- Nil Coalescing — Scene Types in a SwiftUI Mac App (Window vs WindowGroup)
- tl;dv, Krisp, bluedothq editorial reviews of Granola and Fireflies
- Daniel Saidi — Creating a Debounced Search Context for Performant SwiftUI Searches (2025)
- Create With Swift — Exploring the NavigationSplitView

### Tertiary (MEDIUM-LOW confidence)
- Medium — Why Every NavigationSplitView Tutorial Failed Me (community post-mortem, confirmed patterns)
- Medium — Exploring SwiftUI Learnings and Bugs with .searchable (known resource leak, needs validation on target OS)

---
*Research completed: 2026-03-21*
*Ready for roadmap: yes*
