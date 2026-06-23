import Foundation

enum CrewLinkState: String, Sendable {
    case inRange
    case weakSignal
    case relayOnly
    case offline

    var label: String {
        switch self {
        case .inRange: "Dekat"
        case .weakSignal: "Lemah"
        case .relayOnly: "Relay"
        case .offline: "Offline"
        }
    }
}

struct CrewMemberStatus: Identifiable, Sendable {
    let member: PeerIdentity
    var linkState: CrewLinkState
    var signalStrength: Double
    var isSpeaking: Bool

    var id: UUID { member.id }
}
