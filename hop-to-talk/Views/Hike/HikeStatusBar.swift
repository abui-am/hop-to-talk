import SwiftUI

struct HikeStatusBar: View {
    let partyName: String
    let elapsedTime: String
    let nearbyLabel: String
    let hikingModeEnabled: Bool
    var operatingModeName: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Label(partyName, systemImage: "mountain.2.fill")
                        .font(.headline)
                    if !operatingModeName.isEmpty {
                        Text(operatingModeName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Label(elapsedTime, systemImage: "clock")
                    .font(.subheadline.weight(.semibold))
            }

            HStack {
                if hikingModeEnabled {
                    Label("Hiking Mode ON", systemImage: "figure.hiking")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.green.opacity(0.85), in: Capsule())
                }
                Spacer()
                Label(nearbyLabel, systemImage: "person.3")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
}
