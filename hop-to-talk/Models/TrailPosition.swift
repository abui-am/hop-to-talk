import Foundation

enum TrailPosition: String, Codable, CaseIterable, Identifiable, Sendable {
    case lead = "Depan"
    case middle = "Tengah"
    case sweep = "Belakang"

    var id: String { rawValue }

    var isRelayProne: Bool {
        self == .middle
    }
}
