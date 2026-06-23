import SwiftUI

struct HikingLimitsView: View {
    let step: Int
    let onContinue: () -> Void
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Group {
                switch step {
                case 0:
                    stepContent(
                        icon: "figure.hiking",
                        title: "Cara kerja",
                        body: "Pair di basecamp → atur barisan → tekan dan tahan untuk bicara ke seluruh tim."
                    )
                case 1:
                    stepContent(
                        icon: "exclamationmark.triangle.fill",
                        title: "Yang perlu kamu tahu",
                        body: "Aktifkan Hiking Mode saat pendakian. Bukan pengganti radio SOS. Untuk 3–6 orang, iPhone 12+."
                    )
                default:
                    stepContent(
                        icon: "checkmark.circle.fill",
                        title: "Siap di basecamp",
                        body: "Hubungkan semua rekan sebelum masuk jalur. Tambah rekan di tengah hutan sulit tanpa sinyal."
                    )
                }
            }

            Spacer()

            Button(step < 2 ? "Lanjut" : "Mulai setup", action: step < 2 ? onContinue : onFinish)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(minHeight: 56)
                .padding(.horizontal)
                .padding(.bottom, 24)
        }
        .padding()
    }

    private func stepContent(icon: String, title: String, body: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text(title)
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text(body)
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}
