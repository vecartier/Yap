---
phase: 1
slug: foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-21
---

# Phase 1 — Validation Strategy

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
| 01-01-01 | 01 | 1 | CLEAN-01 | build | `swift build` | ✅ | ⬜ pending |
| 01-01-02 | 01 | 1 | CLEAN-02 | grep | `grep -r KnowledgeBase OpenOats/Sources/` | ✅ | ⬜ pending |
| 01-01-03 | 01 | 1 | CLEAN-03 | grep | `grep -r VoyageClient OpenOats/Sources/` | ✅ | ⬜ pending |
| 01-02-01 | 02 | 1 | SOLO-01 | unit | `swift test --filter testSoloMemo` | ❌ W0 | ⬜ pending |
| 01-02-02 | 02 | 1 | SOLO-02 | unit | `swift test --filter testSoloMemo` | ❌ W0 | ⬜ pending |
| 01-02-03 | 02 | 1 | SOLO-03 | unit | `swift test --filter testSoloTranscript` | ❌ W0 | ⬜ pending |
| 01-02-04 | 02 | 1 | SOLO-04 | unit | `swift test --filter testSoloSpeaker` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Solo mode lifecycle tests — stubs for SOLO-01 through SOLO-04
- [ ] Speaker.room enum case test
- [ ] MeetingMode state transition tests

*Existing test infrastructure (MeetingStateTests, SessionStoreTests) covers KB removal verification via build + grep.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Menu bar shows three buttons | SOLO-01 | UI layout, no snapshot tests | Launch app, verify "Start Call" / "Solo (memo)" / "Solo (room)" visible |
| Solo recording captures mic audio | SOLO-01 | Hardware-dependent | Start solo recording, speak, verify transcript appears |
| KB settings absent from UI | CLEAN-02 | UI, no snapshot tests | Open settings, verify no KB folder picker or embedding provider |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
