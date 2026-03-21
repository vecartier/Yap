import SwiftUI

// Free function — accessible via @testable import for unit tests
func groupedSessions(_ sessions: [SessionIndex]) -> [(label: String, sessions: [SessionIndex])] {
    let cal = Calendar.current
    let now = Date()
    let sections: [(String, (SessionIndex) -> Bool)] = [
        ("Today",       { cal.isDateInToday($0.startedAt) }),
        ("Yesterday",   { cal.isDateInYesterday($0.startedAt) }),
        ("Last 7 Days", {
            guard let cutoff = cal.date(byAdding: .day, value: -7, to: now) else { return false }
            return $0.startedAt >= cutoff
                && !cal.isDateInToday($0.startedAt)
                && !cal.isDateInYesterday($0.startedAt)
        }),
        ("Earlier", { _ in true })
    ]
    var remaining = sessions
    var result: [(label: String, sessions: [SessionIndex])] = []
    for (label, predicate) in sections {
        let matched = remaining.filter(predicate)
        remaining.removeAll(where: predicate)
        if !matched.isEmpty { result.append((label: label, sessions: matched)) }
    }
    return result
}

struct MeetingSidebarView: View {
    @Binding var selectedSessionID: String?
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        Group {
            if coordinator.sessionHistory.isEmpty {
                ContentUnavailableView(
                    "No meetings yet",
                    systemImage: "waveform",
                    description: Text("Start a recording to see your meetings here.")
                )
            } else {
                List(selection: $selectedSessionID) {
                    ForEach(groupedSessions(coordinator.sessionHistory), id: \.label) { group in
                        Section(group.label) {
                            ForEach(group.sessions) { session in
                                MeetingRowView(session: session)
                                    .tag(session.id)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .task {
            await coordinator.loadHistory()
        }
    }
}

struct MeetingRowView: View {
    let session: SessionIndex

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: typeSymbol(for: session))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(displayTitle(for: session))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            HStack(spacing: 8) {
                if let duration = formattedDuration(for: session) {
                    Text(duration)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(shortDateString(for: session))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityIdentifier("main.meetingRow.\(session.id)")
    }

    private func displayTitle(for session: SessionIndex) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        let timeString = formatter.string(from: session.startedAt)
        if let app = session.meetingApp, !app.isEmpty {
            return "\(app) — \(timeString)"
        } else if let template = session.templateSnapshot {
            return "\(template.name) — \(timeString)"
        }
        return "Meeting — \(timeString)"
    }

    private func formattedDuration(for session: SessionIndex) -> String? {
        guard let endedAt = session.endedAt else { return nil }
        let interval = endedAt.timeIntervalSince(session.startedAt)
        guard interval > 0 else { return nil }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute]
        formatter.zeroFormattingBehavior = .dropLeading
        return formatter.string(from: interval)
    }

    private func shortDateString(for session: SessionIndex) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: session.startedAt)
    }

    private func typeSymbol(for session: SessionIndex) -> String {
        if let app = session.meetingApp, !app.isEmpty {
            return "video.fill"
        }
        return "mic.fill"
    }
}
