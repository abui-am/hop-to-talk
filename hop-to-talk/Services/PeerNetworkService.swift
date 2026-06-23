import Foundation
import Network
import os
import WiFiAware

actor PeerNetworkService {
    private var connections: [UUID: NetworkConnection<UDP>] = [:]
    private var listenerTask: Task<Void, Never>?
    private var browserTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var receiveTasks: [UUID: Task<Void, Never>] = [:]
    private var performanceMode: WAPerformanceMode = .bulk
    private var isPersistent = false

    private let incomingStream: AsyncStream<HopPacket>
    private let incomingContinuation: AsyncStream<HopPacket>.Continuation

    private let signalStream: AsyncStream<[UUID: Double]>
    private let signalContinuation: AsyncStream<[UUID: Double]>.Continuation

    private let connectedStream: AsyncStream<[UUID]>
    private let connectedContinuation: AsyncStream<[UUID]>.Continuation

    var incomingPackets: AsyncStream<HopPacket> { incomingStream }
    var signalUpdates: AsyncStream<[UUID: Double]> { signalStream }
    /// Emits the current set of connected peer IDs every time a peer joins or
    /// drops, so the UI can show a reliable "connected" state instead of
    /// guessing from signal-strength samples.
    var connectedPeers: AsyncStream<[UUID]> { connectedStream }

    init() {
        var packetContinuation: AsyncStream<HopPacket>.Continuation!
        incomingStream = AsyncStream { packetContinuation = $0 }
        incomingContinuation = packetContinuation

        var signalCont: AsyncStream<[UUID: Double]>.Continuation!
        signalStream = AsyncStream { signalCont = $0 }
        signalContinuation = signalCont

        var connectedCont: AsyncStream<[UUID]>.Continuation!
        connectedStream = AsyncStream { connectedCont = $0 }
        connectedContinuation = connectedCont
    }

    private func emitConnectedPeers() {
        connectedContinuation.yield(Array(connections.keys))
    }

    func setPerformanceMode(_ mode: WAPerformanceMode) {
        performanceMode = mode
    }

    func startPersistentSession(heartbeatInterval: TimeInterval) async throws {
        guard WiFiAwareSupport.isAvailable,
              let publishService = WAPublishableService.hopTalkService else {
            throw PeerNetworkError.unavailable
        }
        isPersistent = true
        await startListener(publishService: publishService)
        startBackgroundBrowse(subscribeService: WASubscribableService.hopTalkService)
        startHeartbeat(interval: heartbeatInterval)
    }

    func establishBurstSession(timeout: TimeInterval) async -> Bool {
        guard WiFiAwareSupport.isAvailable,
              let publishService = WAPublishableService.hopTalkService,
              let subscribeService = WASubscribableService.hopTalkService else {
            return false
        }
        isPersistent = false
        await startListener(publishService: publishService)
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await self.browseAndConnect(subscribeService: subscribeService)
                }
                group.addTask {
                    try await Task.sleep(for: .seconds(timeout))
                    throw PeerNetworkError.timeout
                }
                try await group.next()
                group.cancelAll()
            }
            return true
        } catch {
            // Listener may still be running for inbound peers.
            return !connections.isEmpty
        }
    }

    func teardown() async {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        listenerTask?.cancel()
        listenerTask = nil
        browserTask?.cancel()
        browserTask = nil
        for task in receiveTasks.values { task.cancel() }
        receiveTasks.removeAll()
        connections.removeAll()
        isPersistent = false
        emitConnectedPeers()
    }

    func send(_ packet: HopPacket, excludingPeer: UUID? = nil) async {
        let data = PacketCodec.encode(packet)
        let targets = connections.filter { $0.key != excludingPeer }
        guard !targets.isEmpty else {
            HopLog.net.warning(
                "📤 TX \(String(describing: packet.kind)) seq=\(packet.sequence) \(data.count)B but NO peers connected"
            )
            return
        }
        var sent = 0
        for (_, connection) in targets {
            do {
                try await send(data: data, on: connection)
                sent += 1
            } catch {
                HopLog.net.error("send failed: \(error.localizedDescription)")
            }
        }
        HopLog.net.notice(
            "📤 TX \(String(describing: packet.kind)) seq=\(packet.sequence) \(data.count)B → \(sent)/\(targets.count) peers"
        )
    }

    func connectedPeerIDs() -> [UUID] {
        Array(connections.keys)
    }

    private func startListener(publishService: WAPublishableService) async {
        listenerTask?.cancel()
        listenerTask = Task {
            do {
                try await NetworkListener(
                    for: .wifiAware(.connecting(to: publishService, from: .allPairedDevices)),
                    using: self.connectionParameters()
                )
                .run { connection in
                    await self.attachIncoming(connection)
                }
            } catch {
                // Listener ended; persistent sessions may restart from OperatingModeService.
            }
        }
    }

    private func startBackgroundBrowse(subscribeService: WASubscribableService?) {
        guard let subscribeService else { return }
        browserTask?.cancel()
        browserTask = Task {
            do {
                let browser = NetworkBrowser(
                    for: .wifiAware(.connecting(to: .allPairedDevices, from: subscribeService))
                )
                let endpoint = try await browser.run { endpoints in
                    if let first = endpoints.first {
                        return .finish(first)
                    }
                    return .continue
                }
                let connection = NetworkConnection(to: endpoint, using: self.connectionParameters())
                await self.attachOutgoing(connection)
            } catch {
                // Keep listening for inbound connections from peers.
            }
        }
    }

    private func browseAndConnect(subscribeService: WASubscribableService?) async throws {
        guard let subscribeService else { throw PeerNetworkError.unavailable }
        browserTask?.cancel()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            browserTask = Task {
                do {
                    let browser = NetworkBrowser(
                        for: .wifiAware(.connecting(to: .allPairedDevices, from: subscribeService))
                    )
                    let endpoint = try await browser.run { endpoints in
                        if let first = endpoints.first {
                            return .finish(first)
                        }
                        return .continue
                    }
                    let connection = NetworkConnection(to: endpoint, using: self.connectionParameters())
                    await self.attachOutgoing(connection)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func connectionParameters() -> NWParametersBuilder<UDP> {
        NWParametersBuilder.parameters {
            UDP()
        }
        .wifiAware { parameters in
            parameters.performanceMode = self.performanceMode
        }
        .serviceClass(performanceMode == .realtime ? .interactiveVoice : .bestEffort)
    }

    private func attachIncoming(_ connection: NetworkConnection<UDP>) async {
        let peerID = await resolvePeerID(for: connection) ?? UUID()
        connections[peerID] = connection
        startReceiveLoop(for: peerID, connection: connection)
        HopLog.net.notice("🤝 peer connected (inbound) \(HopLog.short(peerID)) — total \(self.connections.count)")
        emitConnectedPeers()
    }

    private func attachOutgoing(_ connection: NetworkConnection<UDP>) async {
        let peerID = await resolvePeerID(for: connection) ?? UUID()
        connections[peerID] = connection
        startReceiveLoop(for: peerID, connection: connection)
        HopLog.net.notice("🤝 peer connected (outbound) \(HopLog.short(peerID)) — total \(self.connections.count)")
        emitConnectedPeers()
    }

    private func dropConnection(_ peerID: UUID) {
        guard connections.removeValue(forKey: peerID) != nil else { return }
        HopLog.net.notice("❌ peer dropped \(HopLog.short(peerID)) — total \(self.connections.count)")
        emitConnectedPeers()
    }

    private func resolvePeerID(for connection: NetworkConnection<UDP>) async -> UUID? {
        if let path = connection.currentPath,
           let waPath = try? await path.wifiAware {
            return PeerIDMapper.uuid(from: waPath.endpoint.device.id)
        }
        if let endpoint = connection.remoteEndpoint?.wifiAware {
            return PeerIDMapper.uuid(from: endpoint.device.id)
        }
        return nil
    }

    private func startReceiveLoop(for peerID: UUID, connection: NetworkConnection<UDP>) {
        receiveTasks[peerID]?.cancel()
        receiveTasks[peerID] = Task {
            do {
                while !Task.isCancelled {
                    let message = try await connection.receive()
                    if let packet = PacketCodec.decode(message.content) {
                        HopLog.net.notice(
                            "📥 RX \(String(describing: packet.kind)) seq=\(packet.sequence) \(message.content.count)B from \(HopLog.short(peerID))"
                        )
                        incomingContinuation.yield(packet)
                    } else {
                        HopLog.net.error("📥 RX undecodable datagram \(message.content.count)B from \(HopLog.short(peerID))")
                    }
                }
            } catch {
                self.dropConnection(peerID)
            }
        }
        Task {
            if let path = connection.currentPath,
               let waPath = try? await path.wifiAware {
                let strength = waPath.performance.signalStrength ?? 0
                signalContinuation.yield([peerID: strength])
            }
        }
    }

    private func send(data: Data, on connection: NetworkConnection<UDP>) async throws {
        try await connection.send(data)
    }

    private func startHeartbeat(interval: TimeInterval) {
        heartbeatTask?.cancel()
        heartbeatTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                let packet = HopPacket(
                    kind: .heartbeat,
                    source: PeerIdentity.localDeviceID,
                    sequence: UInt32.random(in: 0...UInt32.max)
                )
                await send(packet)
            }
        }
    }
}

enum PeerNetworkError: Error {
    case unavailable
    case timeout
}
