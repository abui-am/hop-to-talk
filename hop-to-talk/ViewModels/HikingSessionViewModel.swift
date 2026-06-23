import Foundation
import Observation

@Observable
@MainActor
final class HikingSessionViewModel {
    enum AppPhase: Equatable {
        case onboarding
        case trailhead
        case activeHike
        case summary
    }

    enum TrailheadStep: Int, CaseIterable {
        case partyName = 0
        case pairCrew
        case formation
        case config
    }

    var phase: AppPhase = .onboarding
    var onboardingStep = 0
    var trailheadStep: TrailheadStep = .partyName

    var party = HikingParty(name: "Tim Gunung", members: [], localPosition: .middle)
    var duration: HikeDuration = .medium
    var operatingMode: HikingOperatingMode = .ecoBurst
    var batteryTier: BatteryTier = .balanced

    var hikeStartDate: Date?
    var pttCount = 0
    var isResting = false
    var statusMessage = "Siap di basecamp"
    var crewStatuses: [CrewMemberStatus] = []

    let pairingService = PairingService()
    let floorControl = FloorControlService()
    let batteryManager = BatteryManager()
    let audioService = AudioEngineService()
    let operatingModeService = OperatingModeService()

    private var packetLoopTask: Task<Void, Never>?
    private var hikeTimerTask: Task<Void, Never>?
    private(set) var isTransmitting = false

    var localDisplayName: String {
        get { PeerIdentity.localDisplayName }
        set { PeerIdentity.localDisplayName = newValue }
    }

    var pttButtonState: PTTButtonState {
        if isResting {
            return .disabled(reason: "Istirahat — radio mati")
        }
        if !floorControl.canTransmit() {
            let reason = floorControl.activeSpeakerName.map { "\($0) sedang bicara" }
                ?? "Tunggu giliran bicara"
            return .disabled(reason: reason)
        }
        if isTransmitting {
            return .transmitting
        }
        return .ready
    }

    var statusBannerTone: HikeStatusBanner.Tone {
        if speakerBannerText != nil { return .speaking }
        if statusMessage.contains("menunggu") || statusMessage.contains("tidak tersedia") {
            return .warning
        }
        if isTransmitting || statusMessage.contains("Sedang bicara") {
            return .active
        }
        return .neutral
    }

    var radioConnectionLevel: RadioConnectionLevel {
        switch operatingModeService.sessionState {
        case .activeConnected, .burstActive:
            return crewStatuses.contains(where: { $0.linkState == .inRange || $0.linkState == .weakSignal })
                ? .live
                : .searching
        case .establishing, .coolingDown:
            return .searching
        case .dormant:
            return operatingMode == .ecoBurst ? .standby : .offline
        }
    }

    var pairedCrewCount: Int {
        pairingService.pairedDevices.count
    }

    var canAdvanceFromPairing: Bool {
        pairingService.canStartHike
    }

    var elapsedHikingTime: String {
        guard let hikeStartDate else { return "0m" }
        let minutes = Int(Date().timeIntervalSince(hikeStartDate) / 60)
        if minutes >= 60 {
            return "\(minutes / 60)j \(minutes % 60)m"
        }
        return "\(minutes)m"
    }

    var nearbyCrewLabel: String {
        let nearby = crewStatuses.filter { $0.linkState == .inRange || $0.linkState == .weakSignal }.count
        return "\(nearby + 1)/\(party.memberCount) rekan dekat"
    }

    var isPTTEnabled: Bool {
        floorControl.canTransmit() && !isResting
    }

    var speakerBannerText: String? {
        guard let name = floorControl.activeSpeakerName, !floorControl.isLocalHolder else { return nil }
        return "\(name.uppercased()) sedang bicara..."
    }

    var showRelayBadge: Bool {
        party.localPosition.isRelayProne && operatingMode == .connected
    }

    init() {
        configureCallbacks()
        if UserDefaults.standard.bool(forKey: "hop_to_talk.onboarding_complete") {
            phase = .trailhead
        }
        pairingService.startMonitoring()
        applyRecommendations()
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hop_to_talk.onboarding_complete")
        phase = .trailhead
    }

    func retreatTrailhead() {
        switch trailheadStep {
        case .partyName:
            break
        case .pairCrew:
            trailheadStep = .partyName
        case .formation:
            trailheadStep = .pairCrew
        case .config:
            trailheadStep = .formation
        }
        statusMessage = "Siap di basecamp"
    }

    func advanceTrailhead() {
        switch trailheadStep {
        case .partyName:
            trailheadStep = .pairCrew
        case .pairCrew:
            syncPartyFromPairing()
            guard pairingService.canStartHike else {
                statusMessage = "Hubungkan minimal 1 rekan dulu"
                return
            }
            trailheadStep = .formation
        case .formation:
            trailheadStep = .config
            applyRecommendations()
        case .config:
            Task { await startHike() }
        }
    }

    func syncPartyFromPairing() {
        for device in pairingService.pairedDevices {
            party.upsertMember(
                PeerIdentity(id: device.id, displayName: device.name, trailPosition: .middle)
            )
        }
        rebuildCrewStatuses()
    }

    func applyRecommendations() {
        operatingMode = HikingOperatingMode.recommended(for: duration.rawValue)
        batteryTier = BatteryTier.recommended(for: duration.rawValue)
    }

    func startHike() async {
        hikeStartDate = Date()
        pttCount = 0
        phase = .activeHike
        isResting = false
        batteryManager.applyTier(batteryTier)
        batteryManager.applyHikingMode(true)
        statusMessage = operatingMode == .connected ? "Mendengarkan jalur..." : "Mode hemat — tekan PTT untuk kirim"
        rebuildCrewStatuses()

        _ = await audioService.requestMicrophoneAccess()

        do {
            try await operatingModeService.startHiking(
                mode: operatingMode,
                meshEnabled: operatingMode == .connected,
                heartbeatInterval: batteryManager.heartbeatIntervalSeconds
            )
        } catch {
            statusMessage = "WiFi Aware tidak tersedia di perangkat ini"
        }
    }

    func endHike() async {
        await operatingModeService.stopHiking()
        batteryManager.applyHikingMode(false)
        audioService.stop()
        phase = .summary
    }

    func beginRest() async {
        isResting = true
        await operatingModeService.stopHiking()
        statusMessage = "Istirahat — radio dimatikan sementara"
    }

    func resumeFromRest() async {
        isResting = false
        await startHike()
    }

    func beginPTT() async {
        guard isPTTEnabled else { return }
        isTransmitting = true
        pttCount += 1

        if floorControl.isFloorAvailable {
            floorControl.grantLocalFloor()
            await operatingModeService.broadcast(packet: floorControl.beginClaim())
        }

        let networkReadiness = await operatingModeService.prepareForPTT()

        do {
            if operatingMode == .connected {
                audioService.onAudioChunk = { [weak self] chunk in
                    guard let self else { return }
                    Task { @MainActor in
                        await self.sendStreamChunk(chunk)
                    }
                }
                try await audioService.startStreamingCapture()
            } else {
                audioService.onAudioChunk = { [weak self] chunk in
                    self?.audioService.appendBurstData(chunk)
                }
                try await audioService.startBurstCapture()
            }

            switch networkReadiness {
            case .ready:
                statusMessage = "Sedang bicara..."
            case .waitingForPeers:
                statusMessage = "Gelorong aktif — menunggu rekan dalam jangkauan"
            case .unavailable:
                statusMessage = "Gelorong aktif — WiFi Aware tidak tersedia"
            }
        } catch AudioEngineError.microphoneDenied {
            statusMessage = "Izinkan mikrofon di Pengaturan → Hop to Talk"
            isTransmitting = false
            await operatingModeService.broadcast(packet: floorControl.releaseFloor())
            await operatingModeService.finishPTT()
        } catch {
            statusMessage = "Gagal memulai gelorong — cek izin mikrofon"
            isTransmitting = false
            await operatingModeService.broadcast(packet: floorControl.releaseFloor())
            await operatingModeService.finishPTT()
        }
    }

    func endPTT() async {
        guard isTransmitting else { return }
        isTransmitting = false
        audioService.onAudioChunk = nil

        if operatingMode == .connected {
            audioService.stopStreamingCapture()
            let endPacket = HopPacket(
                kind: .streamEnd,
                source: PeerIdentity.localDeviceID,
                sequence: operatingModeService.nextAudioSequence()
            )
            await operatingModeService.broadcast(packet: endPacket)
        } else {
            let burstData = audioService.finishBurstCapture()
            let packet = HopPacket(
                kind: .burstMessage,
                source: PeerIdentity.localDeviceID,
                sequence: operatingModeService.nextAudioSequence(),
                payload: burstData
            )
            await operatingModeService.broadcast(packet: packet)
        }

        await operatingModeService.broadcast(packet: floorControl.releaseFloor())
        await operatingModeService.finishPTT()
    }

    private func sendStreamChunk(_ chunk: Data) async {
        let packet = HopPacket(
            kind: .streamChunk,
            source: PeerIdentity.localDeviceID,
            sequence: operatingModeService.nextAudioSequence(),
            payload: chunk
        )
        await operatingModeService.broadcast(packet: packet)
    }

    private func configureCallbacks() {
        operatingModeService.onPacketReceived = { [weak self] packet in
            Task { @MainActor in
                await self?.handleIncoming(packet)
            }
        }
        operatingModeService.onSignalUpdate = { [weak self] strengths in
            Task { @MainActor in
                self?.applySignalStrengths(strengths)
            }
        }
    }

    private func handleIncoming(_ packet: HopPacket) async {
        guard await operatingModeService.shouldProcessPacket(packet) else { return }

        let memberName = party.members.first(where: { $0.id == packet.source })?.displayName
        floorControl.handleIncoming(packet, memberName: memberName)

        switch packet.kind {
        case .streamChunk, .burstMessage, .burstSegment:
            if floorControl.floorState.holder == packet.source || packet.kind == .burstMessage {
                audioService.playPCM(packet.payload)
            }
            if let forward = await operatingModeService.forwardPacketIfNeeded(packet) {
                await operatingModeService.forward(packet: forward, excludingPeer: packet.source)
            }
        case .heartbeat, .peerAnnounce, .floorClaim, .floorRelease, .floorBusy, .floorHeartbeat:
            if let forward = await operatingModeService.forwardPacketIfNeeded(packet) {
                await operatingModeService.forward(packet: forward, excludingPeer: packet.source)
            }
        case .streamEnd:
            break
        }

        rebuildCrewStatuses()
    }

    private func applySignalStrengths(_ strengths: [UUID: Double]) {
        for (peerID, strength) in strengths {
            if let index = crewStatuses.firstIndex(where: { $0.member.id == peerID }) {
                crewStatuses[index].signalStrength = strength
                crewStatuses[index].linkState = strength > 0.6 ? .inRange : .weakSignal
            }
        }
    }

    private func rebuildCrewStatuses() {
        var statuses = party.members.map { member in
            CrewMemberStatus(
                member: member,
                linkState: .offline,
                signalStrength: 0,
                isSpeaking: floorControl.floorState.holder == member.id
            )
        }
        if pairingService.pairedDevices.isEmpty, statuses.isEmpty {
            statuses = [
                CrewMemberStatus(
                    member: PeerIdentity(id: UUID(), displayName: "Rekan (pair di basecamp)", trailPosition: .middle),
                    linkState: .offline,
                    signalStrength: 0,
                    isSpeaking: false
                )
            ]
        }
        crewStatuses = statuses
    }
}
