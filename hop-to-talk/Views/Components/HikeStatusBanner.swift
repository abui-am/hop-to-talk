import SwiftUI

struct HikeStatusBanner: View {
    let message: String
    let tone: Tone

    enum Tone {
        case neutral
        case active
        case warning
        case speaking

        var background: Color {
            switch self {
            case .neutral: Color.secondary.opacity(0.15)
            case .active: Color.green.opacity(0.2)
            case .warning: Color.orange.opacity(0.2)
            case .speaking: Color.orange.opacity(0.25)
            }
        }

        var foreground: Color {
            switch self {
            case .neutral: .secondary
            case .active: .green
            case .warning: .orange
            case .speaking: .orange
            }
        }

        var icon: String {
            switch self {
            case .neutral: "info.circle"
            case .active: "checkmark.circle"
            case .warning: "exclamationmark.triangle"
            case .speaking: "waveform"
            }
        }
    }

    var body: some View {
        Label(message, systemImage: tone.icon)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(tone.foreground)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(tone.background, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
    }
}

struct RadioStatusPill: View {
    let level: RadioConnectionLevel
    let modeName: String

    var body: some View {
        HStack(spacing: 8) {
            Label(level.label, systemImage: level.systemImage)
                .font(.caption.weight(.semibold))
            Text("·")
                .foregroundStyle(.secondary)
            Text(modeName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
    }
}
