import Foundation
import WiFiAware

enum PTTNetworkReadiness: Sendable {
    case ready
    case waitingForPeers
    case unavailable
}

@MainActor
final class OperatingModeService {
    private let network = PeerNetworkService()
    private let mesh = MeshRelayService()
    private var packetTask: Task<Void, Never>?
    private var signalTask: Task<Void, Never>?
    private var connectedTask: Task<Void, Never>?
    private var coolingTask: Task<Void, Never>?
    private var audioSequence: UInt32 = 0

    var onPacketReceived: ((HopPacket) -> Void)?
    var onSignalUpdate: (([UUID: Double]) -> Void)?
    var onConnectedPeersUpdate: (([UUID]) -> Void)?

    private(set) var sessionState: NetworkSessionState = .dormant
    private(set) var operatingMode: HikingOperatingMode = .connected

    func startHiking(
        mode: HikingOperatingMode,
        meshEnabled: Bool,
        heartbeatInterval: TimeInterval
    ) async throws {
        operatingMode = mode
        await mesh.setEnabled(meshEnabled && mode == .connected)
        startObservers()

        switch mode {
        case .connected:
            sessionState = .establishing
            try await network.setPerformanceMode(.bulk)
            try await network.startPersistentSession(heartbeatInterval: heartbeatInterval)
            sessionState = .activeConnected
        case .ecoBurst:
            sessionState = .dormant
        }
    }

    func prepareForPTT() async -> PTTNetworkReadiness {
        switch operatingMode {
        case .connected:
            await network.setPerformanceMode(.realtime)
            sessionState = .activeConnected
            return .ready
        case .ecoBurst:
            sessionState = .establishing
            let connected = await network.establishBurstSession(timeout: 8)
            if connected {
                sessionState = .burstActive
                return .ready
            }
            if WiFiAwareSupport.isAvailable {
                sessionState = .establishing
                return .waitingForPeers
            }
            sessionState = .dormant
            return .unavailable
        }
    }

    func finishPTT() async {
        switch operatingMode {
        case .connected:
            await network.setPerformanceMode(.bulk)
            sessionState = .activeConnected
        case .ecoBurst:
            sessionState = .coolingDown
            coolingTask?.cancel()
            coolingTask = Task {
                try? await Task.sleep(for: .seconds(30))
                await network.teardown()
                sessionState = .dormant
            }
        }
    }

    func stopHiking() async {
        packetTask?.cancel()
        signalTask?.cancel()
        connectedTask?.cancel()
        coolingTask?.cancel()
        await network.teardown()
        sessionState = .dormant
    }

    func broadcast(packet: HopPacket) async {
        await network.send(packet)
    }

    func forward(packet: HopPacket, excludingPeer: UUID) async {
        await network.send(packet, excludingPeer: excludingPeer)
    }

    func nextAudioSequence() -> UInt32 {
        audioSequence &+= 1
        return audioSequence
    }

    func shouldProcessPacket(_ packet: HopPacket) async -> Bool {
        await mesh.shouldProcess(packet: packet, localPeerID: PeerIdentity.localDeviceID)
    }

    func forwardPacketIfNeeded(_ packet: HopPacket) async -> HopPacket? {
        await mesh.shouldForward(packet: packet, localPeerID: PeerIdentity.localDeviceID)
    }

    private func startObservers() {
        packetTask?.cancel()
        packetTask = Task {
            for await packet in await network.incomingPackets {
                onPacketReceived?(packet)
            }
        }
        signalTask?.cancel()
        signalTask = Task {
            for await strengths in await network.signalUpdates {
                onSignalUpdate?(strengths)
            }
        }
        connectedTask?.cancel()
        connectedTask = Task {
            for await peers in await network.connectedPeers {
                onConnectedPeersUpdate?(peers)
            }
        }
    }
}
