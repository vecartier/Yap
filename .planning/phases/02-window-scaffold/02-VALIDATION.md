---
phase: 2
slug: window-scaffold
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-21
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing / XCTest (via SPM) |
| **Config file** | `Package.swift` (test target: OpenOatsTests) |
| **Quick run command** | `swift test --filter OpenOatsTests` |
| **Full suite command** | `swift test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `swift test --filter OpenOatsTests`
- **After every plan wave:** Run `swift test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | WIN-06, WIN-07 | build | `swift build` | ✅ | ⬜ pending |
| 02-01-02 | 01 | 1 | — (rename) | grep | `grep -r "Papyrus" OpenOats/Sources/` | ✅ | ⬜ pending |
| 02-02-01 | 02 | 2 | WIN-03 | unit | `swift test --filter SidebarDateGroupingTests` | ❌ W0 | ⬜ pending |
| 02-02-02 | 02 | 2 | WIN-01, WIN-02, WIN-05 | build+test | `swift build && swift test` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `SidebarDateGroupingTests.swift` — stubs for date grouping logic (Today/Yesterday/Last 7 Days/Earlier)

*Existing test infrastructure (MeetingStateTests) covers compilation verification.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Window opens from menu bar, gains focus | WIN-07 | Activation policy flip, window focus | Click "Open Papyrus" in popover, verify window appears in front |
| Second click brings existing window, no duplicate | WIN-06 | Window singleton behavior | Click "Open Papyrus" twice, verify only one window |
| Cmd+W hides to menu bar | WIN-07 | Window lifecycle | Close window, verify dock icon disappears, menu bar icon stays |
| Sidebar date sections render correctly | WIN-03 | Visual layout verification | Check Today/Yesterday/Last 7 Days/Earlier sections with test data |
| Meeting row shows title + duration + type badge | WIN-02 | Visual layout | Verify row content matches "Zoom — Mar 21, 2:00 PM" format |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
