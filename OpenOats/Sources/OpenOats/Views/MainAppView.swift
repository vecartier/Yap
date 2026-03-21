import SwiftUI
import AppKit

struct MainAppView: View {
    @Bindable var settings: AppSettings
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(AppRuntime.self) private var runtime
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @AppStorage("selectedMeetingID") private var selectedSessionID: String?

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // MeetingSidebarView wired in Plan 02
            Text("Sidebar — coming in Plan 02")
                .frame(minWidth: 220)
        } detail: {
            // DetailRouter wired in Plan 02
            ContentUnavailableView(
                "Select a Meeting",
                systemImage: "waveform",
                description: Text("Choose a meeting from the sidebar.")
            )
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            appDelegate.coordinator = coordinator
            appDelegate.settings = settings
            appDelegate.defaults = .standard
            appDelegate.runtime = runtime
            if case .live = runtime.mode {
                appDelegate.setupMenuBarIfNeeded(
                    coordinator: coordinator,
                    settings: settings,
                    showMainWindow: { showMainWindow() }
                )
            }
            settings.applyScreenShareVisibility()
        }
        .onOpenURL { url in
            guard let command = OpenOatsDeepLink.parse(url) else { return }
            if NSApp.activationPolicy() == .accessory {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
            }
            switch command {
            case .openNotes(let sessionID):
                // Navigate to session in the main window instead of opening a notes window
                selectedSessionID = sessionID
            default:
                coordinator.queueExternalCommand(command)
            }
        }
    }

    private func showMainWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: {
            $0.identifier?.rawValue == OpenOatsRootApp.mainWindowID
        }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: OpenOatsRootApp.mainWindowID)
        }
    }
}
