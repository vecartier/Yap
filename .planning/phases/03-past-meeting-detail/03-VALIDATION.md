---
phase: 3
slug: past-meeting-detail
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-21
---

# Phase 3 — Validation Strategy

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
| 03-01-01 | 01 | 1 | SLCK-01, SLCK-02 | unit | `swift test --filter SlackFormatterTests` | ❌ W0 | ⬜ pending |
| 03-01-02 | 01 | 1 | WIN-04 | build | `swift build` | ✅ | ⬜ pending |
| 03-02-01 | 02 | 2 | WIN-04 | build+test | `swift build && swift test` | ✅ | ⬜ pending |
| 03-02-02 | 02 | 2 | SLCK-03 | build | `swift build` | ✅ | ⬜ pending |

---

## Wave 0 Requirements

- [ ] `SlackFormatterTests.swift` — tests for Slack mrkdwn formatting output
- [ ] Verify `Speaker.room` handled exhaustively in new transcript view

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Transcript renders with labeled lines and timestamp markers | WIN-04 | Visual layout | Select a past meeting, verify transcript format |
| Summary placeholder card visible with "Summary will appear here" | WIN-04 | Visual | Select meeting, verify card outline visible |
| Slack copy button disabled with tooltip | SLCK-03 | UI state | Hover disabled button, verify tooltip "Summary required" |
| Single continuous scroll from metadata to transcript | WIN-04 | Scroll behavior | Scroll through detail pane, verify no split |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 20s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
