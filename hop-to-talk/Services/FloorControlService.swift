import Foundation
import Observation

@Observable
@MainActor
final class FloorControlService {
    private(set) var floorState = FloorState(holder: nil, claimedAt: 0, expiresAt: 0)
    private(set) var activeSpeakerName: String?
    private var sequence: UInt32 = 0

    var localPeerID: UUID { PeerIdentity.localDeviceID }
    var isFloorAvailable: Bool {
        floorState.isExpired
    }

    var isLocalHolder: Bool {
        floorState.isHeld(by: localPeerID)
    }

    func canTransmit() -> Bool {
        floorState.isExpired || floorState.isHeld(by: localPeerID)
    }

    func beginClaim() -> HopPacket {
        sequence &+= 1
        return HopPacket(kind: .floorClaim, source: localPeerID, sequence: sequence)
    }

    func heartbeatIfNeeded() -> HopPacket? {
        guard floorState.isHeld(by: localPeerID) else { return nil }
        let now = FloorState.nowMillis()
        guard now + 1_000 >= floorState.expiresAt - (FloorState.heartbeatSeconds * 1_000) else {
            return nil
        }
        sequence &+= 1
        return HopPacket(kind: .floorHeartbeat, source: localPeerID, sequence: sequence)
    }

    func releaseFloor() -> HopPacket {
        floorState = FloorState(holder: nil, claimedAt: 0, expiresAt: 0)
        activeSpeakerName = nil
        sequence &+= 1
        return HopPacket(kind: .floorRelease, source: localPeerID, sequence: sequence)
    }

    func handleIncoming(_ packet: HopPacket, memberName: String?) {
        let now = FloorState.nowMillis()
        switch packet.kind {
        case .floorClaim, .floorHeartbeat:
            if let holder = floorState.holder, holder != packet.source, !floorState.isExpired {
                if packet.kind == .floorClaim, packet.source.uuidString > holder.uuidString {
                    return
                }
            }
            floorState = FloorState(
                holder: packet.source,
                claimedAt: now,
                expiresAt: now + (FloorState.maxHoldSeconds * 1_000)
            )
            activeSpeakerName = memberName ?? "Rekan"
        case .floorRelease:
            if floorState.holder == packet.source {
                floorState = FloorState(holder: nil, claimedAt: 0, expiresAt: 0)
                activeSpeakerName = nil
            }
        case .floorBusy:
            break
        default:
            break
        }
    }

    func grantLocalFloor() {
        let now = FloorState.nowMillis()
        floorState = FloorState(
            holder: localPeerID,
            claimedAt: now,
            expiresAt: now + (FloorState.maxHoldSeconds * 1_000)
        )
        activeSpeakerName = PeerIdentity.localDisplayName
    }

    func busyResponse(to challenger: UUID) -> HopPacket {
        HopPacket(kind: .floorBusy, source: localPeerID, payload: uuidData(challenger))
    }

    private func uuidData(_ uuid: UUID) -> Data {
        withUnsafeBytes(of: uuid.uuid) { Data($0) }
    }
}
