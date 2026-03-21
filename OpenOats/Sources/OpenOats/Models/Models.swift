import Foundation

enum Speaker: String, Codable, Sendable {
    case you
    case them
}

enum RefinementStatus: String, Codable, Sendable {
    case pending, completed, failed, skipped
}

struct Utterance: Identifiable, Codable, Sendable {
    let id: UUID
    let text: String
    let speaker: Speaker
    let timestamp: Date
    let refinedText: String?
    let refinementStatus: RefinementStatus?

    init(text: String, speaker: Speaker, timestamp: Date = .now, refinedText: String? = nil, refinementStatus: RefinementStatus? = nil) {
        self.id = UUID()
        self.text = text
        self.speaker = speaker
        self.timestamp = timestamp
        self.refinedText = refinedText
        self.refinementStatus = refinementStatus
    }

    /// The best available text: refined if available, otherwise raw.
    var displayText: String {
        refinedText ?? text
    }

    func withRefinement(text: String?, status: RefinementStatus) -> Utterance {
        Utterance(
            id: self.id,
            text: self.text,
            speaker: self.speaker,
            timestamp: self.timestamp,
            refinedText: text,
            refinementStatus: status
        )
    }

    /// Private memberwise init that preserves an existing ID.
    private init(id: UUID, text: String, speaker: Speaker, timestamp: Date, refinedText: String?, refinementStatus: RefinementStatus?) {
        self.id = id
        self.text = text
        self.speaker = speaker
        self.timestamp = timestamp
        self.refinedText = refinedText
        self.refinementStatus = refinementStatus
    }
}

// MARK: - Conversation State

struct ConversationState: Sendable, Codable {
    var currentTopic: String
    var shortSummary: String
    var openQuestions: [String]
    var activeTensions: [String]
    var recentDecisions: [String]
    var lastUpdatedAt: Date

    static let empty = ConversationState(
        currentTopic: "",
        shortSummary: "",
        openQuestions: [],
        activeTensions: [],
        recentDecisions: [],
        lastUpdatedAt: .distantPast
    )
}

// MARK: - Session Record

/// Codable record for JSONL session persistence
struct SessionRecord: Codable {
    let speaker: Speaker
    let text: String
    let timestamp: Date
    let conversationStateSummary: String?
    let refinedText: String?

    init(
        speaker: Speaker,
        text: String,
        timestamp: Date,
        conversationStateSummary: String? = nil,
        refinedText: String? = nil
    ) {
        self.speaker = speaker
        self.text = text
        self.timestamp = timestamp
        self.conversationStateSummary = conversationStateSummary
        self.refinedText = refinedText
    }

    func withRefinedText(_ text: String?) -> SessionRecord {
        SessionRecord(
            speaker: speaker, text: self.text, timestamp: timestamp,
            conversationStateSummary: conversationStateSummary,
            refinedText: text
        )
    }
}

// MARK: - Meeting Templates & Enhanced Notes

struct MeetingTemplate: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    var name: String
    var icon: String
    var systemPrompt: String
    var isBuiltIn: Bool
}

struct TemplateSnapshot: Codable, Sendable {
    let id: UUID
    let name: String
    let icon: String
    let systemPrompt: String
}

struct EnhancedNotes: Codable, Sendable {
    let template: TemplateSnapshot
    let generatedAt: Date
    let markdown: String
}

struct SessionIndex: Identifiable, Codable, Sendable {
    let id: String
    let startedAt: Date
    var endedAt: Date?
    var templateSnapshot: TemplateSnapshot?
    var title: String?
    var utteranceCount: Int
    var hasNotes: Bool
    /// The detected meeting application name (e.g. "Zoom", "Microsoft Teams").
    var meetingApp: String?
    /// The ASR engine used for transcription (e.g. "parakeetV2").
    var engine: String?
}

struct SessionSidecar: Codable, Sendable {
    let index: SessionIndex
    var notes: EnhancedNotes?
}
