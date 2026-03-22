import Foundation

actor SummaryEngine {

    // MARK: - Persisted format (written to disk as Markdown)

    struct PersistedSummary: Codable, Sendable {
        let sessionID: String
        let meetingTitle: String
        let startedAt: Date
        let decisions: [String]
        let actionItems: [String]
        let discussionPoints: [String]
        let openQuestions: [String]
        let generatedAt: Date
    }

    // MARK: - Provider config (captured on MainActor before calling actor methods)

    /// Sendable snapshot of provider configuration extracted from AppSettings on MainActor.
    struct ProviderConfig: Sendable {
        let apiKey: String?
        let baseURL: URL?
        let model: String
        let provider: LLMProvider
        let notesFolderPath: String

        @MainActor
        init(from settings: AppSettings) {
            self.notesFolderPath = settings.notesFolderPath
            self.provider = settings.llmProvider
            switch settings.llmProvider {
            case .openRouter:
                self.apiKey = settings.openRouterApiKey.isEmpty ? nil : settings.openRouterApiKey
                self.baseURL = nil
                self.model = settings.selectedModel
            case .ollama:
                self.apiKey = nil
                let base = settings.ollamaBaseURL.trimmingCharacters(in: .init(charactersIn: "/"))
                self.baseURL = URL(string: base + "/v1/chat/completions")
                self.model = settings.ollamaLLMModel
            case .mlx:
                self.apiKey = nil
                let base = settings.mlxBaseURL.trimmingCharacters(in: .init(charactersIn: "/"))
                self.baseURL = URL(string: base + "/v1/chat/completions")
                self.model = settings.mlxModel
            case .openAICompatible:
                let base = settings.openAILLMBaseURL.trimmingCharacters(in: .init(charactersIn: "/"))
                self.apiKey = settings.openAILLMApiKey.isEmpty ? nil : settings.openAILLMApiKey
                self.baseURL = URL(string: base + "/v1/chat/completions")
                self.model = settings.openAILLMModel
            }
        }
    }

    // MARK: - JSON schema for the formatting pass

    // nonisolated(unsafe) required because [String: Any] is not Sendable in Swift 6
    nonisolated(unsafe) static let summarySchema: [String: Any] = [
        "type": "object",
        "properties": [
            "decisions":        ["type": "array", "items": ["type": "string"]],
            "actionItems":      ["type": "array", "items": ["type": "string"]],
            "discussionPoints": ["type": "array", "items": ["type": "string"]],
            "openQuestions":    ["type": "array", "items": ["type": "string"]]
        ],
        "required": ["decisions", "actionItems", "discussionPoints", "openQuestions"],
        "additionalProperties": false
    ]

    private let client = OpenRouterClient()

    // MARK: - Generate

    /// Generate a structured summary from a session's transcript records.
    /// Call `ProviderConfig(from: settings)` on MainActor first, then pass the config here.
    /// Returns a PersistedSummary on success. Throws on unrecoverable failure.
    func generate(
        sessionID: String,
        records: [Utterance],
        session: SessionIndex?,
        config: ProviderConfig
    ) async throws -> PersistedSummary {
        guard !records.isEmpty else {
            throw SummaryError.emptyTranscript
        }

        let transcriptText = formatTranscript(records)

        // Phase 1 — Grounding pass: extract raw evidence citations
        let groundingMessages: [OpenRouterClient.Message] = [
            .init(role: "system", content: groundingSystemPrompt),
            .init(role: "user", content: "Meeting transcript:\n\n\(transcriptText)\n\nExtract evidence:")
        ]
        let groundedEvidence = try await client.complete(
            apiKey: config.apiKey,
            model: config.model,
            messages: groundingMessages,
            maxTokens: 2048,
            baseURL: config.baseURL
        )

        // Phase 2 — Formatting pass: structure evidence into four JSON sections
        let formattingMessages: [OpenRouterClient.Message] = [
            .init(role: "system", content: formattingSystemPrompt),
            .init(role: "user", content: "Evidence from transcript:\n\n\(groundedEvidence)\n\nReturn JSON:")
        ]
        let jsonString = try await client.completeStructured(
            apiKey: config.apiKey,
            model: config.model,
            messages: formattingMessages,
            jsonSchema: SummaryEngine.summarySchema,
            provider: config.provider,
            maxTokens: 1024,
            baseURL: config.baseURL
        )

        return try parseSummary(
            jsonString,
            sessionID: sessionID,
            session: session
        )
    }

    // MARK: - Convenience overload for AppSettings (MainActor callers)

    /// Convenience: accepts AppSettings directly. Must be called from a MainActor context
    /// since AppSettings is @MainActor. Captures config synchronously then delegates to generate(config:).
    @MainActor
    func generate(
        sessionID: String,
        records: [Utterance],
        session: SessionIndex?,
        settings: AppSettings
    ) async throws -> PersistedSummary {
        let config = ProviderConfig(from: settings)
        return try await generate(sessionID: sessionID, records: records, session: session, config: config)
    }

    // MARK: - Markdown Serialization

    /// Render a PersistedSummary as a Markdown string for disk persistence.
    static func markdownString(for summary: PersistedSummary) -> String {
        var lines: [String] = []
        lines.append("# \(summary.meetingTitle)")
        lines.append("")
        lines.append("## Key Decisions")
        lines.append(contentsOf: summary.decisions.isEmpty
            ? ["None recorded"]
            : summary.decisions.map { "- \($0)" })
        lines.append("")
        lines.append("## Action Items")
        lines.append(contentsOf: summary.actionItems.isEmpty
            ? ["None recorded"]
            : summary.actionItems.map { "- \($0)" })
        lines.append("")
        lines.append("## Discussion Points")
        lines.append(contentsOf: summary.discussionPoints.isEmpty
            ? ["None recorded"]
            : summary.discussionPoints.map { "- \($0)" })
        lines.append("")
        lines.append("## Open Questions")
        lines.append(contentsOf: summary.openQuestions.isEmpty
            ? ["None recorded"]
            : summary.openQuestions.map { "- \($0)" })
        return lines.joined(separator: "\n")
    }

    // MARK: - Private Helpers

    private func formatTranscript(_ records: [Utterance]) -> String {
        // Cap at ~60,000 characters. Keep first third + last third (drop middle).
        let lines = records.map { r -> String in
            let speaker = speakerLabel(r.speaker)
            return "\(speaker): \(r.refinedText ?? r.text)"
        }
        let full = lines.joined(separator: "\n")
        guard full.count > 60_000 else { return full }
        let third = lines.count / 3
        let kept = Array(lines.prefix(third)) + ["[...middle truncated...]"] + Array(lines.suffix(third))
        return kept.joined(separator: "\n")
    }

    private func speakerLabel(_ speaker: Speaker) -> String {
        switch speaker {
        case .you: return "You"
        case .them: return "Them"
        case .room: return "Room"
        }
    }

    private func parseSummary(
        _ jsonString: String,
        sessionID: String,
        session: SessionIndex?
    ) throws -> PersistedSummary {
        struct RawSummary: Decodable {
            let decisions: [String]
            let actionItems: [String]
            let discussionPoints: [String]
            let openQuestions: [String]
        }

        // Try direct JSON decode first
        let raw: RawSummary
        if let data = jsonString.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(RawSummary.self, from: data) {
            raw = decoded
        } else {
            // Fallback: scan for JSON object in the response (LLM may wrap it in markdown code block)
            let cleaned = extractJSONFromMarkdown(jsonString)
            guard let data = cleaned.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode(RawSummary.self, from: data) else {
                throw SummaryError.parseFailure(jsonString)
            }
            raw = decoded
        }

        return PersistedSummary(
            sessionID: sessionID,
            meetingTitle: session?.title ?? "Meeting",
            startedAt: session?.startedAt ?? Date(),
            decisions: raw.decisions,
            actionItems: raw.actionItems,
            discussionPoints: raw.discussionPoints,
            openQuestions: raw.openQuestions,
            generatedAt: Date()
        )
    }

    /// Strips markdown code-fence wrappers (```json ... ```) from an LLM response.
    /// Internal for testability.
    func extractJSONFromMarkdown(_ text: String) -> String {
        // Strip ```json ... ``` fences if present — find outermost { ... }
        if let start = text.range(of: "{"), let end = text.range(of: "}", options: .backwards) {
            // Use end.lowerBound (the position of "}") and include the character itself
            let endIndex = text.index(after: end.lowerBound)
            guard endIndex >= start.lowerBound else { return text }
            return String(text[start.lowerBound..<endIndex])
        }
        return text
    }

    // MARK: - Prompts

    private let groundingSystemPrompt = """
    You are a transcript analyst. Extract direct evidence from the meeting transcript.
    Do not summarize yet. For each of these four categories, copy relevant quotes and note the speaker:
    - Decisions made
    - Action items (with owner if named)
    - Topics discussed
    - Questions raised but not resolved

    Output plain text. Be terse. Include only what was explicitly said.
    """

    private let formattingSystemPrompt = """
    You are a meeting notes assistant. Given evidence extracted from a transcript, produce a casual JSON summary.
    Write like a colleague's quick notes — "We decided X", "Vincent to follow up on Y".
    Keep it brief and proportional to the amount of evidence.

    Output JSON matching this schema exactly:
    {"decisions": [...], "actionItems": [...], "discussionPoints": [...], "openQuestions": [...]}

    Each array contains strings. If a category has no evidence, return an empty array. Return only JSON, no markdown.
    """

    // MARK: - Errors

    enum SummaryError: Error, LocalizedError {
        case emptyTranscript
        case parseFailure(String)

        var errorDescription: String? {
            switch self {
            case .emptyTranscript: return "No transcript to summarize"
            case .parseFailure: return "Could not parse LLM summary response"
            }
        }
    }
}
