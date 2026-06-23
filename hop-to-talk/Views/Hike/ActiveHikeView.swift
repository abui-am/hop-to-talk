import SwiftUI

struct ActiveHikeView: View {
    @Bindable var viewModel: HikingSessionViewModel
    @State private var showRestSheet = false
    @State private var showEndConfirmation = false

    var body: some View {
        VStack(spacing: 14) {
            HikeStatusBar(
                partyName: viewModel.party.name,
                elapsedTime: viewModel.elapsedHikingTime,
                nearbyLabel: viewModel.nearbyCrewLabel,
                hikingModeEnabled: viewModel.batteryManager.hikingModeEnabled,
                operatingModeName: viewModel.operatingMode.displayName
            )

            HStack {
                RadioStatusPill(
                    level: viewModel.radioConnectionLevel,
                    modeName: viewModel.operatingMode.displayName
                )
                Spacer()
            }
            .padding(.horizontal)

            TrailFormationBar(
                localPosition: viewModel.party.localPosition,
                crewStatuses: viewModel.crewStatuses,
                showRelayBadge: viewModel.showRelayBadge
            )

            if let banner = viewModel.speakerBannerText {
                HikeStatusBanner(message: banner, tone: .speaking)
            } else {
                HikeStatusBanner(
                    message: viewModel.statusMessage,
                    tone: viewModel.statusBannerTone
                )
            }

            Spacer()

            HikingPTTButton(
                state: viewModel.pttButtonState,
                onPress: { Task { await viewModel.beginPTT() } },
                onRelease: { Task { await viewModel.endPTT() } }
            )

            Spacer()

            HStack(spacing: 16) {
                Button {
                    if viewModel.isResting {
                        Task { await viewModel.resumeFromRest() }
                    } else {
                        showRestSheet = true
                    }
                } label: {
                    Label(viewModel.isResting ? "Lanjut" : "Istirahat", systemImage: "cup.and.saucer")
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    showEndConfirmation = true
                } label: {
                    Label("Selesai", systemImage: "flag.checkered")
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .sheet(isPresented: $showRestSheet) {
            RestBreakSheet(viewModel: viewModel)
        }
        .confirmationDialog(
            "Akhiri pendakian?",
            isPresented: $showEndConfirmation,
            titleVisibility: .visible
        ) {
            Button("Selesai pendakian", role: .destructive) {
                Task { await viewModel.endHike() }
            }
            Button("Batal", role: .cancel) {}
        } message: {
            Text("Radio akan dimatikan dan kamu kembali ke ringkasan.")
        }
        .overlay {
            if viewModel.isResting {
                restOverlay
            }
        }
    }

    private var restOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.green)
                Text("Sedang istirahat")
                    .font(.title2.bold())
                Text("Radio dimatikan untuk hemat baterai.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Lanjutkan pendakian") {
                    Task { await viewModel.resumeFromRest() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(minHeight: 56)
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding(32)
        }
    }
}
