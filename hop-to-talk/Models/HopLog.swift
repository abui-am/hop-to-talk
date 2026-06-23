import Foundation
import OSLog

/// Centralised logging for end-to-end voice debugging.
///
/// View the logs while two phones are connected:
/// - In **Xcode**: run the app from Xcode and watch the console (debug area).
/// - In **Console.app**: filter by subsystem `com.abui.hop-to-talk`.
///
/// The trail of a working "speak" looks like, on the sender:
///   `▶️ PTT START` → `📤 TX streamChunk … → N peers` (repeating) → `⏹️ PTT END`
/// and on the receiver:
///   `📥 RX streamChunk …` → `🔊 PLAY … bytes` (repeating).
enum HopLog {
    private static let subsystem = "com.abui.hop-to-talk"

    static let ptt = Logger(subsystem: subsystem, category: "ptt")
    static let net = Logger(subsystem: subsystem, category: "net")
    static let audio = Logger(subsystem: subsystem, category: "audio")
    static let floor = Logger(subsystem: subsystem, category: "floor")

    /// Short, readable id for a peer/source UUID (first 4 chars).
    static func short(_ id: UUID) -> String {
        String(id.uuidString.prefix(4))
    }
}
