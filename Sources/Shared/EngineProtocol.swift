import Foundation
import IOSurface

/// Defines the communication protocol between the Main App and the XPC Engine.
@objc public protocol EngineProtocol {
    
    /// Initializes the engine, specifically loading the Whisper ML Model.
    /// - Parameters:
    ///   - modelName: The name of the CoreML model to load.
    ///   - reply: Callback indicating success or failure message.
    func initializeEngine(modelName: String, reply: @escaping (Bool, String?) -> Void)
    
    /// Pushes a chunk of audio data to the engine for processing.
    /// - Parameters:
    ///   - audioData: Raw float channel data encapsulated in `Data`.
    ///   - reply: Callback returning the transcribed string (partial or final).
    func processAudioChunk(_ audioData: Data, reply: @escaping (String?, Error?) -> Void)
    
    /// Elite Optimization: Pushes audio data via zero-copy memory mapping.
    /// - Parameters:
    ///   - surface: An IOSurface containing the raw float channel data.
    ///   - reply: Callback returning the transcribed string (partial or final).
    func processAudioSurface(_ surface: IOSurface, reply: @escaping (String?, Error?) -> Void)
    
    /// Finalizes the current audio stream and returns the complete transcription.
    /// - Parameter reply: Callback containing the full string.
    func finalizeTranscription(reply: @escaping (String?, Error?) -> Void)
}
