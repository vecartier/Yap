import SwiftUI

// MARK: - PastMeetingDetailView

struct PastMeetingDetailView: View {
    let sessionID: String
    @Bindable var settings: AppSettings
    @Environment(AppCoordinator.self) private var coordinator
    @State private var rows: [(SessionRecord, Bool)] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                metadataHeader
                summaryPlaceholderCard
                    .padding(.top, 20)
                slackActionsRow
                    .padding(.top, 12)
                transcriptDivider
                transcriptSection
            }
            .padding(20)
        }
        .task(id: sessionID) {
            isLoading = true
            rows = []
            let loaded = await coordinator.sessionStore.loadTranscript(sessionID: sessionID)
            rows = transcriptRows(for: loaded)
            isLoading = false
        }
    }

    // MARK: - Metadata Header

    @ViewBuilder
    private var metadataHeader: some View {
        if let session = coordinator.sessionHistory.first(where: { $0.id == sessionID }) {
            VStack(alignment: .leading, spacing: 8) {
                Text(session.title ?? "Untitled")
                    .font(.title3)
                    .fontWeight(.semibold)

                HStack(spacing: 8) {
                    metadataBadge(formattedDate(session.startedAt))

                    if let endedAt = session.endedAt {
                        metadataBadge(formattedDuration(from: session.startedAt, to: endedAt))
                    }

                    metadataBadge(meetingType(for: session))
                }
            }
        } else {
            Text("Meeting not found")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private func metadataBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Summary Placeholder Card

    private var summaryPlaceholderCard: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
            .frame(maxWidth: .infinity)
            .frame(height: 96)
            .overlay {
                Text("Summary will appear here")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
            }
    }

    // MARK: - Slack Actions Row

    private var slackActionsRow: some View {
        Button("Copy for Slack", systemImage: "doc.on.clipboard") {}
            .buttonStyle(.bordered)
            .disabled(true)
            .help("Summary required")
    }

    // MARK: - Transcript Divider

    private var transcriptDivider: some View {
        Divider()
            .padding(.vertical, 20)
    }

    // MARK: - Transcript Section

    @ViewBuilder
    private var transcriptSection: some View {
        if isLoading {
            ProgressView("Loading transcript…")
        } else if rows.isEmpty {
            Text("No transcript recorded.")
                .foregroundStyle(.secondary)
                .font(.system(size: 13))
        } else {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, pair in
                TranscriptRow(record: pair.0, showTimestamp: pair.1)
            }
        }
    }

    // MARK: - Private Helpers

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formattedDuration(from start: Date, to end: Date) -> String {
        let interval = end.timeIntervalSince(start)
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .dropLeading
        return formatter.string(from: interval) ?? "Unknown"
    }

    private func meetingType(for session: SessionIndex) -> String {
        if let app = session.meetingApp, !app.isEmpty { return app }
        if let template = session.templateSnapshot { return template.name }
        return "Recording"
    }
}

// MARK: - TranscriptRow

private struct TranscriptRow: View {
    let record: SessionRecord
    let showTimestamp: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showTimestamp {
                Text(record.timestamp, style: .time)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 8)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                let (label, color) = speakerLabelAndColor(for: record.speaker)
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 36, alignment: .trailing)

                Text(record.refinedText ?? record.text)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
            }
        }
    }

    private func speakerLabelAndColor(for speaker: Speaker) -> (String, Color) {
        switch speaker {
        case .you:
            return ("You", Color.youColor)
        case .them:
            return ("Them", Color.themColor)
        case .room:
            return ("Room", Color.secondary)
        }
    }
}
