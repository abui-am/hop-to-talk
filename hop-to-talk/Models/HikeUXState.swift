import Foundation

enum PTTButtonState: Equatable {
    case ready
    case transmitting
    case disabled(reason: String)

    var isInteractive: Bool {
        switch self {
        case .ready, .transmitting: true
        case .disabled: false
        }
    }

    var primaryLabel: String {
        switch self {
        case .ready: "Tahan"
        case .transmitting: "Bicara..."
        case .disabled: "Tunggu"
        }
    }

    var secondaryLabel: String {
        switch self {
        case .ready: "bicara"
        case .transmitting: "lepas untuk kirim"
        case .disabled(let reason): reason
        }
    }
}

enum RadioConnectionLevel: Equatable {
    case live
    case searching
    case standby
    case offline

    var label: String {
        switch self {
        case .live: "Radio aktif"
        case .searching: "Mencari rekan..."
        case .standby: "Siap — tekan PTT"
        case .offline: "Radio offline"
        }
    }

    var systemImage: String {
        switch self {
        case .live: "antenna.radiowaves.left.and.right"
        case .searching: "dot.radiowaves.left.and.right"
        case .standby: "moon.zzz"
        case .offline: "wifi.slash"
        }
    }
}
