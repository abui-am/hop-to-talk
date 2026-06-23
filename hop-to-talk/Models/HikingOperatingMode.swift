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
        // Focused on Mode Live for now — it's the path we've verified end to end.
        // (Mode Hemat/ecoBurst is still selectable but no longer the default.)
        .connected
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
        // Fokus ke Always On: layar tetap nyala supaya terima suara andal di
        // foreground (Hiking Mode). Tier lain tetap bisa dipilih manual.
        .alwaysOn
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
