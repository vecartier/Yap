import Foundation

actor SearchService {
    private var cache: [String: String] = [:]

    func search(
        query: String,
        sessions: [SessionIndex],
        store: SessionStore,
        notesFolderPath: String
    ) async -> [SessionIndex] {
        return await withTaskGroup(of: (SessionIndex, Bool).self) { group in
            for session in sessions {
                group.addTask {
                    let text = await self.searchableText(for: session, store: store, notesFolderPath: notesFolderPath)
                    let matches = text.localizedStandardContains(query)
                    return (session, matches)
                }
            }
            var results: [SessionIndex] = []
            for await (session, matches) in group where matches {
                results.append(session)
            }
            return results.sorted { $0.startedAt > $1.startedAt }
        }
    }

    private func searchableText(
        for session: SessionIndex,
        store: SessionStore,
        notesFolderPath: String
    ) async -> String {
        if let cached = cache[session.id] { return cached }

        var parts: [String] = []
        if let title = session.title { parts.append(title) }
        let records = await store.loadTranscript(sessionID: session.id)
        let transcriptText = records.map { $0.refinedText ?? $0.text }.joined(separator: " ")
        parts.append(transcriptText)
        let summaryURL = URL(fileURLWithPath: notesFolderPath)
            .appendingPathComponent("\(session.id)-summary.md")
        if let summaryText = try? String(contentsOf: summaryURL, encoding: .utf8) {
            parts.append(summaryText)
        }

        let combined = parts.joined(separator: " ")
        cache[session.id] = combined
        return combined
    }

    func evictCache(sessionID: String) {
        cache.removeValue(forKey: sessionID)
    }

    func clearCache() {
        cache.removeAll()
    }
}
