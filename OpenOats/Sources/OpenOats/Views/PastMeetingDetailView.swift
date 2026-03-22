import AppKit
import SwiftUI

// MARK: - PastMeetingDetailView

struct PastMeetingDetailView: View {
    let sessionID: String
    @Bindable var settings: AppSettings
    @Environment(AppCoordinator.self) private var coordinator
    @State private var rows: [(SessionRecord, Bool)] = []
    @State private var isLoading = true
    @State private var summaryState: SummaryState? = nil

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                metadataHeader
                summarySection
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
            summaryState = nil

            // Load transcript (existing)
            let loaded = await coordinator.sessionStore.loadTranscript(sessionID: sessionID)
            rows = transcriptRows(for: loaded)
            isLoading = false

            // Check coordinator live cache first (covers the just-generated case)
            if let cached = coordinator.summaryCache[sessionID] {
                summaryState = cached
                return
            }

            // Fall back to disk (past sessions where summary was generated earlier)
            // Disk format is Markdown: {sessionID}-summary.md
            let summaryURL = URL(fileURLWithPath: settings.notesFolderPath)
                .appendingPathComponent("\(sessionID)-summary.md")
            if let markdownText = try? String(contentsOf: summaryURL, encoding: .utf8) {
                let persisted = parseSummaryMarkdown(markdownText, sessionID: sessionID)
                summaryState = .ready(persisted)
            }
            // If no cache and no disk file: summaryState stays nil (show placeholder)
        }
        .onChange(of: coordinator.summaryCache[sessionID] != nil) { _, hasCached in
            if hasCached, let state = coordinator.summaryCache[sessionID] {
                summaryState = state
            }
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

    // MARK: - Summary Section

    @ViewBuilder
    private var summarySection: some View {
        switch summaryState {
        case nil:
            // No summary exists yet and not in-flight — show subtle placeholder
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                .frame(maxWidth: .infinity, minHeight: 64)
                .overlay {
                    Text("No summary")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }

        case .loading:
            // Spinner — "Generating summary..." spinner in card area
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                .frame(maxWidth: .infinity, minHeight: 80)
                .overlay {
                    HStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Generating summary\u{2026}")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }

        case .failed(let message):
            // Error card with Retry button
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                .frame(maxWidth: .infinity, minHeight: 80)
                .overlay {
                    VStack(spacing: 8) {
                        Text(message)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            retrySummary()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(12)
                }

        case .ready(let persisted):
            // Full summary — four sections displayed as titled bullet lists
            VStack(alignment: .leading, spacing: 16) {
                summaryBullets(title: "Key Decisions", items: persisted.decisions)
                summaryBullets(title: "Action Items", items: persisted.actionItems)
                summaryBullets(title: "Discussion Points", items: persisted.discussionPoints)
                summaryBullets(title: "Open Questions", items: persisted.openQuestions)
            }
        }
    }

    private func summaryBullets(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            if items.isEmpty {
                Text("None recorded")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\u{2022}")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        Text(item)
                            .font(.system(size: 13))
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }

    private func retrySummary() {
        coordinator.summaryCache[sessionID] = nil
        summaryState = .loading
        Task {
            let records = await coordinator.sessionStore.loadTranscript(sessionID: sessionID)
            // Convert [SessionRecord] to [Utterance] for the summary engine
            let utterances = records.map { r in
                Utterance(
                    text: r.text,
                    speaker: r.speaker,
                    timestamp: r.timestamp,
                    refinedText: r.refinedText
                )
            }
            await coordinator.requestSummaryRetry(
                sessionID: sessionID,
                records: utterances,
                settings: settings
            )
        }
    }

    // MARK: - Slack Actions Row

    private var slackActionsRow: some View {
        Button("Copy for Slack", systemImage: "doc.on.clipboard") {
            copyForSlack()
        }
        .buttonStyle(.bordered)
        .disabled(!canCopySlack)
        .help(canCopySlack ? "Copy Slack-formatted summary" : "Summary required")
    }

    private var canCopySlack: Bool {
        if case .ready = summaryState { return true }
        return false
    }

    private func copyForSlack() {
        guard case .ready(let persisted) = summaryState,
              let session = coordinator.sessionHistory.first(where: { $0.id == sessionID }) else { return }
        let slackSummary = SlackFormatter.Summary(
            meetingTitle: session.title ?? persisted.meetingTitle,
            date: session.startedAt,
            decisions: persisted.decisions,
            actionItems: persisted.actionItems,
            discussionPoints: persisted.discussionPoints,
            openQuestions: persisted.openQuestions
        )
        let text = SlackFormatter.format(slackSummary)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
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
            ProgressView("Loading transcript\u{2026}")
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

    private func parseSummaryMarkdown(_ text: String, sessionID: String) -> SummaryEngine.PersistedSummary {
        // The Markdown format is:
        // # Meeting Title
        // (blank)
        // ## Key Decisions
        // - item
        // (blank)
        // ## Action Items
        // - item
        // ...etc
        var decisions: [String] = []
        var actionItems: [String] = []
        var discussionPoints: [String] = []
        var openQuestions: [String] = []
        var meetingTitle = "Meeting"

        enum Section { case none, decisions, actionItems, discussionPoints, openQuestions }
        var currentSection = Section.none

        let lines = text.components(separatedBy: "\n")
        for line in lines {
            if line.hasPrefix("# ") {
                meetingTitle = String(line.dropFirst(2))
            } else if line == "## Key Decisions" {
                currentSection = .decisions
            } else if line == "## Action Items" {
                currentSection = .actionItems
            } else if line == "## Discussion Points" {
                currentSection = .discussionPoints
            } else if line == "## Open Questions" {
                currentSection = .openQuestions
            } else if line.hasPrefix("- ") {
                let item = String(line.dropFirst(2))
                // Skip the "None recorded" placeholder
                guard item != "None recorded" else { continue }
                switch currentSection {
                case .decisions:        decisions.append(item)
                case .actionItems:      actionItems.append(item)
                case .discussionPoints: discussionPoints.append(item)
                case .openQuestions:    openQuestions.append(item)
                case .none:             break
                }
            }
        }

        let session = coordinator.sessionHistory.first { $0.id == sessionID }
        return SummaryEngine.PersistedSummary(
            sessionID: sessionID,
            meetingTitle: meetingTitle,
            startedAt: session?.startedAt ?? Date(),
            decisions: decisions,
            actionItems: actionItems,
            discussionPoints: discussionPoints,
            openQuestions: openQuestions,
            generatedAt: Date()
        )
    }

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
