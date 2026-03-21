---
phase: 01-foundation
plan: 02
subsystem: recording
tags: [swift, swiftui, audio, transcription, macos]

# Dependency graph
requires:
  - phase: 01-foundation
    plan: 01
    provides: Clean codebase with KB removed; Models.swift, AppCoordinator, TranscriptionEngine intact

provides:
  - MeetingMode enum (.call, .soloMemo, .soloRoom) with capturesSystemAudio and micSpeaker computed properties
  - MeetingMetadata.mode field (Codable default .call for backward compatibility)
  - MeetingMetadata.solo() factory for mic-only sessions
  - Speaker.room case with rawValue "room"
  - TranscriptionEngine.start() mode-aware system audio gate
  - Three-button control bar (Start Call / Solo memo / Solo room) in ContentView
  - Exhaustive speakerLabel(for:) in ContentView and MarkdownMeetingWriter

affects:
  - phase-02 (SummaryEngine reads MeetingMetadata.mode to tailor summaries)
  - TranscriptLogger callers (now produce "Room" for solo room sessions)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "MeetingMode enum with computed properties (capturesSystemAudio, micSpeaker) as single source of truth for mode behavior"
    - "Factory-method initialization for MeetingMetadata (manual() and solo(mode:))"
    - "pendingSessionMode @State to preserve mode through consent-sheet flow"
    - "ControlBar callback-based design extended with onStartCall/onStartSoloMemo/onStartSoloRoom"

key-files:
  created: []
  modified:
    - OpenOats/Sources/OpenOats/Meeting/MeetingTypes.swift
    - OpenOats/Sources/OpenOats/Models/Models.swift
    - OpenOats/Sources/OpenOats/Transcription/TranscriptionEngine.swift
    - OpenOats/Sources/OpenOats/App/AppCoordinator.swift
    - OpenOats/Sources/OpenOats/Views/ContentView.swift
    - OpenOats/Sources/OpenOats/Views/ControlBar.swift
    - OpenOats/Sources/OpenOats/Intelligence/MarkdownMeetingWriter.swift
    - OpenOats/Tests/OpenOatsTests/MeetingStateTests.swift

key-decisions:
  - "TranscriptLogger.swift takes String speaker labels (not Speaker enum) — exhaustive labeling delegated to callers (ContentView.speakerLabel(for:), MarkdownMeetingWriter.speakerLabel(_:))"
  - "currentMeetingMode stored on TranscriptionEngine so mic hot-restarts preserve the correct speaker (solo room stays Speaker.room after device switch)"
  - "ControlBar renders three start buttons (Start Call prominent, Solo memo/room bordered) when !isRunning; Live stop button when isRunning"

patterns-established:
  - "MeetingMode is the canonical authority for both capturesSystemAudio (affects audio engine) and micSpeaker (affects transcript labeling)"
  - "Exhaustive switch on Speaker enum — compiler enforces correctness when new cases are added"

requirements-completed: [SOLO-01, SOLO-02, SOLO-03, SOLO-04]

# Metrics
duration: 6min
completed: 2026-03-21
---

# Phase 01 Plan 02: Solo Recording Mode Summary

**MeetingMode enum gates system audio capture and drives Speaker labels for mic-only solo memo and solo room recording paths, with three-button start UI in the menu bar popover**

## Performance

- **Duration:** 6 min
- **Started:** 2026-03-21T12:34:09Z
- **Completed:** 2026-03-21T12:40:00Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments
- MeetingMode enum (.call/.soloMemo/.soloRoom) with capturesSystemAudio and micSpeaker computed properties, both synthesized from a single source of truth
- MeetingMetadata extended with mode field (default .call for backward-compatible Codable decoding of old JSONL sessions) and solo() factory
- TranscriptionEngine.start() now accepts meetingMode — system audio capture conditionally skipped; mic utterances use meetingMode.micSpeaker (Speaker.room for solo room)
- ContentView shows three start buttons ("Start Call" prominent, "Solo (memo)" and "Solo (room)" bordered); speakerLabel(for:) exhaustive switch used in both copyTranscript() and transcriptLogger append call
- 6 new MeetingStateTests added (58 total, all pass); TDD RED→GREEN followed

## Task Commits

Each task was committed atomically:

1. **Task 1: Add MeetingMode enum, extend MeetingMetadata and Speaker** - `0512e36` (feat)
2. **Task 2: Wire mode through TranscriptionEngine, AppCoordinator, and ContentView** - `1134e4b` (feat)

**Plan metadata:** TBD (docs: complete plan)

## Files Created/Modified
- `OpenOats/Sources/OpenOats/Meeting/MeetingTypes.swift` - Added MeetingMode enum, MeetingMetadata.mode field, MeetingMetadata.solo() factory
- `OpenOats/Sources/OpenOats/Models/Models.swift` - Added Speaker.room case
- `OpenOats/Sources/OpenOats/Transcription/TranscriptionEngine.swift` - Added meetingMode param, capturesSystemAudio gate, micSpeaker-aware startMicStream, currentMeetingMode stored property
- `OpenOats/Sources/OpenOats/App/AppCoordinator.swift` - Passes metadata.mode to transcriptionEngine.start()
- `OpenOats/Sources/OpenOats/Views/ContentView.swift` - Three ControlBarAction cases, startSession(mode:), speakerLabel(for:), pendingSessionMode, ControlBar wired with 3 new callbacks
- `OpenOats/Sources/OpenOats/Views/ControlBar.swift` - Three start buttons when !isRunning; onStartCall/onStartSoloMemo/onStartSoloRoom callbacks
- `OpenOats/Sources/OpenOats/Intelligence/MarkdownMeetingWriter.swift` - speakerLabel switch exhaustively covers .room (auto-fixed)
- `OpenOats/Tests/OpenOatsTests/MeetingStateTests.swift` - 6 new test methods: testMeetingModeEnum, testMeetingMetadataSoloFactory, testSpeakerRoomCase, testSoloMemoSessionLifecycle, testSoloRoomSessionLifecycle, testSoloModeSpeakerLabels

## Decisions Made
- TranscriptLogger takes String speaker labels, so the exhaustive Speaker switch lives in callers (ContentView.speakerLabel(for:), MarkdownMeetingWriter.speakerLabel(_:)) not in TranscriptLogger itself — this is architecturally correct and means the TranscriptLogger acceptance criterion (`grep "case .room" TranscriptLogger.swift`) does not literally match, but the intent (exhaustive labeling producing "Room") is fully satisfied
- Stored currentMeetingMode on TranscriptionEngine so performMicRestart() can preserve the correct micSpeaker during live device hot-swaps

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed non-exhaustive switch on Speaker in MarkdownMeetingWriter**
- **Found during:** Task 1 (after adding Speaker.room, swift test failed to compile)
- **Issue:** MarkdownMeetingWriter.speakerLabel(_:) had a two-case switch (.you, .them) that became non-exhaustive after adding .room; Swift compiler rejected the build
- **Fix:** Added `case .room: return "Room"` to the switch
- **Files modified:** OpenOats/Sources/OpenOats/Intelligence/MarkdownMeetingWriter.swift
- **Verification:** Build succeeded; 58 tests pass
- **Committed in:** 0512e36 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - Bug)
**Impact on plan:** Required for compilation; zero scope creep. The fix was already required by the plan's TranscriptLogger intent — the exhaustive switch existed in a closely related file.

## Issues Encountered
- The plan acceptance criterion `grep "case .room" TranscriptLogger.swift` does not match because TranscriptLogger uses String labels, not Speaker enum. The exhaustive speaker labeling is correct in the callers. This is an architecture reality, not a bug.

## User Setup Required
None - no external service configuration required.

## Self-Check: PASSED

All created files and commits verified present on disk.

## Next Phase Readiness
- All three recording modes wired end-to-end: .call (mic + system audio), .soloMemo (mic only, You), .soloRoom (mic only, Room)
- MeetingMetadata.mode is available for Phase 2 SummaryEngine to read and tailor meeting summaries accordingly
- No blockers
