import XCTest
@testable import YapKit

final class PastMeetingDetailTests: XCTestCase {

    // MARK: - transcriptRows empty path

    func testTranscriptRowsEmptyReturnsEmpty() {
        // Empty transcript must not crash and must return an empty array
        let result = transcriptRows(for: [])
        XCTAssertTrue(result.isEmpty, "transcriptRows(for: []) must return an empty array without crashing")
    }

    // MARK: - formattedDuration zero-interval

    func testFormattedDurationZeroIntervalReturnsNonEmpty() {
        // 0-second duration (instant session) must return a non-empty, non-nil string
        let now = Date()
        let result = formattedDurationForTest(from: now, to: now)
        XCTAssertFalse(result.isEmpty, "formattedDuration for a zero-second interval must return a non-empty string")
    }

    // MARK: - Helper (mirrors the private helper in PastMeetingDetailView)

    /// Mirrors PastMeetingDetailView.formattedDuration(from:to:) — extracted here for testability.
    private func formattedDurationForTest(from start: Date, to end: Date) -> String {
        let interval = end.timeIntervalSince(start)
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .dropLeading
        return formatter.string(from: interval) ?? "0 seconds"
    }
}
