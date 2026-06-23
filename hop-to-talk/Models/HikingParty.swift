import Foundation

struct HikingParty: Codable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var members: [PeerIdentity]
    var localPosition: TrailPosition

    static let partyBroadcastID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    init(
        id: UUID = UUID(),
        name: String,
        members: [PeerIdentity] = [],
        localPosition: TrailPosition = .middle
    ) {
        self.id = id
        self.name = name
        self.members = members
        self.localPosition = localPosition
    }

    var memberCount: Int {
        members.count + 1
    }

    mutating func upsertMember(_ member: PeerIdentity) {
        if let index = members.firstIndex(where: { $0.id == member.id }) {
            members[index] = member
        } else {
            members.append(member)
        }
    }
}
