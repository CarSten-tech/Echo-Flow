import Foundation
import AVFoundation

/// Manages audio capture for voice dictation using AVAudioEngine.
public final class AudioEngine: ObservableObject {
    private let engine = AVAudioEngine()
    private var inputNode: AVAudioInputNode { engine.inputNode }
    
    @Published public private(set) var isRecording: Bool = false
    @Published public private(set) var audioLevel: Float = 0.0
    
    // Callback to pass captured PCM buffers to STT processor
    public var onBufferReceived: ((AVAudioPCMBuffer) -> Void)?
    
    public init() {}
    
    /// Starts capturing audio from the default microphone.
    public func startRecording() throws {
        guard !isRecording else { return }
        
        let format = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, time in
            guard let self = self else { return }
            
            // Pass the buffer
            self.onBufferReceived?(buffer)
            
            // Calculate a rudimentary RMS level for metering/UI
            self.updateAudioLevel(from: buffer)
        }
        
        engine.prepare()
        try engine.start()
        
        DispatchQueue.main.async {
            self.isRecording = true
        }
    }
    
    /// Stops audio capture.
    public func stopRecording() {
        guard isRecording else { return }
        
        inputNode.removeTap(onBus: 0)
        engine.stop()
        
        DispatchQueue.main.async {
            self.isRecording = false
            self.audioLevel = 0.0
        }
    }
    
    private func updateAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        
        var sumSquares: Float = 0.0
        for i in 0..<frameLength {
            let sample = channelData[i]
            sumSquares += sample * sample
        }
        
        let rms = sqrt(sumSquares / Float(frameLength))
        
        // Convert to a scaled decimal for UI binding
        let level = min(max(rms * 10, 0.0), 1.0)
        
        DispatchQueue.main.async {
            self.audioLevel = level
        }
    }
}
