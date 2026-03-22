import SwiftUI

struct ControlBar: View {
    let isRunning: Bool
    let audioLevel: Float
    let modelDisplayName: String
    let transcriptionPrompt: String
    let statusMessage: String?
    let errorMessage: String?
    let needsDownload: Bool
    let onToggle: () -> Void
    let onConfirmDownload: () -> Void
    let onStartCall: () -> Void
    let onStartSoloMemo: () -> Void
    let onStartSoloRoom: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Error banner
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
            }

            // Download prompt
            if needsDownload && !isRunning {
                VStack(spacing: 6) {
                    Text(transcriptionPrompt)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Download Now") {
                        onConfirmDownload()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            // Status message (model loading, etc.)
            if let status = statusMessage, status != "Ready" {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text(status)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("app.controlBar.status")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }

            HStack(spacing: 10) {
                if isRunning {
                    // Stop button when session is live
                    Button(action: onToggle) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                                .scaleEffect(1.0 + CGFloat(audioLevel) * 0.5)
                                .animation(.easeOut(duration: 0.1), value: audioLevel)

                            Text("Live")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.primary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        // Avoid hover-driven local state here. On macOS 26 / Swift 6.2,
                        // switching this button from Start to Live while the pointer is
                        // over it can trip a SwiftUI executor crash in onHover handling.
                        .background(Color.green.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("app.controlBar.toggle")

                    AudioLevelView(level: audioLevel)
                        .frame(width: 40, height: 14)
                } else {
                    // Three start buttons when idle
                    Button("Start Call") {
                        onStartCall()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .accessibilityIdentifier("app.startCallButton")

                    Button("Solo (memo)") {
                        onStartSoloMemo()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityIdentifier("app.startSoloMemoButton")

                    Button("Solo (room)") {
                        onStartSoloRoom()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityIdentifier("app.startSoloRoomButton")
                }

                Spacer()

                Text(modelDisplayName)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(Capsule())
                    .accessibilityIdentifier("app.controlBar.model")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

}

/// Mini audio level visualizer — a few bars that react to mic input.
struct AudioLevelView: View {
    let level: Float

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { i in
                let threshold = Float(i) / 5.0
                RoundedRectangle(cornerRadius: 1)
                    .fill(level > threshold ? Color.green.opacity(0.7) : Color.primary.opacity(0.08))
                    .frame(width: 3)
            }
        }
        .animation(.easeOut(duration: 0.08), value: level)
    }
}
