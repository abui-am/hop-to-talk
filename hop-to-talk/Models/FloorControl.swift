import Foundation

struct FloorState: Sendable {
    var holder: UUID?
    var claimedAt: UInt64
    var expiresAt: UInt64

    static let maxHoldSeconds: UInt64 = 60
    static let heartbeatSeconds: UInt64 = 5

    var isExpired: Bool {
        guard holder != nil else { return true }
        return Self.nowMillis() >= expiresAt
    }

    func isHeld(by peerID: UUID) -> Bool {
        holder == peerID && !isExpired
    }

    static func nowMillis() -> UInt64 {
        UInt64(Date().timeIntervalSince1970 * 1000)
    }
}

enum FloorDecision: Sendable {
    case granted
    case busy(holderName: String)
    case denied
}
