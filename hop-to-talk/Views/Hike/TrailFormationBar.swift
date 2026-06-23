import SwiftUI

struct TrailFormationBar: View {
    let localPosition: TrailPosition
    let crewStatuses: [CrewMemberStatus]
    let showRelayBadge: Bool

    var body: some View {
        VStack(spacing: 10) {
            Text("BARISAN JALUR")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                formationNode(position: .lead, label: "Depan")
                connector
                formationNode(position: .middle, label: "Tengah")
                connector
                formationNode(position: localPosition, label: "Kamu", isLocal: true)
                connector
                formationNode(position: .sweep, label: "Belakang")
            }

            if showRelayBadge {
                RelayBadge()
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private var connector: some View {
        Rectangle()
            .fill(.secondary.opacity(0.4))
            .frame(width: 16, height: 2)
    }

    private func formationNode(position: TrailPosition, label: String, isLocal: Bool = false) -> some View {
        let status = crewStatuses.first(where: { $0.member.trailPosition == position })
        let color = signalColor(for: status?.linkState ?? .offline)

        return VStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 14, height: 14)
            Text(isLocal ? "●\(label)" : label)
                .font(.caption2.weight(isLocal ? .bold : .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private func signalColor(for state: CrewLinkState) -> Color {
        switch state {
        case .inRange: .green
        case .weakSignal: .yellow
        case .relayOnly: .orange
        case .offline: .gray
        }
    }
}
