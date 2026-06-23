import SwiftUI

struct CrewMemberRow: View {
    let status: CrewMemberStatus

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(signalColor)
                .frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 2) {
                Text(status.member.displayName)
                    .font(.headline)
                Text(status.member.trailPosition.rawValue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(status.linkState.label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(signalColor)
            if status.isSpeaking {
                Image(systemName: "waveform")
                    .foregroundStyle(.orange)
            }
        }
        .frame(minHeight: 56)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(status.member.displayName), \(status.linkState.label)")
    }

    private var signalColor: Color {
        switch status.linkState {
        case .inRange: .green
        case .weakSignal: .yellow
        case .relayOnly: .orange
        case .offline: .gray
        }
    }
}
