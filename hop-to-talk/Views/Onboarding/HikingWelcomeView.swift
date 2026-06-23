import SwiftUI

struct HikingWelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: "mountain.2.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
                .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text("Komunikasi di jalur tanpa sinyal")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text("Hop to Talk menghubungkan tim pendakian lewat WiFi langsung antar iPhone — tanpa operator seluler.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)

            Spacer()

            Button("Lanjut", action: onContinue)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(minHeight: 56)
                .padding(.horizontal)
                .padding(.bottom, 24)
        }
        .padding()
    }
}
