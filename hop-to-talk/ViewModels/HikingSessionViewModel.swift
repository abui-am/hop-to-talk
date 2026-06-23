import Foundation
import Observation
import os

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
    var operatingMode: HikingOperatingMode = .connected
    var batteryTier: BatteryTier = .alwaysOn

    var hikeStartDate: Date?
    var pttCount = 0
    var isResting = false
    var statusMessage = "Siap di basecamp"
    var crewStatuses: [CrewMemberStatus] = []
    private(set) var connectedPeerIDs: Set<UUID> = []

    /// Replayable history of voice received from other hikers (newest first).
    private(set) var receivedClips: [VoiceClip] = []
    private var incomingBuffers: [UUID: Data] = [:]
    private var lastAudioAt: [UUID: TimeInterval] = [:]
    private var clipFlushTask: Task<Void, Never>?
    private let maxClipHistory = 30

    let pairingService = PairingService()
    let floorControl = FloorControlService()
    let batteryManager = BatteryManager()
    let audioService = AudioEngineService()
    let operatingModeService = OperatingModeService()

    private var packetLoopTask: Task<Void, Never>?
    private var hikeTimerTask: Task<Void, Never>?
    private(set) var isTransmitting = false
    private var lastAckSent: [UUID: TimeInterval] = [:]

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
            return connectedPeerIDs.isEmpty ? .searching : .live
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
        // Count actual live connections (reliable), not inferred signal levels.
        let connected = connectedPeerIDs.count
        if connected == 0 {
            return "Belum ada rekan terhubung"
        }
        return "\(connected) rekan terhubung"
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
        startClipFlushLoop()

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
        clipFlushTask?.cancel()
        // Flush anything still buffered so it lands in history.
        for source in Array(incomingBuffers.keys) { finalizeClip(from: source) }
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
        guard isPTTEnabled else {
            HopLog.ptt.notice("▶️ PTT ignored (disabled) — resting=\(self.isResting), canTransmit=\(self.floorControl.canTransmit())")
            return
        }
        HopLog.ptt.notice("▶️ PTT START mode=\(self.operatingMode.rawValue) connectedPeers=\(self.connectedPeerIDs.count)")
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
        HopLog.ptt.notice("⏹️ PTT END mode=\(self.operatingMode.rawValue)")
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
            await sendBurstSegments(burstData)
        }

        await operatingModeService.broadcast(packet: floorControl.releaseFloor())
        await operatingModeService.finishPTT()
    }

    /// Mode Hemat records the whole press into one buffer (up to ~15 s). That is
    /// far larger than a single UDP datagram (MTU), so the old single-packet send
    /// silently failed and peers heard nothing. Split it into MTU-safe segments;
    /// the receiver schedules them back-to-back for continuous playback.
    private func sendBurstSegments(_ data: Data) async {
        guard !data.isEmpty else { return }
        // 1024 bytes = 512 Int16 samples. Even, so a sample is never split
        // across two packets (which would misalign playback).
        let maxPayload = 1_024
        var offset = 0
        while offset < data.count {
            let end = min(offset + maxPayload, data.count)
            let segment = data.subdata(in: offset..<end)
            let packet = HopPacket(
                kind: .burstSegment,
                source: PeerIdentity.localDeviceID,
                sequence: operatingModeService.nextAudioSequence(),
                payload: segment
            )
            await operatingModeService.broadcast(packet: packet)
            offset = end
        }
    }

    private func accumulateIncomingAudio(_ payload: Data, from source: UUID) {
        let now = Date().timeIntervalSince1970
        // A >2s gap means the previous transmission ended — finalize it first.
        if let last = lastAudioAt[source], now - last > 2.0 {
            finalizeClip(from: source)
        }
        incomingBuffers[source, default: Data()].append(payload)
        lastAudioAt[source] = now
    }

    private func finalizeClip(from source: UUID) {
        guard let pcm = incomingBuffers[source], !pcm.isEmpty else { return }
        incomingBuffers[source] = nil
        lastAudioAt[source] = nil
        let name = party.members.first(where: { $0.id == source })?.displayName ?? "Rekan"
        let clip = VoiceClip(sourceID: source, sourceName: name, receivedAt: Date(), pcm: pcm)
        receivedClips.insert(clip, at: 0)
        if receivedClips.count > maxClipHistory {
            receivedClips.removeLast(receivedClips.count - maxClipHistory)
        }
        HopLog.audio.notice("💾 saved voice clip from \(HopLog.short(source)) — \(clip.durationLabel), history=\(self.receivedClips.count)")
    }

    /// Flushes a transmission to history shortly after it goes quiet, even if the
    /// closing streamEnd packet was lost.
    private func startClipFlushLoop() {
        clipFlushTask?.cancel()
        clipFlushTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                let now = Date().timeIntervalSince1970
                let stale = self.lastAudioAt.filter { now - $0.value > 1.5 }.map(\.key)
                for source in stale {
                    self.finalizeClip(from: source)
                }
            }
        }
    }

    /// Replays a stored clip through the speaker.
    func replayClip(_ clip: VoiceClip) {
        HopLog.audio.notice("⏯️ replay clip from \(HopLog.short(clip.sourceID)) — \(clip.durationLabel)")
        audioService.playPCM(clip.pcm)
    }

    /// Sends a lightweight receipt back to the speaker, at most once per second
    /// per source, so audio traffic isn't doubled by acks.
    private func sendAudioAckIfNeeded(to source: UUID, seq: UInt32) async {
        guard source != PeerIdentity.localDeviceID else { return }
        let now = Date().timeIntervalSince1970
        if let last = lastAckSent[source], now - last < 1.0 { return }
        lastAckSent[source] = now
        let ack = HopPacket(kind: .audioAck, source: PeerIdentity.localDeviceID, sequence: seq)
        await operatingModeService.broadcast(packet: ack)
    }

    private func sendStreamChunk(_ chunk: Data) async {
        let packet = HopPacket(
            kind: .streamChunk,
            source: PeerIdentity.localDeviceID,
            sequence: operatingModeService.nextAudioSequence(),
            payload: chunk
        )
        HopLog.audio.debug("🎤 mic chunk \(chunk.count)B → streamChunk seq=\(packet.sequence)")
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
        operatingModeService.onConnectedPeersUpdate = { [weak self] peers in
            Task { @MainActor in
                self?.applyConnectedPeers(peers)
            }
        }
    }

    private func applyConnectedPeers(_ peers: [UUID]) {
        connectedPeerIDs = Set(peers)
        // Light up the crew rows we recognize; mark the rest offline.
        for index in crewStatuses.indices {
            if connectedPeerIDs.contains(crewStatuses[index].member.id) {
                if crewStatuses[index].linkState == .offline {
                    crewStatuses[index].linkState = .inRange
                }
            } else {
                crewStatuses[index].linkState = .offline
                crewStatuses[index].signalStrength = 0
            }
        }
        updateConnectionStatusMessage()
    }

    private func updateConnectionStatusMessage() {
        guard phase == .activeHike, !isTransmitting, !isResting else { return }
        guard operatingMode == .connected else { return }
        statusMessage = connectedPeerIDs.isEmpty
            ? "Mencari rekan di jalur..."
            : "Terhubung • \(connectedPeerIDs.count) rekan di radio"
    }

    private func handleIncoming(_ packet: HopPacket) async {
        guard await operatingModeService.shouldProcessPacket(packet) else {
            HopLog.net.debug("🚫 dropped duplicate \(String(describing: packet.kind)) seq=\(packet.sequence)")
            return
        }

        let memberName = party.members.first(where: { $0.id == packet.source })?.displayName
        floorControl.handleIncoming(packet, memberName: memberName)

        switch packet.kind {
        case .streamChunk, .burstMessage, .burstSegment:
            // Always play received audio. Previously this was gated on the floor
            // holder being set from a separate floor-claim packet — if that claim
            // was lost, late, or reordered, real voice got silently dropped. The
            // floor state still drives the on-screen "who's talking" banner above;
            // it just no longer blocks playback.
            HopLog.audio.notice("🔊 PLAY \(String(describing: packet.kind)) seq=\(packet.sequence) \(packet.payload.count)B from \(HopLog.short(packet.source))")
            audioService.playPCM(packet.payload)
            accumulateIncomingAudio(packet.payload, from: packet.source)
            // Tell the speaker we actually received their voice, so they can see
            // an end-to-end "✅ teman menerima suara" on their own phone.
            await sendAudioAckIfNeeded(to: packet.source, seq: packet.sequence)
            if let forward = await operatingModeService.forwardPacketIfNeeded(packet) {
                await operatingModeService.forward(packet: forward, excludingPeer: packet.source)
            }
        case .audioAck:
            HopLog.audio.notice("✅ teman MENERIMA suara — ack seq=\(packet.sequence) dari \(HopLog.short(packet.source))")
        case .heartbeat, .peerAnnounce, .floorClaim, .floorRelease, .floorBusy, .floorHeartbeat:
            if let forward = await operatingModeService.forwardPacketIfNeeded(packet) {
                await operatingModeService.forward(packet: forward, excludingPeer: packet.source)
            }
        case .streamEnd:
            finalizeClip(from: packet.source)
        }

        rebuildCrewStatuses()
    }

    private func applySignalStrengths(_ strengths: [UUID: Double]) {
        for (peerID, strength) in strengths {
            if let index = crewStatuses.firstIndex(where: { $0.member.id == peerID }) {
                crewStatuses[index].signalStrength = strength
                // Only refine the link quality when we actually have a reading;
                // a missing/zero sample shouldn't knock a connected peer down.
                if strength > 0.6 {
                    crewStatuses[index].linkState = .inRange
                } else if strength > 0 {
                    crewStatuses[index].linkState = .weakSignal
                } else if connectedPeerIDs.contains(peerID) {
                    crewStatuses[index].linkState = .inRange
                }
            }
        }
    }

    private func rebuildCrewStatuses() {
        var statuses = party.members.map { member in
            let connected = connectedPeerIDs.contains(member.id)
            return CrewMemberStatus(
                member: member,
                linkState: connected ? .inRange : .offline,
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
