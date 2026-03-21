import XCTest
@testable import OpenOatsKit

final class TranscriptTimestampTests: XCTestCase {

    // MARK: - Helpers

    private let base = Date(timeIntervalSinceReferenceDate: 0)

    private func record(at seconds: TimeInterval, speaker: Speaker = .you) -> SessionRecord {
        SessionRecord(speaker: speaker, text: "text at \(seconds)s", timestamp: base.addingTimeInterval(seconds))
    }

    // MARK: - Empty Input

    func testEmptyArrayReturnsEmpty() {
        let result = transcriptRows(for: [])
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Single Record

    func testSingleRecordAlwaysShowsTimestamp() {
        let r = record(at: 0)
        let result = transcriptRows(for: [r])
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result[0].1, "First record must always have showTimestamp = true")
    }

    // MARK: - Below Threshold

    func testRecordAt60sDoesNotTriggerNewMarker() {
        let r0 = record(at: 0)
        let r60 = record(at: 60)
        let result = transcriptRows(for: [r0, r60])
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result[0].1, "r0 must show timestamp")
        XCTAssertFalse(result[1].1, "r60 (60s < 120s threshold) must not show timestamp")
    }

    func testRecordAt119sDoesNotTriggerNewMarker() {
        let r0 = record(at: 0)
        let r119 = record(at: 119)
        let result = transcriptRows(for: [r0, r119])
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result[0].1)
        XCTAssertFalse(result[1].1, "r119 (119s < 120s threshold) must not show timestamp")
    }

    // MARK: - At Threshold

    func testRecordAtExactly120sTriggersNewMarker() {
        let r0 = record(at: 0)
        let r120 = record(at: 120)
        let result = transcriptRows(for: [r0, r120])
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result[0].1)
        XCTAssertTrue(result[1].1, "r120 (exactly 120s) must show timestamp")
    }

    // MARK: - Cumulative (last marker, not last record)

    func testCumulativeMarkingFromLastMarker() {
        // r0 at T=0 (marker), r1 at T=60 (no marker), r2 at T=130 (130s since last marker at T=0 → marker)
        let r0 = record(at: 0)
        let r1 = record(at: 60)
        let r2 = record(at: 130)
        let result = transcriptRows(for: [r0, r1, r2])
        XCTAssertEqual(result.count, 3)
        XCTAssertTrue(result[0].1, "r0 must be a marker")
        XCTAssertFalse(result[1].1, "r1 (60s from last marker) must not be a marker")
        XCTAssertTrue(result[2].1, "r2 (130s from last marker at T=0) must be a marker")
    }

    func testMarkerUpdatesAfterNewMarkerIsSet() {
        // r0=T0 (marker), r1=T130 (marker, resets clock), r2=T200 (70s from T130 — no marker)
        let r0 = record(at: 0)
        let r1 = record(at: 130)
        let r2 = record(at: 200)
        let result = transcriptRows(for: [r0, r1, r2])
        XCTAssertTrue(result[0].1, "r0 must be marker")
        XCTAssertTrue(result[1].1, "r1 (130s from r0) must be marker")
        XCTAssertFalse(result[2].1, "r2 (70s from r1 marker) must NOT be marker")
    }

    // MARK: - Record identity preserved

    func testRecordIdentityPreserved() {
        let r0 = record(at: 0, speaker: .you)
        let r1 = record(at: 60, speaker: .them)
        let result = transcriptRows(for: [r0, r1])
        XCTAssertEqual(result[0].0.speaker, .you)
        XCTAssertEqual(result[1].0.speaker, .them)
    }
}
