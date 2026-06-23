import SwiftUI
import UIKit

struct HikingPTTButton: View {
    let state: PTTButtonState
    let onPress: () -> Void
    let onRelease: () -> Void

    @State private var isFingerDown = false

    private var fillColor: Color {
        switch state {
        case .ready:
            isFingerDown ? .green : .accentColor
        case .transmitting:
            .green
        case .disabled:
            .gray
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                if state == .transmitting || isFingerDown {
                    Circle()
                        .stroke(Color.green.opacity(0.4), lineWidth: 4)
                        .frame(width: 156, height: 156)
                        .scaleEffect(state == .transmitting ? 1.05 : 1.0)
                        .animation(
                            state == .transmitting ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default,
                            value: state == .transmitting
                        )
                }

                Circle()
                    .fill(fillColor)
                    .frame(width: 140, height: 140)
                    .shadow(color: .black.opacity(0.25), radius: 10, y: 4)

                VStack(spacing: 4) {
                    Text(state.primaryLabel.uppercased())
                        .font(.caption.weight(.bold))
                    Text(state.secondaryLabel)
                        .font(.title3.weight(.heavy))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
            }
            .frame(minWidth: 120, minHeight: 120)
            .contentShape(Circle())
            .gesture(pressGesture)

            Text(hintText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    private var hintText: String {
        switch state {
        case .ready:
            "Tahan tombol, bicara ke seluruh tim"
        case .transmitting:
            "Lepas tombol saat selesai bicara"
        case .disabled(let reason):
            reason
        }
    }

    private var accessibilityLabel: String {
        switch state {
        case .ready:
            "Tahan untuk bicara ke seluruh tim"
        case .transmitting:
            "Sedang bicara, lepas untuk berhenti"
        case .disabled(let reason):
            "Tidak bisa bicara: \(reason)"
        }
    }

    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard state.isInteractive, !isFingerDown else { return }
                isFingerDown = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onPress()
            }
            .onEnded { _ in
                guard isFingerDown else { return }
                isFingerDown = false
                if state.isInteractive {
                    onRelease()
                }
            }
    }
}
