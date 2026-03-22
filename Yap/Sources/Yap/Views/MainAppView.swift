import AppKit
import Sparkle
import SwiftUI

struct MainAppView: View {
    @Bindable var settings: AppSettings
    let updater: SPUUpdater
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(AppRuntime.self) private var runtime
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @AppStorage("selectedMeetingID") private var selectedSessionID: String?

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            MeetingSidebarView(selectedSessionID: $selectedSessionID, notesFolderPath: settings.notesFolderPath)
                .frame(minWidth: 220)
        } detail: {
            DetailRouter(selectedSessionID: $selectedSessionID, settings: settings, updater: updater)
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: coordinator.isRecording) { _, isRecording in
            if isRecording {
                selectedSessionID = "_live_"
            }
            // DO NOT clear on false — that would flash to empty during finalization
        }
        .onChange(of: coordinator.lastEndedSession) { _, session in
            guard let session else { return }
            selectedSessionID = session.id
        }
        .onChange(of: coordinator.requestedSessionSelectionID) { _, _ in
            guard let id = coordinator.consumeRequestedSessionSelection() else { return }
            selectedSessionID = id
        }
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
            guard let command = YapDeepLink.parse(url) else { return }
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
            $0.identifier?.rawValue == YapRootApp.mainWindowID
        }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: YapRootApp.mainWindowID)
        }
    }
}
