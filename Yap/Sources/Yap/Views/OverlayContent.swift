import SwiftUI

/// Content displayed in the floating overlay panel.
struct OverlayContent: View {
    let volatileThemText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                Text("Yap")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.bottom, 4)

            // Current "them" speech
            if !volatileThemText.isEmpty {
                Text(volatileThemText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .opacity(0.7)
                    .lineLimit(2)
            } else {
                Text("Waiting for conversation...")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.ultraThinMaterial)
    }
}
