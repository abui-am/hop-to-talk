import Foundation

actor MeshRelayService {
    private var recentPackets: [String: UInt64] = [:]
    private let dedupWindowMs: UInt64 = 2_000
    var isEnabled = true

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }

    func shouldProcess(packet: HopPacket, localPeerID: UUID) -> Bool {
        guard isEnabled else { return packet.source == localPeerID }
        // Key must include the packet kind: floor-control and audio packets use
        // independent sequence counters that both start at 1, so without the
        // kind the first audio chunk collides with the floor claim and gets
        // dropped as a false duplicate — i.e. no sound on the receiver.
        let key = "\(packet.source.uuidString)-\(packet.kind.rawValue)-\(packet.sequence)"
        let now = FloorState.nowMillis()
        if let seenAt = recentPackets[key], now - seenAt < dedupWindowMs {
            return false
        }
        recentPackets[key] = now
        pruneOldEntries(now: now)
        return true
    }

    func shouldForward(packet: HopPacket, localPeerID: UUID) -> HopPacket? {
        guard isEnabled, packet.ttl > 0 else { return nil }
        switch packet.kind {
        case .streamChunk, .burstMessage, .burstSegment, .heartbeat, .floorClaim, .floorRelease, .floorHeartbeat:
            break
        default:
            return nil
        }
        return HopPacket(
            kind: packet.kind,
            source: packet.source,
            sequence: packet.sequence,
            ttl: packet.ttl - 1,
            payload: packet.payload
        )
    }

    private func pruneOldEntries(now: UInt64) {
        recentPackets = recentPackets.filter { now - $0.value < dedupWindowMs }
    }
}
