import SwiftUI

struct RecommendationCard: View {
    let title: String
    let subtitle: String
    let isRecommended: Bool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        if isRecommended {
                            Text("Rekomendasi")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.green.opacity(0.25), in: Capsule())
                                .foregroundStyle(.green)
                        }
                    }
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
                    }
            }
        }
        .buttonStyle(.plain)
        .frame(minHeight: 56)
    }
}
