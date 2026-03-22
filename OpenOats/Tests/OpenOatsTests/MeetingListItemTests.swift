import XCTest
@testable import OpenOatsKit

final class MeetingListItemTests: XCTestCase {

    // MARK: - MeetingListItem.live identity

    func testLiveItemIDIsLiveSentinel() {
        XCTAssertEqual(MeetingListItem.live.id, "_live_",
                       "MeetingListItem.live.id must equal the _live_ sentinel string")
    }

    // MARK: - MeetingListItem.session identity

    func testSessionItemIDMatchesSessionID() {
        let session = SessionIndex(
            id: "test-session-abc",
            startedAt: Date(),
            utteranceCount: 3,
            hasNotes: false
        )
        let item = MeetingListItem.session(session)
        XCTAssertEqual(item.id, session.id,
                       "MeetingListItem.session(s).id must equal s.id")
    }

    // MARK: - Equatable / Hashable

    func testTwoLiveCasesAreEqual() {
        XCTAssertEqual(MeetingListItem.live, MeetingListItem.live,
                       "Two .live cases must be equal (Equatable)")
    }

    func testSessionItemsWithDifferentIDsAreNotEqual() {
        let s1 = SessionIndex(id: "id-1", startedAt: Date(), utteranceCount: 0, hasNotes: false)
        let s2 = SessionIndex(id: "id-2", startedAt: Date(), utteranceCount: 0, hasNotes: false)
        XCTAssertNotEqual(MeetingListItem.session(s1), MeetingListItem.session(s2),
                          "MeetingListItem.session(s1) must not equal .session(s2) when s1.id != s2.id")
    }

    // MARK: - Hashable (usable in Set / Dictionary)

    func testLiveItemIsHashable() {
        var set = Set<MeetingListItem>()
        set.insert(.live)
        set.insert(.live)
        XCTAssertEqual(set.count, 1,
                       "Inserting .live twice into a Set must yield exactly one element")
    }
}
