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

// Top-level enum for testability — exposed via @testable import YapKit
enum MeetingListItem: Identifiable, Hashable {
    case live
    case session(SessionIndex)

    var id: String {
        switch self {
        case .live: return "_live_"
        case .session(let s): return s.id
        }
    }
}

struct MeetingSidebarView: View {
    @Binding var selectedSessionID: String?
    let notesFolderPath: String
    @Environment(AppCoordinator.self) private var coordinator

    @State private var searchQuery = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var filteredSessions: [SessionIndex] = []
    private let searchService = SearchService()

    private var isFinalizing: Bool {
        if case .ending = coordinator.state { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selectedSessionID) {
                if coordinator.isRecording || isFinalizing {
                    LiveSessionRowView(coordinator: coordinator)
                        .tag("_live_")
                }
                if !searchQuery.isEmpty && filteredSessions.isEmpty {
                    ContentUnavailableView.search(text: searchQuery)
                } else {
                    ForEach(groupedSessions(filteredSessions), id: \.label) { group in
                        Section(group.label) {
                            ForEach(group.sessions) { session in
                                MeetingRowView(session: session)
                                    .tag(session.id)
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .searchable(text: $searchQuery, placement: .sidebar, prompt: "Search meetings")
            .onChange(of: searchQuery) { _, query in
                searchTask?.cancel()
                guard !query.isEmpty else {
                    filteredSessions = coordinator.sessionHistory
                    return
                }
                searchTask = Task {
                    try? await Task.sleep(for: .milliseconds(250))
                    guard !Task.isCancelled else { return }
                    let results = await searchService.search(
                        query: query,
                        sessions: coordinator.sessionHistory,
                        store: coordinator.sessionStore,
                        notesFolderPath: notesFolderPath
                    )
                    await MainActor.run { filteredSessions = results }
                }
            }
            .onChange(of: coordinator.sessionHistory) { _, sessions in
                if searchQuery.isEmpty { filteredSessions = sessions }
            }
            .onAppear { filteredSessions = coordinator.sessionHistory }
            .task {
                await coordinator.loadHistory()
            }

            Divider()

            Button {
                selectedSessionID = "_settings_"
            } label: {
                Label("Settings", systemImage: "gear")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .background(selectedSessionID == "_settings_" ? Color.accentColor.opacity(0.1) : Color.clear)
            .accessibilityIdentifier("sidebar.settingsButton")
        }
    }
}

// MARK: - LiveSessionRowView

private struct LiveSessionRowView: View {
    let coordinator: AppCoordinator

    @State private var elapsedSeconds: Int = 0
    @State private var timerTask: Task<Void, Never>?
    @State private var dotOpacity: Double = 1.0

    private var isFinalizing: Bool {
        if case .ending = coordinator.state { return true }
        return false
    }

    private var recordingStartedAt: Date? {
        if case .recording(let metadata) = coordinator.state { return metadata.startedAt }
        return nil
    }

    private var formattedTime: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        HStack(spacing: 8) {
            if isFinalizing {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 10, height: 10)
            } else {
                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
                    .opacity(dotOpacity)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Live Session")
                    .font(.subheadline)
                    .fontWeight(.medium)

                if isFinalizing {
                    Text("Finalizing\u{2026}")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(formattedTime)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityIdentifier("main.liveSessionRow")
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                dotOpacity = 0.3
            }
            if coordinator.isRecording {
                startTimer()
            }
        }
        .onDisappear {
            stopTimer()
        }
        .onChange(of: coordinator.isRecording) { _, isRecording in
            if isRecording {
                startTimer()
            } else {
                stopTimer()
            }
        }
    }

    private func startTimer() {
        updateElapsed()
        stopTimer()
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                updateElapsed()
            }
        }
    }

    private func updateElapsed() {
        if let start = recordingStartedAt {
            elapsedSeconds = max(0, Int(Date().timeIntervalSince(start)))
        } else {
            elapsedSeconds = 0
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }
}

// MARK: - MeetingRowView

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
            return "\(app) \u{2014} \(timeString)"
        } else if let template = session.templateSnapshot {
            return "\(template.name) \u{2014} \(timeString)"
        }
        return "Meeting \u{2014} \(timeString)"
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
