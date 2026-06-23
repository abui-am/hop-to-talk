import SwiftUI

struct TrailheadSetupFlow: View {
    @Bindable var viewModel: HikingSessionViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TrailheadProgressView(currentStep: viewModel.trailheadStep)

                stepContent
                    .frame(maxHeight: .infinity)

                trailheadFooter
            }
            .navigationTitle(trailheadTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if viewModel.trailheadStep != .partyName {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Kembali", action: viewModel.retreatTrailhead)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.trailheadStep {
        case .partyName:
            partyNameStep
        case .pairCrew:
            PairCrewView(viewModel: viewModel)
        case .formation:
            TrailFormationView(viewModel: viewModel)
        case .config:
            HikeConfigView(viewModel: viewModel)
        }
    }

    private var partyNameStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                stepHeader(
                    title: "Siapa tim kamu?",
                    subtitle: "Nama tim dan nama kamu akan tampil di barisan jalur."
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("Nama tim")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("Tim Merbabu", text: $viewModel.party.name)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Nama kamu")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("Budi", text: $viewModel.localDisplayName)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)
                }
            }
            .padding()
        }
    }

    private func stepHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title.bold())
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var trailheadFooter: some View {
        VStack(spacing: 10) {
            if viewModel.trailheadStep == .pairCrew, !viewModel.canAdvanceFromPairing {
                Label("Hubungkan minimal 1 rekan untuk lanjut", systemImage: "person.badge.plus")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            } else if !viewModel.statusMessage.isEmpty,
                      viewModel.trailheadStep == .pairCrew,
                      viewModel.statusMessage != "Siap di basecamp" {
                Text(viewModel.statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .padding(.horizontal)
            }

            Button(primaryButtonTitle, action: viewModel.advanceTrailhead)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity, minHeight: 56)
                .disabled(isPrimaryDisabled)
                .padding(.horizontal)
                .padding(.bottom, 16)
        }
    }

    private var isPrimaryDisabled: Bool {
        viewModel.trailheadStep == .pairCrew && !viewModel.canAdvanceFromPairing
    }

    private var trailheadTitle: String {
        switch viewModel.trailheadStep {
        case .partyName: "Basecamp"
        case .pairCrew: "Hubungkan rekan"
        case .formation: "Barisan"
        case .config: "Konfigurasi"
        }
    }

    private var primaryButtonTitle: String {
        viewModel.trailheadStep == .config ? "Mulai pendakian" : "Lanjut"
    }
}
