import Foundation

// MARK: - SlackFormatter

/// Pure formatting utility that converts a meeting summary into Slack mrkdwn format.
/// No SwiftUI, no async, no side effects.
struct SlackFormatter {

    // MARK: - Summary

    struct Summary {
        let meetingTitle: String
        let date: Date
        let decisions: [String]
        let actionItems: [String]
        let discussionPoints: [String]
        let openQuestions: [String]
    }

    // MARK: - Formatting

    /// Returns a Slack mrkdwn string with five sections: header, key decisions,
    /// action items, discussion points, and open questions.
    static func format(_ summary: Summary) -> String {
        var lines: [String] = []

        // Header
        lines.append("*Meeting: \(summary.meetingTitle) — \(dateString(summary.date))*")
        lines.append("")

        // Sections
        lines.append(contentsOf: section("Key Decisions", items: summary.decisions))
        lines.append("")
        lines.append(contentsOf: section("Action Items", items: summary.actionItems))
        lines.append("")
        lines.append(contentsOf: section("Discussion Points", items: summary.discussionPoints))
        lines.append("")
        lines.append(contentsOf: section("Open Questions", items: summary.openQuestions))

        return lines.joined(separator: "\n")
    }

    // MARK: - Private Helpers

    private static func section(_ title: String, items: [String]) -> [String] {
        var lines = ["*\(title)*"]
        if items.isEmpty {
            lines.append("• _None recorded_")
        } else {
            for item in items {
                lines.append("• \(item)")
            }
        }
        return lines
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private static func dateString(_ date: Date) -> String {
        formatter.string(from: date)
    }
}

// MARK: - transcriptRows

/// Returns (record, showTimestamp) pairs. The Bool is true for the first record
/// and for any record whose timestamp is ≥120 seconds after the last marked record.
func transcriptRows(for records: [SessionRecord]) -> [(SessionRecord, Bool)] {
    var result: [(SessionRecord, Bool)] = []
    var lastMarkerTimestamp: Date? = nil

    for record in records {
        let showTimestamp: Bool
        if let lastMarker = lastMarkerTimestamp {
            showTimestamp = record.timestamp.timeIntervalSince(lastMarker) >= 120
        } else {
            showTimestamp = true
        }

        if showTimestamp {
            lastMarkerTimestamp = record.timestamp
        }

        result.append((record, showTimestamp))
    }

    return result
}
