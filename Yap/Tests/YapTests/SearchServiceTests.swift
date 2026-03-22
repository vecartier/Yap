import Testing
import Foundation
@testable import OpenOatsKit

@Suite("SearchService")
struct SearchServiceTests {

    // MARK: - Helpers

    private static func makeSession(
        id: String,
        title: String?,
        startedAt: Date = Date()
    ) -> SessionIndex {
        SessionIndex(
            id: id,
            startedAt: startedAt,
            title: title,
            utteranceCount: 0,
            hasNotes: false
        )
    }

    // MARK: - Title match

    @Test("search matches session by title")
    func searchMatchesTitle() async throws {
        let service = SearchService()
        let store = SessionStore(rootDirectory: URL(fileURLWithPath: NSTemporaryDirectory()))
        let session = Self.makeSession(id: "s1", title: "Q4 Decision Meeting")
        let results = await service.search(
            query: "decision",
            sessions: [session],
            store: store,
            notesFolderPath: NSTemporaryDirectory()
        )
        #expect(results.contains(session))
    }

    // MARK: - No match

    @Test("search returns empty when query not found")
    func searchReturnsEmptyWhenNoMatch() async throws {
        let service = SearchService()
        let store = SessionStore(rootDirectory: URL(fileURLWithPath: NSTemporaryDirectory()))
        let session = Self.makeSession(id: "s2", title: "Team Standup")
        let results = await service.search(
            query: "coffee",
            sessions: [session],
            store: store,
            notesFolderPath: NSTemporaryDirectory()
        )
        #expect(results.isEmpty)
    }

    // MARK: - Case-insensitive

    @Test("search is case-insensitive via localizedStandardContains")
    func searchIsCaseInsensitive() async throws {
        let service = SearchService()
        let store = SessionStore(rootDirectory: URL(fileURLWithPath: NSTemporaryDirectory()))
        let session = Self.makeSession(id: "s3", title: "Budget Review")
        let results = await service.search(
            query: "budget",
            sessions: [session],
            store: store,
            notesFolderPath: NSTemporaryDirectory()
        )
        #expect(results.contains(session))
    }

    // MARK: - Cache eviction

    @Test("evictCache removes cached text for session")
    func evictCacheRemovesEntry() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("evict-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let store = SessionStore(rootDirectory: tmpDir)
        let session = Self.makeSession(id: "s4", title: "Alpha")
        let service = SearchService()

        // Prime the cache
        _ = await service.search(
            query: "alpha",
            sessions: [session],
            store: store,
            notesFolderPath: tmpDir.path
        )

        // Evict
        await service.evictCache(sessionID: "s4")

        // Second search should still work (re-loads from store)
        let results = await service.search(
            query: "alpha",
            sessions: [session],
            store: store,
            notesFolderPath: tmpDir.path
        )
        #expect(results.contains(session))
    }

    // MARK: - Results sorted by startedAt descending

    @Test("search results sorted by startedAt descending")
    func searchResultsSortedDescending() async throws {
        let service = SearchService()
        let store = SessionStore(rootDirectory: URL(fileURLWithPath: NSTemporaryDirectory()))
        let older = Self.makeSession(
            id: "old",
            title: "Marketing Review",
            startedAt: Date(timeIntervalSinceNow: -7200)
        )
        let newer = Self.makeSession(
            id: "new",
            title: "Marketing Sync",
            startedAt: Date(timeIntervalSinceNow: -3600)
        )
        let results = await service.search(
            query: "marketing",
            sessions: [older, newer],
            store: store,
            notesFolderPath: NSTemporaryDirectory()
        )
        #expect(results.count == 2)
        #expect(results[0].id == "new")
        #expect(results[1].id == "old")
    }

    // MARK: - Summary file match

    @Test("search matches text in summary markdown file")
    func searchMatchesSummaryFile() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("summary-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let store = SessionStore(rootDirectory: tmpDir)
        let session = Self.makeSession(id: "s5", title: nil)

        // Write a summary file
        let summaryURL = tmpDir.appendingPathComponent("s5-summary.md")
        try "## Key Decisions\n- Approved the roadmap".write(to: summaryURL, atomically: true, encoding: .utf8)

        let service = SearchService()
        let results = await service.search(
            query: "roadmap",
            sessions: [session],
            store: store,
            notesFolderPath: tmpDir.path
        )
        #expect(results.contains(session))
    }
}
