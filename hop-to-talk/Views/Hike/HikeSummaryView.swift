import SwiftUI

struct HikeSummaryView: View {
    @Bindable var viewModel: HikingSessionViewModel
    let onNextHike: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "flag.checkered.2.crossed")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            VStack(spacing: 8) {
                Text("Pendakian selesai")
                    .font(.largeTitle.bold())
                Text(viewModel.party.name)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                summaryRow(title: "Durasi", value: viewModel.elapsedHikingTime, icon: "clock")
                Divider().padding(.leading, 44)
                summaryRow(title: "Gelorong", value: "\(viewModel.pttCount)×", icon: "mic.fill")
                Divider().padding(.leading, 44)
                summaryRow(title: "Mode", value: viewModel.operatingMode.displayName, icon: "antenna.radiowaves.left.and.right")
            }
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            Text("Tim dan pairing tersimpan untuk pendakian berikutnya.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            Button("Pendakian berikutnya", action: onNextHike)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(minHeight: 56)
                .padding(.horizontal)
                .padding(.bottom, 24)
        }
    }

    private func summaryRow(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 28)
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.body)
        .padding(.vertical, 10)
    }
}
