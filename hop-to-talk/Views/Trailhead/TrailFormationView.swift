import SwiftUI

struct TrailFormationView: View {
    @Bindable var viewModel: HikingSessionViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Atur barisan jalur")
                        .font(.title.bold())
                    Text("Posisi menentukan siapa jadi relay di tengah barisan.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Posisi kamu")
                        .font(.headline)
                    Picker("Posisi kamu", selection: $viewModel.party.localPosition) {
                        ForEach(TrailPosition.allCases) { position in
                            Text(position.rawValue).tag(position)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if viewModel.party.localPosition.isRelayProne {
                    HikeStatusBanner(
                        message: "Kamu di tengah — berperan sebagai relay. Baterai sedikit lebih boros.",
                        tone: .warning
                    )
                }

                GroupBox("Barisan tim") {
                    ForEach(viewModel.party.members) { member in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.displayName)
                                    .font(.headline)
                                Text("Rekan")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Picker("", selection: binding(for: member.id)) {
                                ForEach(TrailPosition.allCases) { position in
                                    Text(position.rawValue).tag(position)
                                }
                            }
                            .labelsHidden()
                        }
                        .frame(minHeight: 52)
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.localDisplayName)
                                .font(.headline)
                            Text("Kamu")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                        Spacer()
                        Text(viewModel.party.localPosition.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(minHeight: 52)
                }
            }
            .padding()
        }
    }

    private func binding(for memberID: UUID) -> Binding<TrailPosition> {
        Binding(
            get: {
                viewModel.party.members.first(where: { $0.id == memberID })?.trailPosition ?? .middle
            },
            set: { newValue in
                guard let index = viewModel.party.members.firstIndex(where: { $0.id == memberID }) else { return }
                viewModel.party.members[index].trailPosition = newValue
            }
        )
    }
}
