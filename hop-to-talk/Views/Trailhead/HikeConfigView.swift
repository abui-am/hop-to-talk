import SwiftUI

struct HikeConfigView: View {
    @Bindable var viewModel: HikingSessionViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Berapa lama pendakian?")
                        .font(.title.bold())
                    Text("Pilih durasi — kami rekomendasikan mode terbaik untuk baterai.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 10) {
                    ForEach(HikeDuration.allCases) { duration in
                        RecommendationCard(
                            title: duration.label,
                            subtitle: durationHint(duration),
                            isRecommended: false,
                            isSelected: viewModel.duration == duration
                        ) {
                            viewModel.duration = duration
                            viewModel.applyRecommendations()
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Mode komunikasi")
                        .font(.headline)
                    ForEach(HikingOperatingMode.allCases) { mode in
                        RecommendationCard(
                            title: mode.displayName,
                            subtitle: mode.subtitle,
                            isRecommended: mode == HikingOperatingMode.recommended(for: viewModel.duration.rawValue),
                            isSelected: viewModel.operatingMode == mode
                        ) {
                            viewModel.operatingMode = mode
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Pengaturan baterai")
                        .font(.headline)
                    ForEach(BatteryTier.allCases) { tier in
                        RecommendationCard(
                            title: tier.displayName,
                            subtitle: batteryHint(tier),
                            isRecommended: tier == BatteryTier.recommended(for: viewModel.duration.rawValue),
                            isSelected: viewModel.batteryTier == tier
                        ) {
                            viewModel.batteryTier = tier
                        }
                    }
                }

                if viewModel.duration == .long {
                    HikeStatusBanner(
                        message: "Pendakian panjang — bawa power bank jika bisa.",
                        tone: .warning
                    )
                }

                summaryCard
            }
            .padding()
        }
    }

    private var summaryCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Label("Ringkasan sebelum mulai", systemImage: "checklist")
                    .font(.headline)
                Text("Tim \(viewModel.party.name) · \(viewModel.pairedCrewCount) rekan terhubung")
                Text("\(viewModel.operatingMode.displayName) · \(viewModel.batteryTier.displayName)")
                    .foregroundStyle(.secondary)
                Text("Setelah mulai, tahan tombol PTT untuk bicara ke seluruh barisan.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func durationHint(_ duration: HikeDuration) -> String {
        switch duration {
        case .short: "Cocok untuk day hike — mode live disarankan"
        case .medium: "Pendakian seharian — mode hemat disarankan"
        case .long: "Multi-peakt atau camping — hemat baterai penting"
        }
    }

    private func batteryHint(_ tier: BatteryTier) -> String {
        switch tier {
        case .eco: "Paling hemat — heartbeat lebih jarang"
        case .balanced: "Seimbang untuk kebanyakan jalur"
        case .alwaysOn: "Layar tetap aktif — boros baterai"
        }
    }
}
