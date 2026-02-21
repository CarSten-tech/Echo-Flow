import Foundation
import AVFoundation
import Shared

/// A real implementation for a Whisper-based STT Provider using WhisperKitService via XPC.
public final class WhisperService: STTProvider, ObservableObject {
    
    @Published public private(set) var currentTranscription: String = ""
    private var connection: NSXPCConnection?
    private var engine: EngineProtocol?
    
    // An internal continuation to yield partial transcriptions asynchronously
    private var streamContinuation: AsyncStream<String>.Continuation?
    
    public lazy var transcriptionStream: AsyncStream<String> = {
        AsyncStream { continuation in
            self.streamContinuation = continuation
        }
    }()
    
    public init() {
        setupXPC()
    }
    
    private func setupXPC() {
        // Connect to the XPC Engine target
        connection = NSXPCConnection(serviceName: "com.carstenrheidt.EchoFlowEngine")
        connection?.remoteObjectInterface = NSXPCInterface(with: EngineProtocol.self)
        
        connection?.interruptionHandler = {
            AppLog.warning("XPC Connection to Whisper Engine interrupted.", category: .audio)
            // Interruptions usually self-recover, but we log to track stability.
        }
        
        connection?.invalidationHandler = { [weak self] in
            AppLog.error("XPC Connection to Whisper Engine invalidated. Attempting recovery...", category: .audio)
            self?.connection = nil
            self?.engine = nil
            
            // Wait briefly before attempting to reconnect to avoid spam-looping if the daemon is totally dead
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self?.setupXPC()
            }
        }
        
        connection?.resume()
        
        // Grab the proxy object
        engine = connection?.remoteObjectProxyWithErrorHandler { [weak self] error in
            AppLog.error("Failed to get XPC proxy: \(error.localizedDescription)", category: .audio)
            self?.engine = nil
        } as? EngineProtocol
    }
    
    public func pushBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let engine = engine else { return }
        
        // Convert AVAudioPCMBuffer (assuming Float32) to Data
        guard let channelData = buffer.floatChannelData else { return }
        let channelDataValue = channelData.pointee
        let channelDataArray = Array(UnsafeBufferPointer(start: channelDataValue, count: Int(buffer.frameLength)))
        
        let audioData = channelDataArray.withUnsafeBufferPointer { Data(buffer: $0) }
        
        engine.processAudioChunk(audioData) { [weak self] text, error in
            guard let self = self, let text = text, error == nil else {
                if let error = error {
                    AppLog.error("WhisperKit inference error: \(error.localizedDescription)", category: .audio)
                }
                return
            }
            Task { @MainActor in
                self.currentTranscription = text
            }
            self.streamContinuation?.yield(text)
        }
    }
    
    public func start() throws {
        // Reset state and initialize Whisper model
        DispatchQueue.main.async {
            self.currentTranscription = ""
        }
        streamContinuation?.yield("Initializing engine...")
        
        guard let engine = engine else {
            AppLog.error("Engine not available. Is XPC working?", category: .audio)
            return
        }
        
        engine.initializeEngine(modelName: "openai_whisper-base", initialPrompt: VocabularyManager().getPromptString()) { success, message in
            if success {
                AppLog.info("WhisperKit Engine initialized: \(message ?? "")", category: .audio)
                self.streamContinuation?.yield("Listening...")
            } else {
                AppLog.error("Failed to initialize WhisperKit: \(message ?? "")", category: .audio)
                self.streamContinuation?.yield("Error initializing STT")
            }
        }
    }
    
    public func stop() async throws -> String {
        let finalOutput = currentTranscription
        
        // Optional: Call finalizeTranscription if the engine needs to flush state
        engine?.finalizeTranscription { _, _ in }
        
        // Yield final output just in case
        streamContinuation?.yield(finalOutput)
        
        return finalOutput
    }
    
    deinit {
        connection?.invalidate()
    }
}
