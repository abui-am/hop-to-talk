import DeviceDiscoveryUI
import SwiftUI
import WiFiAware

struct PairCrewView: View {
    @Bindable var viewModel: HikingSessionViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hubungkan di basecamp")
                        .font(.title.bold())
                    Text("Semua rekan harus di-pair sebelum masuk jalur. Tanpa sinyal seluler, tidak bisa tambah rekan di tengah hutan.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                pairingChecklist

                if WiFiAwareSupport.isAvailable, let publishService = WAPublishableService.hopTalkService {
                    pairingButtons(publishService: publishService)
                } else {
                    unavailablePairingCard
                }

                crewList
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .onAppear {
            viewModel.syncPartyFromPairing()
        }
        .onChange(of: viewModel.pairingService.pairedDevices.count) { _, _ in
            viewModel.syncPartyFromPairing()
        }
    }

    private var pairingChecklist: some View {
        VStack(alignment: .leading, spacing: 10) {
            checklistRow(
                done: viewModel.pairedCrewCount >= 1,
                text: "Minimal 1 rekan terhubung",
                detail: viewModel.pairedCrewCount >= 1 ? "\(viewModel.pairedCrewCount) rekan siap" : "Belum ada"
            )
            checklistRow(
                done: WiFiAwareSupport.isAvailable,
                text: "WiFi Aware tersedia",
                detail: WiFiAwareSupport.isAvailable ? "Siap" : "Butuh iPhone 12+"
            )
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func checklistRow(done: Bool, text: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? .green : .secondary)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(.subheadline.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(minHeight: 44)
    }

    @ViewBuilder
    private func pairingButtons(publishService: WAPublishableService) -> some View {
        VStack(spacing: 12) {
            Text("Langkah pairing")
                .font(.headline)

            DevicePairingView(
                .wifiAware(.connecting(to: publishService, from: .userSpecifiedDevices))
            ) {
                Label("Undang rekan (tampilkan QR)", systemImage: "qrcode")
                    .frame(maxWidth: .infinity, minHeight: 56)
            } fallback: {
                Label("Pairing tidak tersedia", systemImage: "xmark.circle")
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.borderedProminent)

            if let subscribeService = WASubscribableService.hopTalkService {
                DevicePicker(
                    .wifiAware(.connecting(to: .userSpecifiedDevices, from: subscribeService))
                ) { _ in
                    viewModel.syncPartyFromPairing()
                } label: {
                    Label("Gabung ke rekan lain", systemImage: "person.badge.plus")
                        .frame(maxWidth: .infinity, minHeight: 56)
                } fallback: {
                    Label("Picker tidak tersedia", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var crewList: some View {
        GroupBox("Rekan terhubung") {
            if viewModel.pairingService.pairedDevices.isEmpty {
                ContentUnavailableView {
                    Label("Belum ada rekan", systemImage: "person.2.slash")
                } description: {
                    Text("Tap tombol di atas untuk menghubungkan perangkat rekan.")
                }
                .frame(minHeight: 120)
            } else {
                ForEach(viewModel.pairingService.pairedDevices) { device in
                    HStack(spacing: 12) {
                        Image(systemName: "iphone.gen3")
                            .foregroundStyle(.green)
                        Text(device.name)
                            .font(.headline)
                        Spacer()
                        Text("Terhubung")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                    .frame(minHeight: 52)
                }
            }
        }
    }

    private var unavailablePairingCard: some View {
        ContentUnavailableView {
            Label("WiFi Aware tidak tersedia", systemImage: "wifi.slash")
        } description: {
            Text("Butuh iPhone 12+ dengan iOS 26. Simulator tidak mendukung pairing.")
        }
    }
}
