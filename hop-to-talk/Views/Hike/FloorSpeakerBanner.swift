import SwiftUI

struct FloorSpeakerBanner: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "speaker.wave.2.fill")
            .font(.title3.weight(.semibold))
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal)
            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            .accessibilityLabel(text)
    }
}
