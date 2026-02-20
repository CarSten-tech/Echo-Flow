import Foundation
import IOSurface
import WhisperKit
import Shared

/// XPC Service implementation running WhisperKit for local text inference.
@objc public class WhisperKitService: NSObject, EngineProtocol {
    
    private var whisperKit: WhisperKit?
    private var isInitialized = false
    
    public override init() {
        super.init()
    }
    
    public func initializeEngine(modelName: String, reply: @escaping (Bool, String?) -> Void) {
        guard !isInitialized else {
            reply(true, "Already initialized")
            return
        }
        
        Task {
            do {
                // WhisperKit initialization downloads/loads the CoreML model.
                // "openai_whisper-base" or "openai_whisper-small" are typical.
                self.whisperKit = try await WhisperKit(model: modelName)
                self.isInitialized = true
                reply(true, "Engine initialized with model: \(modelName)")
            } catch {
                reply(false, "Failed to initialize WhisperKit: \(error.localizedDescription)")
            }
        }
    }
    
    public func processAudioChunk(_ audioData: Data, reply: @escaping (String?, Error?) -> Void) {
        guard isInitialized, let whisperKit = whisperKit else {
            reply(nil, nil) // or custom error
            return
        }
        
        // Convert raw Data (bytes) back into [Float]
        let floatArray = audioData.withUnsafeBytes {
            Array($0.bindMemory(to: Float.self))
        }
        
        Task {
            do {
                let transcription = try await whisperKit.transcribe(audioArray: floatArray)
                let text = transcription.first?.text
                reply(text, nil)
            } catch {
                reply(nil, error)
            }
        }
    }
    
    public func processAudioSurface(_ surface: IOSurface, reply: @escaping (String?, Error?) -> Void) {
        print("[WhisperKitService] Received zero-copy IOSurface for ultra-low latency inference.")
        reply("simulated surface transcription", nil)
    }
    
    public func finalizeTranscription(reply: @escaping (String?, Error?) -> Void) {
        // In a real streaming scenario, this would flush the remaining buffers and close the stream.
        // For now, we simply act as a pass-through.
        reply(nil, nil)
    }
}
