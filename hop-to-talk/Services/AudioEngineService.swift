import AVFoundation
import Foundation
import Observation

enum AudioEngineError: LocalizedError {
    case microphoneDenied
    case sessionConfigurationFailed
    case engineStartFailed

    var errorDescription: String? {
        switch self {
        case .microphoneDenied:
            "Akses mikrofon ditolak"
        case .sessionConfigurationFailed:
            "Gagal mengatur sesi audio"
        case .engineStartFailed:
            "Gagal memulai audio engine"
        }
    }
}

@Observable
@MainActor
final class AudioEngineService {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var inputTapInstalled = false
    private(set) var isRecording = false
    private(set) var isPlaying = false

    var onAudioChunk: ((Data) -> Void)?
    var onBurstReady: ((Data) -> Void)?

    private let sampleRate: Double = 16_000
    private var burstBuffer = Data()

    init() {
        setupEngine()
    }

    static func requestMicrophoneAccess() async -> Bool {
        let session = AVAudioSession.sharedInstance()
        switch session.recordPermission {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return await withCheckedContinuation { continuation in
                session.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }

    func requestMicrophoneAccess() async -> Bool {
        await Self.requestMicrophoneAccess()
    }

    private func activateSession() throws {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.allowBluetooth, .defaultToSpeaker]
            )
            try session.setActive(true)
        } catch {
            throw AudioEngineError.sessionConfigurationFailed
        }
    }

    private func setupEngine() {
        engine.attach(playerNode)
        let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: true
        )!
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
    }

    func startStreamingCapture() async throws {
        guard !isRecording else { return }

        guard await requestMicrophoneAccess() else {
            throw AudioEngineError.microphoneDenied
        }
        try activateSession()

        let input = engine.inputNode
        let hardwareFormat = input.outputFormat(forBus: 0)
        let tapFormat: AVAudioFormat
        if hardwareFormat.sampleRate > 0, hardwareFormat.channelCount > 0 {
            tapFormat = hardwareFormat
        } else {
            tapFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: sampleRate,
                channels: 1,
                interleaved: false
            )!
        }

        if inputTapInstalled {
            input.removeTap(onBus: 0)
            inputTapInstalled = false
        }

        engine.prepare()
        input.installTap(onBus: 0, bufferSize: 1_024, format: tapFormat) { [weak self] buffer, _ in
            guard let self, let data = Self.pcmData(from: buffer) else { return }
            Task { @MainActor in
                self.onAudioChunk?(data)
            }
        }
        inputTapInstalled = true

        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                input.removeTap(onBus: 0)
                inputTapInstalled = false
                throw AudioEngineError.engineStartFailed
            }
        }
        isRecording = true
    }

    func stopStreamingCapture() {
        guard isRecording else { return }
        if inputTapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            inputTapInstalled = false
        }
        isRecording = false
    }

    func startBurstCapture() async throws {
        burstBuffer.removeAll(keepingCapacity: true)
        try await startStreamingCapture()
    }

    func finishBurstCapture() -> Data {
        stopStreamingCapture()
        let data = burstBuffer
        burstBuffer.removeAll(keepingCapacity: true)
        return data
    }

    func appendBurstData(_ data: Data) {
        burstBuffer.append(data)
        if burstBuffer.count > 480_000 {
            burstBuffer.removeFirst(burstBuffer.count - 480_000)
        }
    }

    func playPCM(_ data: Data) {
        guard !data.isEmpty else { return }
        let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: true
        )!
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(data.count) / 2
        ) else {
            return
        }
        buffer.frameLength = buffer.frameCapacity
        data.withUnsafeBytes { rawBuffer in
            guard let source = rawBuffer.baseAddress else { return }
            memcpy(buffer.int16ChannelData![0], source, data.count)
        }
        if !engine.isRunning {
            try? activateSession()
            try? engine.start()
        }
        isPlaying = true
        playerNode.scheduleBuffer(buffer) { [weak self] in
            Task { @MainActor in
                self?.isPlaying = false
            }
        }
        if !playerNode.isPlaying {
            playerNode.play()
        }
    }

    func stop() {
        stopStreamingCapture()
        playerNode.stop()
        engine.stop()
    }

    private static func pcmData(from buffer: AVAudioPCMBuffer) -> Data? {
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return nil }

        if let channelData = buffer.int16ChannelData {
            let byteCount = frameCount * MemoryLayout<Int16>.size
            return Data(bytes: channelData[0], count: byteCount)
        }

        if let channelData = buffer.floatChannelData {
            var samples = [Int16]()
            samples.reserveCapacity(frameCount)
            for index in 0..<frameCount {
                let sample = max(-1.0, min(1.0, channelData[0][index]))
                samples.append(Int16(sample * Float(Int16.max)))
            }
            return samples.withUnsafeBufferPointer { Data(buffer: $0) }
        }

        return nil
    }
}
