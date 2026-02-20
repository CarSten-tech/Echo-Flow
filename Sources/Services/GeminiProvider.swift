import Foundation
import GoogleGenerativeAI

/// Enterprise-grade provider for the Google Gemini API.
/// Utilizes the official SDK for streaming and function calling support.
public final class GeminiProvider {
    
    /// The initialized model ready for generation.
    public private(set) var model: GenerativeModel?
    private let modelName = "gemini-1.5-pro-latest"
    
    public init() {}
    
    /// Initializes the GenerativeModel instance securely.
    /// This should be called before any generation attempts.
    public func setup() throws {
        // In a real app, this key should never be hardcoded or logged.
        let apiKey = try KeychainService.load(key: "GeminiAPIKey")
        
        // Define Model Configuration
        let config = GenerationConfig(
            temperature: 0.1, // Low temperature for deterministic routing
            topP: 0.8,
            topK: 40
        )
        
        // Enable Function Calling tools
        self.model = GenerativeModel(
            name: modelName,
            apiKey: apiKey,
            generationConfig: config,
            tools: [EchoFlowTools.routingTools]
        )
        
        AppLog.info("GeminiProvider successfully initialized with SDK.", category: .inference)
    }
    
    /// Generates a streaming response from the Gemini API.
    /// - Parameter prompt: The consolidated system instructions + user audio text.
    /// - Returns: An AsyncThrowingStream of generated text chunks.
    public func generateStream(from prompt: String) -> AsyncThrowingStream<String, Error>? {
        guard let model = model else {
            AppLog.error("GeminiProvider: Model not initialized. Did you call setup()?", category: .inference)
            return nil
        }
        
        let responseStream = model.generateContentStream(prompt)
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await chunk in responseStream {
                        if let text = chunk.text {
                            continuation.yield(text)
                        }
                    }
                    continuation.finish()
                } catch {
                    AppLog.error("GeminiProvider Stream Error: \(error.localizedDescription)", category: .inference)
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
