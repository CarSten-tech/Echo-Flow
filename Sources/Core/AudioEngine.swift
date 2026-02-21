import Foundation
import AVFoundation

/// Manages audio capture for voice dictation using AVAudioEngine.
public final class AudioEngine: ObservableObject {

    /// Indicates whether the audio engine is actively tapping the microphone.
    @Published public private(set) var isRecording: Bool = false

    /// The current normalized audio volume level (0.0 to 1.0) used for UI metering.
    @Published public private(set) var audioLevel: Float = 0.0

    /// A closure invoked on a background thread every time a new PCM buffer is available.
    public var onBufferReceived: ((AVAudioPCMBuffer) -> Void)?

    // MARK: - Private

    // The engine is created fresh each session so that macOS fully releases
    // the audio hardware (format, sample-rate, exclusive access) when we stop.
    // Reusing a single engine instance is the root cause of post-session audio
    // quality degradation reported by the user.
    private var engine: AVAudioEngine?

    /// Initializes the AudioEngine.
    public init() {}

    // MARK: - Public API

    /// Starts capturing audio from the default microphone.
    public func startRecording() throws {
        guard !isRecording else { return }

        // ENTERPRISE SECURITY: Block audio recording if password field is focused
        try PrivacyShield.assertSafeInputEnvironment()

        // Always create a fresh engine instance to guarantee a clean audio session.
        let freshEngine = AVAudioEngine()
        self.engine = freshEngine

        let inputNode = freshEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        AppLog.info("Starting AudioEngine recording. Format: \(format)", category: .audio)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            guard let self = self else { return }
            self.onBufferReceived?(buffer)
            self.updateAudioLevel(from: buffer)
        }

        freshEngine.prepare()
        try freshEngine.start()

        DispatchQueue.main.async {
            self.isRecording = true
        }
    }

    /// Stops audio capture and fully tears down the engine, returning the
    /// audio hardware to the system so other apps are unaffected.
    public func stopRecording() {
        guard isRecording else { return }
        AppLog.info("Stopping AudioEngine recording.", category: .audio)

        tearDownEngine()

        DispatchQueue.main.async {
            self.isRecording = false
            self.audioLevel = 0.0
        }
    }

    // MARK: - Private helpers

    /// Removes the tap, stops, and nils the engine so macOS returns the
    /// audio hardware to the system immediately.
    private func tearDownEngine() {
        guard let engine = engine else { return }

        // Remove tap before stopping to avoid AVAudioEngine assertion failures.
        let inputNode = engine.inputNode
        inputNode.removeTap(onBus: 0)

        engine.stop()

        // Nil out the reference – ARC will deallocate the engine, which releases
        // the exclusive audio session lock and restores normal system audio routing.
        self.engine = nil
    }

    /// Calculates the Root Mean Square (RMS) of the incoming audio buffer.
    private func updateAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)

        var sumSquares: Float = 0.0
        for i in 0..<frameLength {
            let sample = channelData[i]
            sumSquares += sample * sample
        }

        let rms = sqrt(sumSquares / Float(frameLength))

        // Increased base sensitivity + user-defined gain
        let gain = Float(ModelSettings.shared.audioGain)
        let level = min(max(rms * 25 * gain, 0.0), 1.0)

        DispatchQueue.main.async {
            self.audioLevel = level
        }
    }
}
