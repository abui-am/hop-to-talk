import Foundation
import Observation
import UIKit

@Observable
@MainActor
final class BatteryManager {
    var tier: BatteryTier = .balanced
    var hikingModeEnabled = false

    func applyHikingMode(_ enabled: Bool) {
        hikingModeEnabled = enabled
        UIApplication.shared.isIdleTimerDisabled = enabled && tier == .alwaysOn
    }

    func applyTier(_ newTier: BatteryTier) {
        tier = newTier
        if hikingModeEnabled {
            UIApplication.shared.isIdleTimerDisabled = newTier == .alwaysOn
        }
    }

    var heartbeatIntervalSeconds: TimeInterval {
        switch tier {
        case .eco: 90
        case .balanced: 75
        case .alwaysOn: 60
        }
    }

    var reconnectBackoffSeconds: TimeInterval {
        switch tier {
        case .eco: 60
        case .balanced: 30
        case .alwaysOn: 10
        }
    }

    var statusLabel: String {
        if hikingModeEnabled {
            return "Hiking Mode ON"
        }
        return "Hiking Mode OFF"
    }
}
