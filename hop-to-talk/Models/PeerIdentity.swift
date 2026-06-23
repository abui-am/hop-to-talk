import Foundation

struct PeerIdentity: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var displayName: String
    var trailPosition: TrailPosition

    init(id: UUID = UUID(), displayName: String, trailPosition: TrailPosition = .middle) {
        self.id = id
        self.displayName = displayName
        self.trailPosition = trailPosition
    }

    static let localDeviceIDKey = "hop_to_talk.local_device_id"
    static let localDisplayNameKey = "hop_to_talk.local_display_name"

    static var localDeviceID: UUID {
        if let stored = UserDefaults.standard.string(forKey: localDeviceIDKey),
           let uuid = UUID(uuidString: stored) {
            return uuid
        }
        let newID = UUID()
        UserDefaults.standard.set(newID.uuidString, forKey: localDeviceIDKey)
        return newID
    }

    static var localDisplayName: String {
        get {
            UserDefaults.standard.string(forKey: localDisplayNameKey) ?? "Rekanku"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: localDisplayNameKey)
        }
    }

    static var localPeer: PeerIdentity {
        PeerIdentity(id: localDeviceID, displayName: localDisplayName)
    }
}

enum PeerIDMapper {
  static func uuid(from deviceID: UInt64) -> UUID {
        var bytes = uuid_t(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        var upper = deviceID.bigEndian
        var lower = deviceID.littleEndian
        withUnsafeMutableBytes(of: &bytes) { destination in
            withUnsafeBytes(of: &upper) { source in
                destination.copyBytes(from: source.prefix(8))
            }
            withUnsafeBytes(of: &lower) { source in
                destination.baseAddress!.advanced(by: 8).copyMemory(
                    from: source.baseAddress!,
                    byteCount: 8
                )
            }
        }
        return UUID(uuid: bytes)
    }
}
