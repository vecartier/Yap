import SwiftUI
import CoreAudio

struct ContentView: View {
    private enum ControlBarAction {
        case toggle
        case confirmDownload
    }

    private struct ViewState {
        var isRunning = false
        var lastEndedSession: SessionIndex?
        var lastSessionHasNotes = false
        var modelDisplayName = ""
        var transcriptionPrompt = ""
        var statusMessage: String?
        var errorMessage: String?
        var needsDownload = false
        var showLiveTranscript = true
        var utterances: [Utterance] = []
        var volatileYouText = ""
        var volatileThemText = ""
        var notesFolderPath = ""
        var transcriptionModel: TranscriptionModel = .parakeetV2
        var inputDeviceID: AudioDeviceID = 0
    }

    @Bindable var settings: AppSettings
    @Environment(AppRuntime.self) private var runtime
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.openWindow) private var openWindow
    @State private var overlayManager = OverlayManager()
    @AppStorage("isTranscriptExpanded") private var isTranscriptExpanded = true
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false
    @State private var showConsentSheet = false
    @State private var audioLevel: Float = 0
    @State private var viewState = ViewState()
    @State private var pendingControlBarAction: ControlBarAction?
    @State private var observedUtteranceCount = 0
    @State private var observedIsRunning = false
    @State private var observedPendingExternalCommandID: UUID?
    @State private var observedNotesFolderPath = ""
    @State private var observedTranscriptionModel: TranscriptionModel = .parakeetV2
    @State private var observedInputDeviceID: AudioDeviceID = 0

    var body: some View {
        bodyWithModifiers
    }

    private var rootContent: some View {
        let viewState = viewState

        return VStack(spacing: 0) {
            // Compact header
            HStack {
                Text("OpenOats")
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                Button {
                    openWindow(id: "notes")
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "note.text")
                            .font(.system(size: 11))
                        Text("Past Meetings")
                            .font(.system(size: 11))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                // Avoid hover-driven local state here. On macOS 26 / Swift 6.2,
                // the onHover closure triggers a view body re-evaluation outside
                // the MainActor executor context, which crashes in
                // swift_getObjectType when checking @Observable actor isolation.
                // Same class of bug fixed in ControlBar (b9625e7).
                .help("View past meeting notes")
                .accessibilityIdentifier("app.pastMeetingsButton")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // Post-session banner
            if let lastSession = viewState.lastEndedSession, lastSession.utteranceCount > 0 {
                HStack {
                    Text("Session ended \u{00B7} \(lastSession.utteranceCount) utterances")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("app.sessionEndedBanner")
                    Spacer()
                    if viewState.lastSessionHasNotes {
                        Button {
                            openWindow(id: "notes")
                        } label: {
                            Label("View Notes", systemImage: "doc.text")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .accessibilityIdentifier("app.viewNotesButton")
                    } else {
                        Button {
                            openWindow(id: "notes")
                        } label: {
                            Label("Generate Notes", systemImage: "sparkles")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .accessibilityIdentifier("app.generateNotesButton")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)

                Divider()
            }

            // Collapsible transcript (hidden when live transcript is disabled)
            if viewState.showLiveTranscript {
                DisclosureGroup(isExpanded: $isTranscriptExpanded) {
                    TranscriptView(
                        utterances: viewState.utterances,
                        volatileYouText: viewState.volatileYouText,
                        volatileThemText: viewState.volatileThemText
                    )
                    .frame(height: 150)
                } label: {
                    HStack(spacing: 6) {
                        Text("Transcript")
                            .font(.system(size: 12, weight: .medium))
                        if !viewState.utterances.isEmpty {
                            Text("(\(viewState.utterances.count))")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        if isTranscriptExpanded && !viewState.utterances.isEmpty {
                            Button {
                                copyTranscript()
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .padding(4)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            .buttonStyle(.plain)
                            // Same hover executor crash as the Past Meetings button
                            // and ControlBar toggle (b9625e7). Remove onHover to
                            // avoid EXC_BAD_ACCESS in swift_getObjectType.
                            .help("Copy transcript")
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            Divider()

            // Bottom bar: live indicator + model
            ControlBar(
                isRunning: viewState.isRunning,
                audioLevel: audioLevel,
                modelDisplayName: viewState.modelDisplayName,
                transcriptionPrompt: viewState.transcriptionPrompt,
                statusMessage: viewState.statusMessage,
                errorMessage: viewState.errorMessage,
                needsDownload: viewState.needsDownload,
                onToggle: {
                    pendingControlBarAction = .toggle
                },
                onConfirmDownload: {
                    pendingControlBarAction = .confirmDownload
                }
            )
        }
    }

    private var bodyWithModifiers: some View {
        contentWithEventHandlers
    }

    private var sizedRootContent: some View {
        rootContent
            .frame(minWidth: 360, maxWidth: 600, minHeight: 400)
            .background(.ultraThinMaterial)
    }

    private var contentWithOverlay: some View {
        sizedRootContent.overlay {
            if showOnboarding {
                OnboardingView(isPresented: $showOnboarding)
                    .transition(.opacity)
            }
            if showConsentSheet {
                RecordingConsentView(
                    isPresented: $showConsentSheet,
                    settings: settings
                )
                .transition(.opacity)
            }
        }
    }

    private var contentWithLifecycle: some View {
        contentWithOverlay
        .onChange(of: showOnboarding) { _, isShowing in
            if !isShowing {
                hasCompletedOnboarding = true
            }
        }
        .onChange(of: showConsentSheet) { _, isShowing in
            if !isShowing && settings.hasAcknowledgedRecordingConsent && !viewState.isRunning {
                startSession()
            }
        }
        .task {
            if !hasCompletedOnboarding {
                showOnboarding = true
            }
            runtime.ensureServicesInitialized(settings: settings, coordinator: coordinator)
            overlayManager.defaults = runtime.defaults
            await runtime.seedIfNeeded(coordinator: coordinator)
            refreshViewState()
            handlePendingExternalCommandIfPossible()

            // Purge recently deleted sessions older than 24h
            await coordinator.sessionStore.purgeRecentlyDeleted()

            // Setup meeting detection if enabled
            if settings.meetingAutoDetectEnabled {
                coordinator.setupMeetingDetection(settings: settings)
                await coordinator.evaluateImmediate()
            }
        }
        .onChange(of: settings.meetingAutoDetectEnabled) {
            if settings.meetingAutoDetectEnabled {
                coordinator.setupMeetingDetection(settings: settings)
                Task {
                    await coordinator.evaluateImmediate()
                }
            } else {
                coordinator.teardownMeetingDetection()
            }
        }
    }

    private var contentWithEventHandlers: some View {
        contentWithLifecycle
        .onKeyPress(.escape) {
            overlayManager.hide()
            return .handled
        }
        .task {
            refreshViewState()
            synchronizeDerivedState()

            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                refreshViewState()
                synchronizeDerivedState()
            }
        }
    }

    // MARK: - Actions

    private func startSession() {
        // Gate recording behind consent acknowledgment
        guard settings.hasAcknowledgedRecordingConsent else {
            withAnimation(.easeInOut(duration: 0.25)) {
                showConsentSheet = true
            }
            return
        }

        coordinator.handle(.userStarted(.manual()), settings: settings)
    }

    private func stopSession() {
        coordinator.handle(.userStopped, settings: settings)
    }

    private func toggleOverlay() {
        let content = OverlayContent(
            volatileThemText: viewState.volatileThemText
        )
        overlayManager.toggle(content: content)
    }

    private func copyTranscript() {
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm:ss"
        let lines = viewState.utterances.map { u in
            "[\(timeFmt.string(from: u.timestamp))] \(u.speaker == .you ? "You" : "Them"): \(u.displayText)"
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
    }

    private func handlePendingExternalCommandIfPossible() {
        guard let request = coordinator.pendingExternalCommand else { return }
        let handled: Bool

        switch request.command {
        case .startSession:
            guard coordinator.transcriptionEngine != nil, coordinator.transcriptLogger != nil else {
                return
            }
            if !viewState.isRunning {
                startSession()
            }
            handled = true
        case .stopSession:
            guard viewState.isRunning else { return }
            stopSession()
            handled = true
        case .openNotes(let sessionID):
            coordinator.queueSessionSelection(sessionID)
            openWindow(id: "notes")
            handled = true
        }

        if handled {
            coordinator.completeExternalCommand(request.id)
        }
    }

    private func handleNewUtterance(_ last: Utterance) {
        // Reset silence timer for auto-detected sessions
        coordinator.noteUtterance()

        // Persist to transcript log
        Task {
            await coordinator.transcriptLogger?.append(
                speaker: last.speaker == .you ? "You" : "Them",
                text: last.text,
                timestamp: last.timestamp
            )
        }

        // Trigger transcript refinement if enabled
        if settings.enableTranscriptRefinement, let engine = coordinator.refinementEngine {
            Task {
                await engine.refine(last)
            }
        }

        // Trigger delayed write for THEM utterance (captures refined text after delay)
        if last.speaker == .them {
            let baseRecord = SessionRecord(
                speaker: last.speaker,
                text: last.text,
                timestamp: last.timestamp
            )
            Task {
                await coordinator.sessionStore.appendRecordDelayed(
                    baseRecord: baseRecord,
                    utteranceID: last.id,
                    transcriptStore: coordinator.transcriptStore
                )
            }
        } else {
            // Log non-them utterances immediately
            Task {
                await coordinator.sessionStore.appendRecord(SessionRecord(
                    speaker: last.speaker,
                    text: last.text,
                    timestamp: last.timestamp
                ))
            }
        }
    }

    private func handleNewUtterances(startingAt startIndex: Int) {
        let utterances = coordinator.transcriptStore.utterances
        guard startIndex < utterances.count else { return }

        for utterance in utterances[startIndex...] {
            handleNewUtterance(utterance)
        }
    }

    @MainActor
    private func refreshViewState() {
        let lastEndedSession = coordinator.lastEndedSession
        let lastSessionHasNotes = lastEndedSession.flatMap { lastSession in
            coordinator.sessionHistory.first { $0.id == lastSession.id }?.hasNotes
        } ?? false

        let activeModelRaw = switch settings.llmProvider {
        case .openRouter: settings.selectedModel
        case .ollama: settings.ollamaLLMModel
        case .mlx: settings.mlxModel
        case .openAICompatible: settings.openAILLMModel
        }

        var nextViewState = ViewState()
        nextViewState.isRunning = coordinator.transcriptionEngine?.isRunning ?? false
        nextViewState.lastEndedSession = lastEndedSession
        nextViewState.lastSessionHasNotes = lastSessionHasNotes
        nextViewState.modelDisplayName = activeModelRaw.split(separator: "/").last.map(String.init) ?? activeModelRaw
        nextViewState.transcriptionPrompt = settings.transcriptionModel.downloadPrompt
        nextViewState.statusMessage = coordinator.transcriptionEngine?.assetStatus
        nextViewState.errorMessage = coordinator.transcriptionEngine?.lastError
        nextViewState.needsDownload = coordinator.transcriptionEngine?.needsModelDownload ?? false
        nextViewState.showLiveTranscript = settings.showLiveTranscript
        nextViewState.utterances = coordinator.transcriptStore.utterances
        nextViewState.volatileYouText = coordinator.transcriptStore.volatileYouText
        nextViewState.volatileThemText = coordinator.transcriptStore.volatileThemText
        nextViewState.notesFolderPath = settings.notesFolderPath
        nextViewState.transcriptionModel = settings.transcriptionModel
        nextViewState.inputDeviceID = settings.inputDeviceID

        viewState = nextViewState
    }

    @MainActor
    private func synchronizeDerivedState() {
        let currentViewState = viewState

        if currentViewState.notesFolderPath != observedNotesFolderPath {
            observedNotesFolderPath = currentViewState.notesFolderPath
            let url = URL(fileURLWithPath: currentViewState.notesFolderPath)
            Task {
                await coordinator.transcriptLogger?.updateDirectory(url)
            }
            coordinator.audioRecorder?.updateDirectory(url)
        }

        if currentViewState.transcriptionModel != observedTranscriptionModel {
            observedTranscriptionModel = currentViewState.transcriptionModel
            coordinator.transcriptionEngine?.refreshModelAvailability()
        }

        if currentViewState.inputDeviceID != observedInputDeviceID {
            observedInputDeviceID = currentViewState.inputDeviceID
            if currentViewState.isRunning {
                Task {
                    coordinator.transcriptionEngine?.restartMic(inputDeviceID: currentViewState.inputDeviceID)
                }
            }
        }

        let utteranceCount = currentViewState.utterances.count
        if utteranceCount > observedUtteranceCount {
            handleNewUtterances(startingAt: observedUtteranceCount)
        }
        observedUtteranceCount = utteranceCount

        if currentViewState.isRunning != observedIsRunning {
            observedIsRunning = currentViewState.isRunning
        }

        let pendingExternalCommandID = coordinator.pendingExternalCommand?.id
        if pendingExternalCommandID != observedPendingExternalCommandID {
            observedPendingExternalCommandID = pendingExternalCommandID
            handlePendingExternalCommandIfPossible()
        }

        if let action = pendingControlBarAction {
            pendingControlBarAction = nil
            handleControlBarAction(action)
        }

        if currentViewState.isRunning {
            audioLevel = coordinator.transcriptionEngine?.audioLevel ?? 0
        } else if audioLevel != 0 {
            audioLevel = 0
        }
    }

    @MainActor
    private func handleControlBarAction(_ action: ControlBarAction) {
        switch action {
        case .toggle:
            if viewState.isRunning {
                stopSession()
            } else {
                startSession()
            }
        case .confirmDownload:
            coordinator.transcriptionEngine?.downloadConfirmed = true
            startSession()
        }
    }
}
