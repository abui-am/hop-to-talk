import Foundation

/// One received transmission (a full PTT press from another hiker), stored so it
/// can be replayed from the history list.
struct VoiceClip: Identifiable, Sendable {
    let id = UUID()
    let sourceID: UUID
    let sourceName: String
    let receivedAt: Date
    let pcm: Data

    /// 16 kHz, mono, Int16 → 2 bytes per sample.
    var durationSeconds: Double {
        Double(pcm.count) / 2.0 / 16_000.0
    }

    var durationLabel: String {
        String(format: "%.1fs", durationSeconds)
    }

    var timeLabel: String {
        receivedAt.formatted(date: .omitted, time: .standard)
    }
}
