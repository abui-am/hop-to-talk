import Foundation

enum PacketKind: UInt8, Sendable {
    case streamChunk = 1
    case streamEnd = 2
    case burstMessage = 3
    case burstSegment = 4
    case heartbeat = 5
    case peerAnnounce = 6
    case floorClaim = 10
    case floorRelease = 11
    case floorBusy = 12
    case floorHeartbeat = 13
}

struct HopPacket: Sendable {
    let kind: PacketKind
    let source: UUID
    let sequence: UInt32
    let ttl: UInt8
    let payload: Data

    init(
        kind: PacketKind,
        source: UUID,
        sequence: UInt32 = 0,
        ttl: UInt8 = 5,
        payload: Data = Data()
    ) {
        self.kind = kind
        self.source = source
        self.sequence = sequence
        self.ttl = ttl
        self.payload = payload
    }
}

enum PacketCodec {
    // kind (1) + source UUID (16) + sequence (4) + ttl (1) = 22 bytes
    private static let headerSize = 22

    static func encode(_ packet: HopPacket) -> Data {
        var data = Data(capacity: headerSize + packet.payload.count)
        data.append(packet.kind.rawValue)
        data.append(uuidData(packet.source))
        var sequence = packet.sequence.bigEndian
        withUnsafeBytes(of: &sequence) { data.append(contentsOf: $0) }
        data.append(packet.ttl)
        data.append(packet.payload)
        return data
    }

    static func decode(_ data: Data) -> HopPacket? {
        guard data.count >= headerSize else { return nil }
        guard let kind = PacketKind(rawValue: data[0]) else { return nil }
        let source = uuid(from: data.subdata(in: 1..<17))
        let sequence = data.subdata(in: 17..<21).withUnsafeBytes {
            $0.load(as: UInt32.self).bigEndian
        }
        let ttl = data[21]
        let payload = data.subdata(in: headerSize..<data.count)
        return HopPacket(kind: kind, source: source, sequence: sequence, ttl: ttl, payload: payload)
    }

    private static func uuidData(_ uuid: UUID) -> Data {
        withUnsafeBytes(of: uuid.uuid) { Data($0) }
    }

    private static func uuid(from data: Data) -> UUID {
        let bytes = [UInt8](data.prefix(16))
        guard bytes.count == 16 else { return UUID() }
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
