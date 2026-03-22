import Sparkle
import SwiftUI

struct DetailRouter: View {
    @Binding var selectedSessionID: String?
    @Bindable var settings: AppSettings
    let updater: SPUUpdater
    @Environment(AppCoordinator.self) private var coordinator

    private enum Content { case live, past(String), settings, empty }

    private var resolvedContent: Content {
        if selectedSessionID == "_settings_" { return .settings }
        if selectedSessionID == "_live_" { return .live }
        if let id = selectedSessionID { return .past(id) }
        return .empty
    }

    var body: some View {
        switch resolvedContent {
        case .live:
            LiveDetailView(settings: settings)
        case .past(let id):
            PastMeetingDetailView(sessionID: id, settings: settings)
        case .settings:
            ScrollView {
                SettingsView(settings: settings, updater: updater)
                    .padding()
            }
        case .empty:
            if coordinator.sessionHistory.isEmpty {
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
    }
}
