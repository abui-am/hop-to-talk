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

    /// Wire/playback format shared by every device: 16 kHz, mono, Int16.
    /// The mic hardware usually runs at 44.1/48 kHz, so capture is resampled
    /// down to this before transmit; otherwise the receiver (which plays at
    /// 16 kHz) hears voice ~3x too slow and deep.
    private var wireFormat: AVAudioFormat {
        AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: true
        )!
    }

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

    /// The format the engine graph runs in. AVAudioEngine's mixer expects
    /// standard (non-interleaved Float32) buffers — connecting the player with an
    /// interleaved Int16 format throws inside CoreAudio and crashes the app, and
    /// can also silently drop audio. We keep Int16 only on the network wire and
    /// convert at playback.
    private var playbackFormat: AVAudioFormat {
        AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    }

    private func setupEngine() {
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: playbackFormat)
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
        // Build a converter from the mic's hardware format to the shared
        // 16 kHz mono wire format. Captured here (not on the audio thread) and
        // used only inside the serial tap callback, so it needs no locking.
        let target = wireFormat
        let converter = AVAudioConverter(from: tapFormat, to: target)
        input.installTap(onBus: 0, bufferSize: 1_024, format: tapFormat) { [weak self] buffer, _ in
            guard let self,
                  let data = Self.wireData(from: buffer, using: converter, to: target) else { return }
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
        // Two bytes per Int16 sample. Drop a trailing odd byte so reads never
        // run past the sample count.
        let frameCount = data.count / 2
        guard frameCount > 0 else { return }

        // Build a Float32 buffer in the engine's playback format directly from
        // the Int16 wire bytes, so the buffer always matches the player node's
        // connection format (a mismatch crashes scheduleBuffer).
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: playbackFormat,
            frameCapacity: AVAudioFrameCount(frameCount)
        ), let output = buffer.floatChannelData?[0] else {
            return
        }
        buffer.frameLength = AVAudioFrameCount(frameCount)
        let scale = 1.0 / Float(Int16.max)
        data.withUnsafeBytes { rawBuffer in
            let samples = rawBuffer.bindMemory(to: Int16.self)
            for index in 0..<frameCount {
                output[index] = Float(samples[index]) * scale
            }
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

    /// Resamples a captured buffer into the 16 kHz mono wire format and returns
    /// its raw Int16 bytes. Runs on the realtime audio thread.
    private static func wireData(
        from buffer: AVAudioPCMBuffer,
        using converter: AVAudioConverter?,
        to target: AVAudioFormat
    ) -> Data? {
        // Already in the wire format (e.g. some mics expose 16 kHz Int16) —
        // skip the converter entirely.
        if converter == nil || buffer.format == target {
            return pcmData(from: buffer)
        }
        guard let converter else { return pcmData(from: buffer) }

        let ratio = target.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1_024
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else {
            return nil
        }

        var suppliedInput = false
        var conversionError: NSError?
        let status = converter.convert(to: outBuffer, error: &conversionError) { _, inputStatus in
            if suppliedInput {
                inputStatus.pointee = .noDataNow
                return nil
            }
            suppliedInput = true
            inputStatus.pointee = .haveData
            return buffer
        }

        guard status != .error, outBuffer.frameLength > 0 else { return nil }
        return pcmData(from: outBuffer)
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
