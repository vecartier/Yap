---
phase: 06-search-export
plan: 02
subsystem: ui
tags: [pdf, nsprintoperation, nsattributedstring, nssavepanel, export, appkit]

# Dependency graph
requires:
  - phase: 05-summary-engine-settings
    provides: SummaryEngine.PersistedSummary struct used in PDFExporter.Content
  - phase: 03-past-meeting-detail
    provides: PastMeetingDetailView, SessionRecord, SessionIndex models
provides:
  - PDFExporter struct writing paginated multi-page PDF via NSPrintOperation
  - Export PDF button in PastMeetingDetailView alongside Copy for Slack
affects: [future export features]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "NSPrintInfo.shared.mutableCopy() — never mutate shared NSPrintInfo directly"
    - "@MainActor on AppKit PDF operations — NSPrintOperation requires main actor"
    - "NSMutableData intermediate for pdfOperation, then write(to:options:atomic) to URL"

key-files:
  created:
    - OpenOats/Sources/OpenOats/Export/PDFExporter.swift
  modified:
    - OpenOats/Sources/OpenOats/Views/PastMeetingDetailView.swift

key-decisions:
  - "PDFExporter.export() is @MainActor — NSPrintOperation requires main actor in Swift 6 strict concurrency; Task.detached caller uses await"
  - "NSPrintOperation.pdfOperation(to:) takes NSMutableData not URL — write NSMutableData to URL after op.run()"
  - "verticalPagination = .automatic (not .auto which doesn't exist in Swift 4.2+)"

patterns-established:
  - "Export layer lives in Export/ subfolder — separate from Views and Intelligence"
  - "PDF content struct (PDFExporter.Content) bundles all inputs — pure function interface"

requirements-completed: [EXPRT-01, EXPRT-02]

# Metrics
duration: 12min
completed: 2026-03-22
---

# Phase 06 Plan 02: PDF Export Summary

**Paginated multi-page PDF export via NSPrintOperation.pdfOperation with NSSavePanel, composing NSAttributedString from meeting metadata, summary sections, and full transcript.**

## Performance

- **Duration:** 12 min
- **Started:** 2026-03-22T14:12:19Z
- **Completed:** 2026-03-22T14:23:44Z
- **Tasks:** 2
- **Files modified:** 2 (1 created, 1 modified)

## Accomplishments

- PDFExporter pure struct in new Export/ folder composes NSAttributedString with title, metadata, summary sections (if any), and transcript
- NSPrintInfo.shared.mutableCopy() ensures shared instance is never mutated; US Letter size with 72pt margins
- NSSavePanel opens on MainActor with .pdf content type defaulting to ~/Documents; PDF write dispatched via Task.detached
- Export PDF button appears alongside Copy for Slack in PastMeetingDetailView; export always available regardless of summary presence

## Task Commits

Each task was committed atomically:

1. **Task 1: Create PDFExporter struct** - `dd5dd17` (feat)
2. **Task 2: Add Export PDF button to PastMeetingDetailView** - `5e5c2fd` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified

- `OpenOats/Sources/OpenOats/Export/PDFExporter.swift` - Pure struct: PDFExporter, PDFExporter.Content, static export(_:to:) writing PDF via NSPrintOperation
- `OpenOats/Sources/OpenOats/Views/PastMeetingDetailView.swift` - Added Export PDF button to slackActionsRow HStack, added exportPDF() function, added import UniformTypeIdentifiers

## Decisions Made

- **PDFExporter.export() is @MainActor**: NSPrintOperation is AppKit and requires main actor in Swift 6 strict concurrency. The plan specified `Task.detached` for the PDF write but Swift 6 rejects sending `NSMutableData` to main-actor-isolated `pdfOperation`. Annotating `export()` as `@MainActor` resolves the data race error while preserving correct behavior (caller uses `await` in `Task.detached`).
- **NSMutableData intermediate**: `NSPrintOperation.pdfOperation(with:inside:to:printInfo:)` takes `NSMutableData`, not `URL`. After `op.run()`, the data is written atomically to the user-chosen URL.
- **`.automatic` pagination**: `NSPrintInfo.PaginationMode.auto` does not exist; the correct name is `.automatic`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed NSPrintOperation.pdfOperation parameter type**
- **Found during:** Task 1 (Create PDFExporter struct)
- **Issue:** Plan specified `to: fileURL` (URL) but the API parameter type is `NSMutableData`. Build error: "cannot convert value of type 'URL' to expected argument type 'NSMutableData'"
- **Fix:** Use `NSMutableData()` as intermediate, call `pdfData.write(to: fileURL, options: .atomic)` after `op.run()`
- **Files modified:** OpenOats/Sources/OpenOats/Export/PDFExporter.swift
- **Verification:** Build succeeded
- **Committed in:** dd5dd17 (Task 1 commit)

**2. [Rule 1 - Bug] Fixed NSPrintInfo.PaginationMode.auto → .automatic**
- **Found during:** Task 1 (Create PDFExporter struct)
- **Issue:** Plan used `.auto` which doesn't exist; renamed to `.automatic` in Swift 4.2+. Build error: "type 'NSPrintInfo.PaginationMode' has no member 'auto'"
- **Fix:** Changed `printInfo.verticalPagination = .auto` to `.automatic`
- **Files modified:** OpenOats/Sources/OpenOats/Export/PDFExporter.swift
- **Verification:** Build succeeded
- **Committed in:** dd5dd17 (Task 1 commit)

**3. [Rule 1 - Bug] Fixed Swift 6 SendingRisksDataRace on NSMutableData**
- **Found during:** Task 1 (Create PDFExporter struct)
- **Issue:** `NSMutableData` sent to main-actor-isolated `pdfOperation` from nonisolated context caused Swift 6 data race error
- **Fix:** Annotated `PDFExporter.export()` as `@MainActor`; Task.detached caller uses `await`
- **Files modified:** OpenOats/Sources/OpenOats/Export/PDFExporter.swift
- **Verification:** Build succeeded
- **Committed in:** dd5dd17 (Task 1 commit)

---

**Total deviations:** 3 auto-fixed (all Rule 1 - Bug)
**Impact on plan:** All three fixes were required to compile. Plan's specified API signatures had two incorrect types and one naming error. No scope creep; behavior matches plan intent exactly.

## Issues Encountered

None beyond the three auto-fixed build errors above.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- PDF export is complete and builds clean
- Phase 06 (search + export) is now fully implemented: 06-01 search, 06-02 PDF export
- v1.0 milestone complete

---
*Phase: 06-search-export*
*Completed: 2026-03-22*
