import SwiftUI

struct RelayBadge: View {
    var body: some View {
        Label("Relay aktif di kamu", systemImage: "arrow.up.arrow.down")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.orange)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.orange.opacity(0.15), in: Capsule())
    }
}
