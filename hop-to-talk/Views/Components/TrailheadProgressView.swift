import SwiftUI

struct TrailheadProgressView: View {
    let currentStep: HikingSessionViewModel.TrailheadStep

    private let steps: [HikingSessionViewModel.TrailheadStep] = [
        .partyName, .pairCrew, .formation, .config
    ]

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    stepNode(step: step, index: index)
                    if index < steps.count - 1 {
                        connector(filled: step.rawValue < currentStep.rawValue)
                    }
                }
            }
            Text("Langkah \(currentStep.rawValue + 1) dari \(steps.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Langkah \(currentStep.rawValue + 1) dari \(steps.count), \(stepTitle(currentStep))")
    }

    private func stepNode(step: HikingSessionViewModel.TrailheadStep, index: Int) -> some View {
        let isComplete = step.rawValue < currentStep.rawValue
        let isCurrent = step == currentStep

        return VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isComplete ? Color.green : (isCurrent ? Color.accentColor : Color.gray.opacity(0.35)))
                    .frame(width: 28, height: 28)
                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                } else {
                    Text("\(index + 1)")
                        .font(.caption.bold())
                        .foregroundStyle(isCurrent ? .white : .secondary)
                }
            }
            Text(shortTitle(step))
                .font(.caption2)
                .foregroundStyle(isCurrent ? .primary : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private func connector(filled: Bool) -> some View {
        Rectangle()
            .fill(filled ? Color.green : Color.gray.opacity(0.35))
            .frame(height: 2)
            .frame(maxWidth: 24)
            .padding(.bottom, 18)
    }

    private func shortTitle(_ step: HikingSessionViewModel.TrailheadStep) -> String {
        switch step {
        case .partyName: "Tim"
        case .pairCrew: "Pair"
        case .formation: "Barisan"
        case .config: "Setup"
        }
    }

    private func stepTitle(_ step: HikingSessionViewModel.TrailheadStep) -> String {
        switch step {
        case .partyName: "Nama tim"
        case .pairCrew: "Hubungkan rekan"
        case .formation: "Atur barisan"
        case .config: "Konfigurasi"
        }
    }
}
