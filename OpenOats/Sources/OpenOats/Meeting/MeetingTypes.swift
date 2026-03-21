import Foundation

// MARK: - Meeting App Detection

/// A running application that may host meetings.
struct MeetingApp: Sendable, Hashable, Codable {
    let bundleID: String
    let name: String
}

/// A single entry in the list of known meeting apps.
struct MeetingAppEntry: Sendable, Hashable, Codable {
    let bundleID: String
    let displayName: String
}

// MARK: - Detection Signal

/// Describes why the system believes a meeting started or ended.
enum DetectionSignal: Sendable, Hashable, Codable {
    /// User pressed Start manually.
    case manual
    /// A known meeting app was detected running.
    case appLaunched(MeetingApp)
    /// A calendar event started.
    case calendarEvent(CalendarEvent)
    /// Audio activity was detected from a meeting source.
    case audioActivity
}

// MARK: - Detection Context

/// Aggregated context about an active or pending meeting.
struct DetectionContext: Sendable, Equatable, Codable {
    let signal: DetectionSignal
    let detectedAt: Date
    let meetingApp: MeetingApp?
    let calendarEvent: CalendarEvent?
}

// MARK: - Calendar Integration

/// Minimal representation of a calendar event relevant to meeting detection.
struct CalendarEvent: Sendable, Hashable, Codable, Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let organizer: String?
    let participants: [Participant]
    let isOnlineMeeting: Bool
    let meetingURL: URL?
}

/// A meeting participant from a calendar event.
struct Participant: Sendable, Hashable, Codable {
    let name: String?
    let email: String?
}

// MARK: - Meeting Mode

/// Determines which audio streams are captured and how speakers are labeled.
enum MeetingMode: String, Sendable, Codable, Equatable {
    case call       // mic + system audio; "You" + "Them" speakers
    case soloMemo   // mic only; "You" speaker — personal voice memo
    case soloRoom   // mic only; "Room" speaker — in-person meeting via laptop mic

    /// True only for .call mode where system audio capture is needed.
    var capturesSystemAudio: Bool {
        self == .call
    }

    /// The Speaker label to apply to mic-transcribed utterances.
    var micSpeaker: Speaker {
        switch self {
        case .call, .soloMemo: return .you
        case .soloRoom: return .room
        }
    }
}

// MARK: - Meeting Metadata

/// Metadata assembled during a meeting session (detection context + calendar info).
struct MeetingMetadata: Sendable, Equatable, Codable {
    let detectionContext: DetectionContext?
    let calendarEvent: CalendarEvent?
    let title: String?
    let startedAt: Date
    var endedAt: Date?
    var mode: MeetingMode = .call

    static func manual() -> MeetingMetadata {
        let now = Date()
        return MeetingMetadata(
            detectionContext: DetectionContext(
                signal: .manual, detectedAt: now,
                meetingApp: nil, calendarEvent: nil
            ),
            calendarEvent: nil, title: nil,
            startedAt: now, endedAt: nil,
            mode: .call
        )
    }

    static func solo(_ mode: MeetingMode) -> MeetingMetadata {
        MeetingMetadata(
            detectionContext: nil,
            calendarEvent: nil,
            title: nil,
            startedAt: Date(),
            endedAt: nil,
            mode: mode
        )
    }
}
