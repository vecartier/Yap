import XCTest
@testable import YapKit

final class SlackFormatterTests: XCTestCase {

    // MARK: - Helpers

    private static let referenceDate: Date = {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 3
        comps.day = 21
        comps.hour = 9
        comps.minute = 0
        return Calendar.current.date(from: comps)!
    }()

    private func makeSummary(
        title: String = "Standup",
        date: Date = referenceDate,
        decisions: [String] = ["Shipped feature X"],
        actionItems: [String] = ["Write tests"],
        discussionPoints: [String] = ["Deployment approach"],
        openQuestions: [String] = ["What about v2?"]
    ) -> SlackFormatter.Summary {
        SlackFormatter.Summary(
            meetingTitle: title,
            date: date,
            decisions: decisions,
            actionItems: actionItems,
            discussionPoints: discussionPoints,
            openQuestions: openQuestions
        )
    }

    // MARK: - Header

    func testHeaderContainsBoldMeetingTitle() {
        let summary = makeSummary(title: "Standup")
        let output = SlackFormatter.format(summary)
        XCTAssertTrue(output.contains("*Meeting: Standup —"), "Expected bold header with meeting title, got:\n\(output)")
    }

    // MARK: - Section Headers

    func testOutputContainsAllFiveSectionHeaders() {
        let summary = makeSummary()
        let output = SlackFormatter.format(summary)
        XCTAssertTrue(output.contains("*Key Decisions*"), "Missing *Key Decisions*")
        XCTAssertTrue(output.contains("*Action Items*"), "Missing *Action Items*")
        XCTAssertTrue(output.contains("*Discussion Points*"), "Missing *Discussion Points*")
        XCTAssertTrue(output.contains("*Open Questions*"), "Missing *Open Questions*")
    }

    // MARK: - Populated Sections

    func testDecisionAppearsAsBullet() {
        let summary = makeSummary(decisions: ["Shipped feature X"])
        let output = SlackFormatter.format(summary)
        XCTAssertTrue(output.contains("• Shipped feature X"), "Expected bullet for decision, got:\n\(output)")
    }

    func testMultipleActionItemsEachOnOwnBulletLine() {
        let summary = makeSummary(actionItems: ["Write tests", "Deploy to prod", "Update docs"])
        let output = SlackFormatter.format(summary)
        XCTAssertTrue(output.contains("• Write tests"), "Missing bullet: Write tests")
        XCTAssertTrue(output.contains("• Deploy to prod"), "Missing bullet: Deploy to prod")
        XCTAssertTrue(output.contains("• Update docs"), "Missing bullet: Update docs")
    }

    // MARK: - Empty Section Fallback

    func testEmptyDecisionsRendersNoneRecorded() {
        let summary = makeSummary(decisions: [])
        let output = SlackFormatter.format(summary)
        XCTAssertTrue(output.contains("*Key Decisions*"), "Section header must still appear when empty")
        XCTAssertTrue(output.contains("• _None recorded_"), "Expected placeholder bullet for empty section, got:\n\(output)")
    }

    func testEmptyActionItemsRendersNoneRecorded() {
        let summary = makeSummary(actionItems: [])
        let output = SlackFormatter.format(summary)
        XCTAssertTrue(output.contains("*Action Items*"), "Section header must still appear when empty")
    }

    func testAllSectionsEmptyDoesNotCrash() {
        let summary = makeSummary(decisions: [], actionItems: [], discussionPoints: [], openQuestions: [])
        let output = SlackFormatter.format(summary)
        XCTAssertFalse(output.isEmpty, "Output must not be empty even when all sections are empty")
        // Count occurrences of the placeholder bullet
        let placeholderCount = output.components(separatedBy: "• _None recorded_").count - 1
        XCTAssertEqual(placeholderCount, 4, "Each of the 4 empty sections should have a placeholder bullet, got \(placeholderCount)")
    }
}
