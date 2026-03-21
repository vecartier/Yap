import SwiftUI

struct DetailRouter: View {
    @Binding var selectedSessionID: String?
    @Bindable var settings: AppSettings
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        if let sessionID = selectedSessionID {
            PastMeetingDetailView(sessionID: sessionID, settings: settings)
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
}
