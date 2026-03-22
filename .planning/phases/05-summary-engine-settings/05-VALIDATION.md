---
phase: 5
slug: summary-engine-settings
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-22
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing / XCTest (via SPM) |
| **Config file** | `Package.swift` (test target: OpenOatsTests) |
| **Quick run command** | `swift test --filter OpenOatsTests` |
| **Full suite command** | `swift test` |
| **Estimated runtime** | ~25 seconds |

---

## Sampling Rate

- **After every task commit:** Run `swift test --filter OpenOatsTests`
- **After every plan wave:** Run `swift test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 25 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 05-01-01 | 01 | 1 | SUMM-01–06 | unit | `swift test --filter SummaryEngineTests` | ❌ W0 | ⬜ pending |
| 05-01-02 | 01 | 1 | SUMM-07, SUMM-08 | build | `swift build` | ✅ | ⬜ pending |
| 05-02-01 | 02 | 2 | SUMM-09 | build+test | `swift build && swift test` | ✅ | ⬜ pending |
| 05-02-02 | 02 | 2 | SETT-01, SETT-02 | build | `swift build` | ✅ | ⬜ pending |

---

## Wave 0 Requirements

- [ ] `SummaryEngineTests.swift` — tests for two-phase prompt construction, JSON parsing, fallback handling

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Summary appears in detail pane after recording ends | SUMM-01 | Requires live recording + LLM call | Record meeting, stop, verify summary card populates |
| Slack copy button enables after summary generation | SLCK-03 | UI state after async operation | Stop recording, wait for summary, verify button enabled |
| Spinner during summary generation | SUMM-01 | UI timing | Stop recording, observe spinner then summary reveal |
| Error + Retry on LLM failure | SUMM-08 | Requires triggering LLM error | Disconnect network / misconfigure API key, verify error card |
| Settings gear icon in sidebar | SETT-01 | Visual layout | Click gear, verify settings appear in detail pane |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 25s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
