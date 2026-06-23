import Foundation
import Network
import WiFiAware

struct PairedCrewDevice: Identifiable, Sendable {
    let id: UUID
    let name: String
}

@MainActor
@Observable
final class PairingService {
    private(set) var pairedDevices: [PairedCrewDevice] = []
    private(set) var isMonitoring = false
    private var monitorTask: Task<Void, Never>?

    var canStartHike: Bool {
        pairedDevices.count >= 1
    }

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        monitorTask = Task { @MainActor in
            guard WiFiAwareSupport.isAvailable else { return }
            do {
                for try await updatedDevices in WAPairedDevice.allDevices {
                    pairedDevices = updatedDevices.values.map { device in
                        PairedCrewDevice(
                            id: PeerIDMapper.uuid(from: device.id),
                            name: device.name ?? "Rekan"
                        )
                    }
                }
            } catch {
                isMonitoring = false
            }
        }
    }

    func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
        isMonitoring = false
    }
}
