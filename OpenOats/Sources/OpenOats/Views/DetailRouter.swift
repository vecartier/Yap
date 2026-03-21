import SwiftUI

// Phase 2 placeholder — Phase 3 will replace the meeting-selected branch with PastMeetingDetailView
struct DetailRouter: View {
    @Binding var selectedSessionID: String?
    @Bindable var settings: AppSettings
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        if let sessionID = selectedSessionID {
            // Phase 3 will replace this with PastMeetingDetailView(sessionID: sessionID, settings: settings)
            VStack(spacing: 16) {
                ContentUnavailableView(
                    "Meeting Selected",
                    systemImage: "doc.text",
                    description: Text("Transcript and summary view coming in Phase 3.")
                )
                if let session = coordinator.sessionHistory.first(where: { $0.id == sessionID }) {
                    meetingMetadata(for: session)
                }
            }
        } else if coordinator.sessionHistory.isEmpty {
            // First launch / no meetings — friendly onboarding
            VStack(spacing: 20) {
                Image(systemName: "waveform.circle")
                    .font(.system(size: 56))
                    .foregroundStyle(.secondary)
                Text("Start your first meeting")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Click the menu bar icon and press Start Recording.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        } else {
            ContentUnavailableView(
                "Select a Meeting",
                systemImage: "waveform",
                description: Text("Choose a meeting from the sidebar.")
            )
        }
    }

    @ViewBuilder
    private func meetingMetadata(for session: SessionIndex) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            Group {
                labeledRow("Date", value: formattedDate(session.startedAt))
                if let endedAt = session.endedAt {
                    labeledRow("Duration", value: formattedDuration(from: session.startedAt, to: endedAt))
                }
                labeledRow("Type", value: meetingType(for: session))
            }
            .padding(.horizontal)
        }
        .padding(.bottom)
    }

    private func labeledRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
        }
        .font(.subheadline)
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
