import SwiftUI

struct LiveDetailView: View {
    @Bindable var settings: AppSettings
    @Environment(AppCoordinator.self) private var coordinator

    @State private var elapsedSeconds: Int = 0
    @State private var timerTask: Task<Void, Never>?
    @State private var pulseOpacity: Double = 1.0
    @State private var observedUtteranceCount = 0

    var body: some View {
        VStack(spacing: 0) {
            recordingHeader
            Divider()
            transcriptBody
        }
        .onAppear {
            startPulse()
            if coordinator.isRecording {
                startTimer()
            }
            observedUtteranceCount = coordinator.transcriptStore.utterances.count
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
        .onChange(of: coordinator.transcriptStore.utterances.count) { old, new in
            guard new > old else { return }
            handleNewUtterances(startingAt: old)
            observedUtteranceCount = new
        }
    }

    // MARK: - Computed State

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

    // MARK: - Subviews

    private var recordingHeader: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
                .opacity(pulseOpacity)

            Text(formattedTime)
                .font(.system(size: 13, weight: .medium).monospacedDigit())
                .foregroundStyle(.primary)

            Spacer()

            if isFinalizing {
                ProgressView()
                    .controlSize(.small)
                Text("Finalizing\u{2026}")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else {
                Button("Stop") {
                    coordinator.handle(.userStopped, settings: settings)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var transcriptBody: some View {
        TranscriptView(
            utterances: coordinator.transcriptStore.utterances,
            volatileYouText: coordinator.transcriptStore.volatileYouText,
            volatileThemText: coordinator.transcriptStore.volatileThemText
        )
    }

    // MARK: - Timer

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
        elapsedSeconds = 0
    }

    // MARK: - Pulse Animation

    private func startPulse() {
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            pulseOpacity = 0.3
        }
    }

    // MARK: - Utterance Persistence (ported verbatim from ContentView)

    private func speakerLabel(for speaker: Speaker) -> String {
        switch speaker {
        case .you:  return "You"
        case .them: return "Them"
        case .room: return "Room"
        }
    }

    private func handleNewUtterance(_ last: Utterance) {
        // Reset silence timer for auto-detected sessions
        coordinator.noteUtterance()

        // Persist to transcript log
        Task {
            await coordinator.transcriptLogger?.append(
                speaker: speakerLabel(for: last.speaker),
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
}
