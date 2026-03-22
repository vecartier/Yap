---
phase: 6
slug: search-export
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-22
---

# Phase 6 — Validation Strategy

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
| 06-01-01 | 01 | 1 | SRCH-01, SRCH-02 | unit | `swift test --filter SearchServiceTests` | ❌ W0 | ⬜ pending |
| 06-01-02 | 01 | 1 | SRCH-03 | build | `swift build` | ✅ | ⬜ pending |
| 06-02-01 | 02 | 1 | EXPRT-01, EXPRT-02 | unit | `swift test --filter PDFExporterTests` | ❌ W0 | ⬜ pending |
| 06-02-02 | 02 | 1 | EXPRT-01 | build | `swift build` | ✅ | ⬜ pending |

---

## Wave 0 Requirements

- [ ] `SearchServiceTests.swift` — tests for search filtering, debounce, multi-field matching
- [ ] `PDFExporterTests.swift` — tests for NSAttributedString composition, content assembly

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Search filters sidebar in real-time | SRCH-03 | UI interaction | Type in search bar, verify sidebar updates |
| No UI stutter during search | SRCH-02 | Performance perception | Search while scrolling, verify smooth |
| PDF opens in Preview with correct content | EXPRT-01 | File output + external app | Export, open PDF, verify metadata + summary + transcript |
| PDF has proper multi-page pagination | EXPRT-02 | Visual layout | Check long transcript spans multiple pages cleanly |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 25s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
