import SwiftUI

struct OnboardingFlowView: View {
    @Bindable var viewModel: HikingSessionViewModel
    @State private var page = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "mountain.2.fill",
            iconColor: .green,
            title: "Komunikasi di jalur tanpa sinyal",
            body: "Hop to Talk menghubungkan tim pendakian lewat WiFi langsung antar iPhone — tanpa operator seluler."
        ),
        OnboardingPage(
            icon: "figure.hiking",
            iconColor: .accentColor,
            title: "Cara kerja",
            body: "Pair di basecamp → atur barisan → tahan tombol untuk bicara ke seluruh tim."
        ),
        OnboardingPage(
            icon: "exclamationmark.triangle.fill",
            iconColor: .orange,
            title: "Yang perlu kamu tahu",
            body: "Aktifkan Hiking Mode saat pendakian. Bukan pengganti radio SOS. Untuk 3–6 orang, iPhone 12+."
        ),
        OnboardingPage(
            icon: "checkmark.circle.fill",
            iconColor: .green,
            title: "Siap di basecamp?",
            body: "Hubungkan semua rekan sebelum masuk jalur. Tambah rekan di tengah hutan hampir mustahil tanpa sinyal."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, onboardingPage in
                    onboardingPageView(onboardingPage)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button(page < pages.count - 1 ? "Lanjut" : "Mulai setup") {
                if page < pages.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    viewModel.completeOnboarding()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private func onboardingPageView(_ onboardingPage: OnboardingPage) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: onboardingPage.icon)
                .font(.system(size: 64))
                .foregroundStyle(onboardingPage.iconColor)
                .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text(onboardingPage.title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                Text(onboardingPage.body)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(.horizontal, 24)
            Spacer()
            Spacer()
        }
    }
}

private struct OnboardingPage {
    let icon: String
    let iconColor: Color
    let title: String
    let body: String
}
