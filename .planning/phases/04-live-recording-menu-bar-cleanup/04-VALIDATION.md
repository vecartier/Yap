---
phase: 4
slug: live-recording-menu-bar-cleanup
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-22
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing / XCTest (via SPM) |
| **Config file** | `Package.swift` (test target: OpenOatsTests) |
| **Quick run command** | `swift test --filter OpenOatsTests` |
| **Full suite command** | `swift test` |
| **Estimated runtime** | ~20 seconds |

---

## Sampling Rate

- **After every task commit:** Run `swift test --filter OpenOatsTests`
- **After every plan wave:** Run `swift test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 20 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 04-01-01 | 01 | 1 | LIVE-01, LIVE-02, LIVE-04 | unit | `swift test --filter MeetingListItemTests` | ❌ W0 | ⬜ pending |
| 04-01-02 | 01 | 1 | LIVE-01 | build | `swift build` | ✅ | ⬜ pending |
| 04-02-01 | 02 | 2 | MENU-01, MENU-02 | build+grep | `swift build && grep -c "Live" MenuBarPopoverView.swift` | ✅ | ⬜ pending |
| 04-02-02 | 02 | 2 | MENU-03, LIVE-03 | build | `swift build` | ✅ | ⬜ pending |

---

## Wave 0 Requirements

- [ ] `MeetingListItemTests.swift` — tests for MeetingListItem enum, live row insertion logic
- [ ] Verify ContentView.swift and NotesView.swift are deleted (grep for file existence)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Live transcript appears in main window during recording | LIVE-01 | Hardware-dependent audio | Start recording, verify transcript in detail pane |
| Sidebar shows "Live Session" row pinned at top | LIVE-02 | UI layout | Start recording, check sidebar |
| "Finalizing..." state then auto-swap to completed session | LIVE-03 | Timing-dependent transition | Stop recording, observe transition |
| Menu bar shows only status + Stop during recording | MENU-01 | UI verification | Open popover during recording |
| Start buttons work from both menu bar and main window | LIVE-01 | UI interaction | Start from each location |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 20s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
