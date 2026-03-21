import XCTest
@testable import OpenOatsKit

final class SidebarDateGroupingTests: XCTestCase {

    private func makeSession(daysAgo: Int) -> SessionIndex {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        return SessionIndex(id: "test-\(daysAgo)", startedAt: date, utteranceCount: 0, hasNotes: false)
    }

    func testEmptyArrayReturnsNoGroups() {
        let result = groupedSessions([])
        XCTAssertTrue(result.isEmpty)
    }

    func testTodaySessionGoesToTodayGroup() {
        let session = makeSession(daysAgo: 0)
        let result = groupedSessions([session])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].label, "Today")
        XCTAssertEqual(result[0].sessions.count, 1)
    }

    func testYesterdaySessionGoesToYesterdayGroup() {
        let session = makeSession(daysAgo: 1)
        let result = groupedSessions([session])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].label, "Yesterday")
    }

    func testFiveDaysAgoGoesToLastSevenDays() {
        let session = makeSession(daysAgo: 5)
        let result = groupedSessions([session])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].label, "Last 7 Days")
    }

    func testThirtyDaysAgoGoesToEarlier() {
        let session = makeSession(daysAgo: 30)
        let result = groupedSessions([session])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].label, "Earlier")
    }

    func testMixedSessionsProduceCorrectGroups() {
        let today = makeSession(daysAgo: 0)
        let earlier = makeSession(daysAgo: 30)
        let result = groupedSessions([today, earlier])
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].label, "Today")
        XCTAssertEqual(result[1].label, "Earlier")
    }

    func testEmptySectionsAreOmitted() {
        // Only an earlier session — Today, Yesterday, Last 7 Days sections must not appear
        let session = makeSession(daysAgo: 30)
        let result = groupedSessions([session])
        let labels = result.map { $0.label }
        XCTAssertFalse(labels.contains("Today"))
        XCTAssertFalse(labels.contains("Yesterday"))
        XCTAssertFalse(labels.contains("Last 7 Days"))
    }

    func testSessionOrderWithinGroupPreserved() {
        // Two today sessions — order must match input order
        let s1 = makeSession(daysAgo: 0)
        let s2 = SessionIndex(id: "test-0b", startedAt: Date(), utteranceCount: 0, hasNotes: false)
        let result = groupedSessions([s1, s2])
        XCTAssertEqual(result[0].sessions[0].id, s1.id)
        XCTAssertEqual(result[0].sessions[1].id, s2.id)
    }
}
