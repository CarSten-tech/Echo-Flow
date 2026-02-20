import Foundation
import AVFoundation

/// Protocol defining the interface for Speech-to-Text providers.
public protocol STTProvider {
    /// Pushes an audio buffer into the transcriber.
    func pushBuffer(_ buffer: AVAudioPCMBuffer)
    
    /// Starts the STT engine.
    func start() throws
    
    /// Stops the STT engine and returns the final transcription.
    func stop() async throws -> String
    
    /// A stream of partial transcriptions for real-time feedback.
    var transcriptionStream: AsyncStream<String> { get }
}
