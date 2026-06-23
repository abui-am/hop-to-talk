import Foundation

enum HikingOperatingMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case connected
    case ecoBurst

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .connected: "Mode Live"
        case .ecoBurst: "Mode Hemat"
        }
    }

    var subtitle: String {
        switch self {
        case .connected: "Walkie-talkie real-time di jalur"
        case .ecoBurst: "Kirim suara saat perlu, hemat baterai"
        }
    }

    static func recommended(for durationHours: Double) -> HikingOperatingMode {
        durationHours < 4 ? .connected : .ecoBurst
    }
}

enum NetworkSessionState: String, Sendable {
    case dormant
    case establishing
    case activeConnected
    case burstActive
    case coolingDown
}

enum BatteryTier: String, Codable, CaseIterable, Identifiable, Sendable {
    case eco
    case balanced
    case alwaysOn

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .eco: "Eco"
        case .balanced: "Balanced"
        case .alwaysOn: "Always On"
        }
    }

    static func recommended(for durationHours: Double) -> BatteryTier {
        if durationHours < 4 { return .balanced }
        if durationHours < 6 { return .eco }
        return .eco
    }
}

enum HikeDuration: Double, CaseIterable, Identifiable {
    case short = 3
    case medium = 5
    case long = 8

    var id: Double { rawValue }

    var label: String {
        switch self {
        case .short: "Kurang dari 4 jam"
        case .medium: "4–6 jam"
        case .long: "Lebih dari 6 jam"
        }
    }
}
