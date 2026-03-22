---
phase: 04-live-recording-menu-bar-cleanup
verified: 2026-03-22T10:00:00Z
status: passed
score: 9/9 must-haves verified
re_verification: false
human_verification:
  - test: "Start a recording and observe the main window"
    expected: "Sidebar shows Live Session row with pulsing red dot + timer. Detail pane shows recording header with red dot, elapsed timer, and Stop button. Transcript lines appear as you speak."
    why_human: "Cannot start a real audio recording programmatically in a static file check — requires runtime + microphone."
  - test: "Click Stop and observe the finalizing state"
    expected: "Header briefly shows ProgressView + 'Finalizing…' text. After finalization, sidebar live row disappears and completed session is auto-selected. Detail pane switches to PastMeetingDetailView."
    why_human: "Requires runtime execution and real recording flow to verify state transitions."
  - test: "Open menu bar popover when idle"
    expected: "Popover shows Start Call, Solo (memo), Solo (room) buttons. No transcript or waveform UI visible. Open Papyrus link visible."
    why_human: "Menu bar popover requires a running macOS app to inspect."
  - test: "Open menu bar popover during recording"
    expected: "Popover shows red dot + timer in status line + Stop Recording button. No transcript visible."
    why_human: "Requires runtime execution."
---

# Phase 4: Live Recording + Menu Bar Cleanup Verification Report

**Phase Goal:** Live transcript appears in main window during recording; menu bar is stripped to minimal; legacy files deleted
**Verified:** 2026-03-22
**Status:** PASSED
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths (from Plan must_haves)

#### Plan 04-01 Truths

| # | Truth | Status | Evidence |
|---|-------|--------|---------|
| 1 | During recording, main window detail pane shows live transcript with recording header (red pulsing dot, duration timer, Stop button) | VERIFIED | `LiveDetailView.swift` lines 12-100: `recordingHeader` with pulsing Circle, `formattedTime`, Stop/Finalizing branch; `transcriptBody` passes `TranscriptView` |
| 2 | Sidebar shows synthetic 'Live Session' row pinned at top while recording is active or finalizing | VERIFIED | `MeetingSidebarView.swift` lines 51-55: `if coordinator.isRecording || isFinalizing { LiveSessionRowView(...).tag("_live_") }` |
| 3 | When recording stops, sidebar live row disappears and detail pane auto-navigates to completed session | VERIFIED | `MainAppView.swift` lines 27-30: `onChange(of: coordinator.lastEndedSession) { _, session in guard let session else { return }; selectedSessionID = session.id }` |
| 4 | DetailRouter routes to LiveDetailView when selectedSessionID is '_live_', and to PastMeetingDetailView for all real session IDs | VERIFIED | `DetailRouter.swift` lines 10-14: `resolvedContent` returns `.live` when `selectedSessionID == "_live_"`, `.past(id)` for real IDs, `.empty` for nil |
| 5 | Utterances are persisted to disk during recording (transcriptLogger, sessionStore) — not just rendered | VERIFIED | `LiveDetailView.swift` lines 148-201: `handleNewUtterance` calls `coordinator.transcriptLogger?.append(...)` and `coordinator.sessionStore.appendRecord(...)` / `appendRecordDelayed(...)`; wired via `onChange(of: coordinator.transcriptStore.utterances.count)` at line 35 |

#### Plan 04-02 Truths

| # | Truth | Status | Evidence |
|---|-------|--------|---------|
| 6 | Menu bar popover idle state shows exactly three start buttons: Start Call, Solo (memo), Solo (room) | VERIFIED | `MenuBarPopoverView.swift` lines 117-159: idle branch of `primaryAction` contains three `Button` views with those exact labels; grep confirms each appears exactly once |
| 7 | Menu bar popover during recording shows only: status line (red dot + timer), Stop Recording button, Open Papyrus link, Quit Papyrus — no live transcript | VERIFIED | `MenuBarPopoverView.swift`: no `TranscriptView`, `utterances`, or `DisclosureGroup` anywhere; recording branch at lines 105-115 shows only Stop Recording button |
| 8 | ContentView.swift and NotesView.swift no longer exist anywhere in the project | VERIFIED | `test ! -f .../ContentView.swift` → DELETED; `test ! -f .../NotesView.swift` → DELETED |
| 9 | swift build succeeds after file deletion with zero errors or unresolved references | VERIFIED (by SUMMARY) | 04-02-SUMMARY.md reports `197/197 tests passing` after deletion; commits 17fc0d2 (delete files) and 9cbe7bb (3 buttons) both exist in git log |

**Score:** 9/9 truths verified

---

## Required Artifacts

### Plan 04-01 Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `OpenOats/Sources/OpenOats/Views/LiveDetailView.swift` | Live recording detail pane with header + transcript | VERIFIED | 202 lines; substantive implementation; contains `isFinalizing`, `handleNewUtterance`, `onChange.*utterances.count`, no `.onHover` |
| `OpenOats/Sources/OpenOats/Views/DetailRouter.swift` | Routes `_live_` → LiveDetailView, real ID → PastMeetingDetailView, nil → empty | VERIFIED | 46 lines; `private enum Content`, `resolvedContent` computed var, `selectedSessionID == "_live_"` on line 11 |
| `OpenOats/Sources/OpenOats/Views/MeetingSidebarView.swift` | MeetingListItem enum + live row in sidebar List | VERIFIED | 241 lines; `enum MeetingListItem: Identifiable, Hashable` on line 29; `LiveSessionRowView` private struct present |
| `OpenOats/Sources/OpenOats/Views/MainAppView.swift` | Auto-selects `_live_` on recording start, auto-navigates to session on stop | VERIFIED | 72 lines; both `onChange` hooks present at lines 21-30 |
| `OpenOats/Tests/OpenOatsTests/MeetingListItemTests.swift` | Unit tests for MeetingListItem enum | VERIFIED | 50 lines; 5 test functions: `testLiveItemIDIsLiveSentinel`, `testSessionItemIDMatchesSessionID`, `testTwoLiveCasesAreEqual`, `testSessionItemsWithDifferentIDsAreNotEqual`, `testLiveItemIsHashable` |

### Plan 04-02 Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `OpenOats/Sources/OpenOats/Views/MenuBarPopoverView.swift` | Minimal popover: 3 idle start buttons + recording status/stop | VERIFIED | 194 lines; "Start Call", "Solo (memo)", "Solo (room)" each appear once; no transcript UI |
| `OpenOats/Sources/OpenOats/Views/ContentView.swift` | DELETED — must not exist | VERIFIED | File absent from Views directory |
| `OpenOats/Sources/OpenOats/Views/NotesView.swift` | DELETED — must not exist | VERIFIED | File absent from Views directory |

---

## Key Link Verification

### Plan 04-01 Key Links

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `MainAppView.swift` | `selectedSessionID = "_live_"` | `onChange(of: coordinator.isRecording)` | WIRED | Line 21-26: `onChange(of: coordinator.isRecording) { _, isRecording in if isRecording { selectedSessionID = "_live_" } }` |
| `MainAppView.swift` | `selectedSessionID = session.id` | `onChange(of: coordinator.lastEndedSession)` | WIRED | Lines 27-30: `onChange(of: coordinator.lastEndedSession) { _, session in guard let session else { return }; selectedSessionID = session.id }` |
| `DetailRouter.swift` | `LiveDetailView` | `resolvedContent == .live` when `selectedSessionID == "_live_"` | WIRED | Lines 10-11: `if selectedSessionID == "_live_" { return .live }` |
| `LiveDetailView.swift` | `coordinator.sessionStore` | `onChange(of: utterances.count) → handleNewUtterances` | WIRED | Lines 35-39: `onChange(of: coordinator.transcriptStore.utterances.count) { old, new in ... handleNewUtterances(startingAt: old) }` |

### Plan 04-02 Key Links

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `MenuBarPopoverView.swift` | `AppCoordinator` | `coordinator.handle(.userStarted(.manual()), ...)` | WIRED | Lines 122-124: three buttons each call `coordinator.handle(.userStarted(...))` with consent gate |
| Source/App code | `openWindow(id: "notes")` | No such call should exist | VERIFIED ABSENT | grep across all Sources finds zero matches for `openWindow.*notes`; `.openNotes` deep link is handled in `MainAppView.onOpenURL` via `selectedSessionID = sessionID` |

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|---------|
| LIVE-01 | 04-01 | Live transcript appears in main window detail pane | SATISFIED | `LiveDetailView.swift` with `TranscriptView` wired to `coordinator.transcriptStore` |
| LIVE-02 | 04-01 | Sidebar shows synthetic "Live Session" row pinned at top | SATISFIED | `MeetingSidebarView.swift`: `LiveSessionRowView.tag("_live_")` prepended when `isRecording || isFinalizing` |
| LIVE-03 | 04-01 | When recording stops, detail auto-navigates to completed session | SATISFIED | `MainAppView.swift`: `onChange(of: coordinator.lastEndedSession)` sets `selectedSessionID = session.id` |
| LIVE-04 | 04-01 | DetailRouter routes between live view and past meeting view | SATISFIED | `DetailRouter.swift`: three-branch routing via `resolvedContent` enum |
| MENU-01 | 04-02 | Menu bar shows recording status + start/stop + Open link | SATISFIED | `MenuBarPopoverView.swift`: `statusLine` + `primaryAction` (3 buttons idle / Stop recording) + "Open Papyrus" + "Quit Papyrus" |
| MENU-02 | 04-02 | Live transcript removed from menu bar popover | SATISFIED | No `TranscriptView`, `utterances`, or `DisclosureGroup` in `MenuBarPopoverView.swift` |
| MENU-03 | 04-02 | ContentView.swift and NotesView.swift removed | SATISFIED | Both files deleted; zero type-reference occurrences remain in Sources (only harmless code comments) |

All 7 requirements for Phase 4 are satisfied. No orphaned requirements found — REQUIREMENTS.md traceability table maps LIVE-01 through LIVE-04 and MENU-01 through MENU-03 exclusively to Phase 4.

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `TranscriptionEngine.swift` | 109 | `// Audio recorder for tapping streams (set by ContentView when recording is enabled)` — comment references deleted type | Info | Comment is stale but harmless; no functional impact |
| `LiveDetailView.swift` | 138 | `// MARK: - Utterance Persistence (ported verbatim from ContentView)` — comment references deleted type | Info | Comment is accurate historical context; no functional impact |

No blocker or warning-level anti-patterns found.

---

## Human Verification Required

The following items require a running instance of the app to confirm visually and functionally. Automated checks confirm the implementation is correct and wired — runtime behavior needs a human pass.

### 1. Live Recording End-to-End Flow

**Test:** Start a recording from the menu bar. Observe the main window sidebar and detail pane.
**Expected:** Sidebar shows "Live Session" row at the top with pulsing red dot and elapsed timer. Detail pane shows LiveDetailView: pulsing red dot, timer, Stop button, and live transcript lines appearing as you speak.
**Why human:** Cannot start a real audio recording in a static file analysis.

### 2. Finalization Transition

**Test:** Click Stop from either the menu bar or the main window Stop button. Observe the transition.
**Expected:** Header briefly switches to ProgressView + "Finalizing…" text. Sidebar live row shows ProgressView icon + "Finalizing…" caption. After finalization, live row disappears, the completed session row auto-selects, and PastMeetingDetailView loads.
**Why human:** Multi-step state machine transition requires real audio finalization pipeline.

### 3. Menu Bar Popover — Idle State

**Test:** Ensure no recording is active. Click the menu bar icon.
**Expected:** Popover shows "Start Call", "Solo (memo)", "Solo (room)" bordered buttons. "Open Papyrus" link below. No transcript, waveform, or live audio UI.
**Why human:** Menu bar popover is a macOS runtime artifact not inspectable statically.

### 4. Menu Bar Popover — Recording State

**Test:** Start a recording, then click the menu bar icon.
**Expected:** Status line shows red dot + "Recording - 0:XX". Primary action shows only "Stop Recording" button (red, prominent). No transcript section visible.
**Why human:** Requires runtime execution.

---

## Gaps Summary

No gaps. All 9 observable truths are verified. All 7 requirements (LIVE-01, LIVE-02, LIVE-03, LIVE-04, MENU-01, MENU-02, MENU-03) are satisfied by substantive, wired implementations. The only items requiring attention are 4 runtime behavior checks that need a human with a running build.

---

_Verified: 2026-03-22_
_Verifier: Claude (gsd-verifier)_
