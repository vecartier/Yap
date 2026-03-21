# Feature Research

**Domain:** Meeting management app — main window (browse, search, manage past meetings)
**Researched:** 2026-03-21
**Confidence:** HIGH (cross-referenced Granola, Otter, Fathom, Fireflies, tl;dv, and macOS app patterns)

> **Scope note:** This document covers the *app window* milestone: sidebar + meeting list + detail pane +
> search + export + settings. Transcription, audio capture, LLM summaries, and Slack sharing are
> covered by the earlier milestone's FEATURES.md. Features here are in the context of browsing and
> managing the meeting history that already exists on disk.

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist in any meeting notes app. Missing these = product feels incomplete or broken.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Sidebar meeting list, chronological | Every meeting notes app (Granola, Otter, Fathom, Fireflies) shows a scrollable list of past meetings in reverse-chronological order — it is the primary navigation surface | LOW | Load from existing TranscriptLogger + SessionStore; List<MeetingSession> sorted by date descending |
| Date-grouped sections ("Today", "Yesterday", "Last 7 days", "Earlier") | Apple Notes, Reminders, and Finder all use this pattern; users expect time-bucketed grouping, not a flat undifferentiated list | LOW | Computed property on meeting list; 4 buckets: today / yesterday / last 7 days / earlier — same grouping Apple uses |
| Meeting title + date + duration in list row | Fireflies shows title, participants, date, time, and emoji topic points per row; Fathom shows title + duration; minimal is title + date + duration | LOW | Title from session metadata or auto-generated (e.g., "Meeting — Mar 21"); duration from session start/end timestamps |
| Detail pane: summary at top, transcript below | Granola's defining UX — unified view with AI notes flowing into raw transcript, no tab-switching; users who have seen Granola expect this over a tabbed layout | MEDIUM | NavigationSplitView detail pane; summary rendered as Markdown; transcript as scrollable plain text below a divider |
| Live transcript in detail pane during recording | Granola displays the live transcript in a dedicated panel inside the main window, not the menu bar; users expect to glance at the window and see what's being captured | MEDIUM | Binding from AudioPipelineCoordinator's transcript buffer into the detail view; show "Recording..." banner at top |
| Full-text search across all transcripts | Users cite finding "when was that topic discussed?" as a primary use case; Otter, Granola, and Fathom all provide keyword search across all meetings | MEDIUM | Search bar in sidebar; filter meeting list to those containing the query; macOS spotlight-style feel; case-insensitive substring match on transcript text |
| Meeting metadata: date, time, duration, meeting type | Every app shows this in the detail view header; meeting type (Zoom / Teams / Meet / Solo memo / Solo room) disambiguates context | LOW | Source from SessionStore JSONL; meeting type already tracked by MeetingTypeDetector |
| Rename meeting | Users want to override auto-generated titles ("Meeting — Mar 21") with something meaningful ("Q1 Planning Sync") — Granola and Otter both support this | LOW | Editable TextField in sidebar row or detail pane header; persist to session metadata |
| Empty state for no meetings | First launch before any recordings = blank sidebar is confusing; users expect a welcoming empty state with clear CTA | LOW | SwiftUI ContentUnavailableView: "No meetings yet" + subtitle "Start a recording from the menu bar" |
| Settings as tab/pane in main window | Granola puts settings in the main window, not a separate Preferences window; users of productivity macOS apps expect inline settings | LOW | NavigationSplitView sidebar with a Settings entry at the bottom; SwiftUI Form with sections |
| Slack-formatted copy button in detail pane | After reading a summary, the next action is sharing it; the copy button should be immediately visible without navigating anywhere | LOW | Toolbar button in detail pane; copies pre-formatted Slack message to clipboard; no webhook config required |

### Differentiators (Competitive Advantage)

Features that set this app apart within the main window experience. Not universally expected, but create real user value.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Inline transcript search with highlight | Granola explicitly lacks in-transcript search (users must ask the chatbot); a Cmd+F-style search that jumps to and highlights matching words in the transcript is a concrete advantage | MEDIUM | NSFindPanelAction or a custom find bar; highlight matching spans in the transcript text; scroll to first match |
| Meeting type badge in list row | A small pill showing "Zoom", "Teams", "Solo memo" etc. in the sidebar row lets users visually scan and filter by context — no competitor surfaces this in the list | LOW | Colored badge based on MeetingType enum; 4 types, 4 distinct colors; no extra data needed |
| "Currently recording" live entry at top of list | Fathom and Granola show an in-progress meeting as a live entry in the list — users know the app is capturing without checking the menu bar | LOW | Pinned row at top of sidebar when SessionManager.isRecording == true; pulsing indicator dot; tapping opens live transcript view |
| Persistent scroll position per meeting | When a user opens a long transcript, reads halfway, closes, and returns — restoring their scroll position avoids re-reading from the top; no competitor does this explicitly | LOW | Store scroll offset per meeting ID in UserDefaults; restore on NavigationSplitView selection change |
| Export to PDF (transcript + summary) | Users need a permanent, shareable artifact; PDF export is expected by professional users but missing from Granola (which only provides note export) | MEDIUM | WKWebView render of summary + transcript to PDF via NSPrintOperation; one button in toolbar |
| Keyboard shortcut to open main window | Power users trigger Granola with a keyboard shortcut; a configurable global shortcut to bring MeetingScribe to front fits macOS power user expectations | LOW | NSEvent globalMonitor or SGEventTap; default Cmd+Shift+M; configurable in Settings |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Tags / folder organization | Users with many meetings want to file them by project or client — Granola 2.0 added folders; Otter added AI Channels | Adds sidebar complexity (tag management, drag-to-folder, folder CRUD) for a personal single-user tool where chronological search + text search covers 95% of retrieval needs | Full-text search across transcripts retrieves the same meetings faster; add tags only if users hit search limits |
| Video recording and video player in detail pane | Power users want to rewind to a specific moment with video context | Storage is prohibitive (1hr meeting = 2–5GB); adds AV capture complexity; audio + transcript is sufficient for the core use case | Audio recording (M4A) already exists; transcript click-to-seek into audio is a viable v2 |
| Bulk delete / archive | "Clean up old meetings" is a common request | Adds multi-select mode, confirmation dialogs, undo state; scope risk for what is purely a housekeeping feature | Single delete from context menu is sufficient; bulk operations are v2 if usage patterns show hoarding behavior |
| Inline AI chat per meeting ("Ask about this meeting") | Granola has this; Otter has it; Fathom has it | Requires an LLM call per question, streaming response UI, conversation state per meeting — significant complexity on top of a milestone that is primarily about window layout | Structured summary already answers "what were the decisions/actions/questions"; chat adds marginal retrieval value for a personal tool |
| Participant list with avatars | Fathom and Otter pull attendees from calendar; looks polished | Requires calendar integration to get real names/avatars; without calendar access, participant list is just speaker labels ("Speaker 1", "Speaker 2") which adds noise not signal | Show participant count from session metadata only if it's reliable; defer named participants to calendar integration milestone |
| Sync / iCloud backup | Multi-device access, peace of mind | Adds sync conflict logic, CloudKit entitlements, iCloud storage concerns; this is a single-machine personal tool | Auto-save to ~/Documents (already exists) is sufficient; user can back up via Time Machine |
| Dark/light mode toggle per-meeting | Aesthetic customization request | Zero functional value; macOS system appearance is the right single source of truth | Respect system appearance via SwiftUI's default `.preferredColorScheme` behavior |

---

## Feature Dependencies

```
Sidebar meeting list
    └── requires ──> SessionStore / TranscriptLogger loading meetings from disk
    └── requires ──> NavigationSplitView scaffold (window must exist)

Detail pane (summary + transcript)
    └── requires ──> Sidebar meeting list (selection drives detail)
    └── requires ──> Summary Markdown file on disk (generated by summary engine milestone)
    └── requires ──> Transcript text file on disk (already exists)

Live transcript in detail pane (during recording)
    └── requires ──> Detail pane rendered
    └── requires ──> Binding to AudioPipelineCoordinator.liveTranscriptBuffer
    └── conflicts with ──> Static meeting detail (same pane, different state)

Full-text search
    └── requires ──> Meeting list loaded
    └── requires ──> Transcript files readable at search time (disk access)
    └── enhances ──> Inline highlight (optional layer on top of search)

Inline transcript search (Cmd+F)
    └── requires ──> Transcript displayed in detail pane
    └── enhances ──> Full-text search (search at macro vs micro level)

Rename meeting
    └── requires ──> Meeting metadata editable in SessionStore
    └── requires ──> Sidebar list row updates reactively on rename

Export to PDF
    └── requires ──> Detail pane content (summary + transcript) rendered
    └── requires ──> Summary file exists (graceful degradation: export transcript-only if no summary)

Slack copy button
    └── requires ──> Summary generated (no summary = disabled button with tooltip)
    └── independent of ──> Settings / webhook configuration

Settings pane
    └── requires ──> NavigationSplitView sidebar (Settings is a sidebar destination)
    └── independent of ──> All meeting data features

"Currently recording" live entry
    └── requires ──> SessionManager.isRecording observable state
    └── enhances ──> Live transcript in detail pane (tapping live entry shows live transcript)

Keyboard shortcut to open window
    └── requires ──> AppDelegate NSWindow management
    └── independent of ──> All content features
```

### Dependency Notes

- **Detail pane has two modes:** static (viewing a past meeting) and live (active recording). These must be distinct view states driven by a `selectedMeeting` binding — nil selection + active recording shows live view; a selected past meeting shows static detail.
- **Summary is optional in v1 detail pane:** The summary engine milestone is being built in parallel. The detail pane must gracefully show "Summary not yet generated" if the `.md` file doesn't exist, without crashing or showing an error sheet.
- **Search requires no index in v1:** Substring match across loaded transcript files is fast enough for personal use (< 500 meetings); a search index (e.g., CoreSpotlight) is a v2 optimization, not a v1 requirement.
- **PDF export depends on rendered content:** It cannot be a background operation — the SwiftUI view must be rendered (even off-screen) to capture it as PDF.

---

## MVP Definition

### Launch With (v1 — this milestone)

Minimum to deliver a functional "home" for all meeting history.

- [ ] NavigationSplitView with sidebar + detail — the scaffold everything else lives in
- [ ] Sidebar: meeting list, date-grouped, with title + date + duration per row
- [ ] Detail pane: summary (Markdown rendered) + transcript (plain text), static layout
- [ ] Live transcript in detail pane when recording is active
- [ ] Full-text search: filter sidebar list by query across transcript text
- [ ] Rename meeting: editable title in detail pane header or sidebar row
- [ ] Slack copy button in detail pane toolbar
- [ ] Settings pane: LLM provider, transcription model, API key, audio device
- [ ] Empty state: ContentUnavailableView for no meetings
- [ ] Meeting type badge in sidebar row (Zoom / Teams / Meet / Solo memo / Solo room)

### Add After Validation (v1.x)

Add once core layout is stable and in use.

- [ ] Export to PDF — add when user feedback identifies "I need to share this as a document"
- [ ] Inline transcript search (Cmd+F) — add once the transcript view is confirmed usable
- [ ] "Currently recording" pinned live entry in sidebar — add once live transcript view is solid
- [ ] Keyboard shortcut to open window — add once basic window management is stable

### Future Consideration (v2+)

Defer until there is demonstrated user demand.

- [ ] Tags / folder organization — only if text search proves insufficient at scale
- [ ] Audio playback with transcript seek — requires storing M4A alongside transcript, surfacing a player
- [ ] AI chat per meeting — only if structured summary proves insufficient for retrieval
- [ ] Calendar integration for participant names — requires calendar permissions milestone
- [ ] Bulk delete / archive — only if users accumulate large meeting histories

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| NavigationSplitView scaffold | HIGH | LOW | P1 |
| Sidebar meeting list (date-grouped) | HIGH | LOW | P1 |
| Detail pane: summary + transcript | HIGH | LOW | P1 |
| Live transcript during recording | HIGH | MEDIUM | P1 |
| Full-text search (sidebar filter) | HIGH | MEDIUM | P1 |
| Rename meeting | MEDIUM | LOW | P1 |
| Slack copy button in detail pane | HIGH | LOW | P1 |
| Settings pane (in main window) | HIGH | LOW | P1 |
| Empty state (no meetings) | MEDIUM | LOW | P1 |
| Meeting type badge in sidebar row | MEDIUM | LOW | P1 |
| Export to PDF | MEDIUM | MEDIUM | P2 |
| Inline transcript Cmd+F search | MEDIUM | MEDIUM | P2 |
| Live recording pinned entry in sidebar | MEDIUM | LOW | P2 |
| Keyboard shortcut to open window | MEDIUM | LOW | P2 |
| Tags / folder organization | LOW | HIGH | P3 |
| AI chat per meeting | LOW | HIGH | P3 |
| Audio playback + transcript seek | MEDIUM | HIGH | P3 |

**Priority key:**
- P1: Must have for this milestone launch
- P2: Add after core layout is validated
- P3: Future milestone

---

## Competitor Feature Analysis

| Feature | Granola | Otter | Fathom | Fireflies | Our Approach |
|---------|---------|-------|--------|-----------|--------------|
| Sidebar meeting list | Yes, chronological + people/companies | Yes, chronological + AI Channels | Dashboard with calendar-pulled meetings | List view with emoji topic points | Chronological + date-grouped sections |
| Summary + transcript unified view | Yes (Granola's defining feature — notes flow into transcript) | Tabbed (summary tab / transcript tab) | Summary + video recording side-by-side | Two tabs (notes / transcript) | Granola-style: summary at top, transcript below in same pane |
| Full-text search | Multi-meeting chat query (no direct transcript search!) | Keyword search across all transcripts | Not prominent | Smart search with highlights | Sidebar filter + inline highlight (fills Granola's gap) |
| Inline transcript search | No (use chatbot workaround) | Clickable word jumps to audio | Not highlighted | Smart search highlights moments | Cmd+F with highlight — explicit differentiator vs Granola |
| Live transcript during recording | Yes (dedicated panel in app) | Yes | Bot-based (separate window) | Bot-based | In detail pane, replaces static content while recording |
| Rename meeting | Yes | Yes | Yes | Yes | Yes — editable in detail pane header |
| Meeting type indicator | No | No | No | No | Badge in sidebar row (novel for this category) |
| Export to PDF | No (notes export only) | Yes (PDF + docx) | No | Yes | Yes (transcript + summary) |
| Settings in main window | Yes | Web settings | Yes | Web settings | Yes — Settings as sidebar destination, not Preferences window |

---

## Sources

- [Granola updates / changelog](https://www.granola.ai/updates) — HIGH confidence (official)
- [Granola live transcription docs](https://www.granola.ai/docs/docs/101/duringyourmeeting/live-transcription) — HIGH confidence (official)
- [Honest Granola AI Review — tl;dv](https://tldv.io/blog/granola-review/) — MEDIUM confidence (editorial)
- [Granola AI review and missing features — Krisp](https://krisp.ai/blog/granola-ai-review-alternatives/) — MEDIUM confidence (editorial)
- [Granola.ai teardown: sharing friction — meetingnotes.com](https://meetingnotes.com/blog/granola-ai-teardown) — MEDIUM confidence (editorial)
- [Granola 2026 in-depth review — bluedothq](https://www.bluedothq.com/blog/granola-review) — MEDIUM confidence (editorial)
- [Otter.ai features overview](https://otter.ai/features) — HIGH confidence (official)
- [5 Fathom features — Zapier](https://zapier.com/blog/fathom-features/) — MEDIUM confidence (editorial)
- [tl;dv vs Fireflies comparison](https://tldv.io/blog/tldv-vs-fireflies/) — MEDIUM confidence (editorial)
- [Fireflies review — bluedothq](https://www.bluedothq.com/blog/fireflies-ai-review) — MEDIUM confidence (editorial)
- [Apple Notes date-grouping pattern — macOS HIG](https://developer.apple.com/design/human-interface-guidelines/lists-and-tables) — HIGH confidence (official platform pattern)

---
*Feature research for: MeetingScribe (OpenOats fork) — main app window milestone*
*Researched: 2026-03-21*
