import SwiftUI

struct ReceivedClipsView: View {
    @Bindable var viewModel: HikingSessionViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.receivedClips.isEmpty {
                    ContentUnavailableView {
                        Label("Belum ada suara masuk", systemImage: "waveform.slash")
                    } description: {
                        Text("Suara yang diterima dari rekan akan muncul di sini dan bisa diputar ulang.")
                    }
                } else {
                    List(viewModel.receivedClips) { clip in
                        Button {
                            viewModel.replayClip(clip)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "play.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(.green)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(clip.sourceName)
                                        .font(.headline)
                                    Text("\(clip.timeLabel) · \(clip.durationLabel)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "waveform")
                                    .foregroundStyle(.secondary)
                            }
                            .frame(minHeight: 52)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Riwayat suara")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Tutup") { dismiss() }
                }
            }
        }
    }
}
