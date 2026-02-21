import Foundation
import Shared
import GoogleGenerativeAI

/// Enterprise-grade provider for the Google Gemini API.
/// Utilizes the official SDK for streaming and function calling support.
public final class GeminiProvider: LLMProviderProtocol {
    
    /// The initialized model ready for generation.
    public private(set) var model: GenerativeModel?
    private let modelName: String
    private var apiKey: String
    
    public init(apiKey: String, modelName: String = "gemini-2.0-flash") {
        self.apiKey = apiKey
        self.modelName = modelName
    }
    
    /// Initializes the GenerativeModel instance securely.
    public func setup() throws {
        guard !apiKey.isEmpty else {
            throw NSError(domain: "GeminiProvider", code: 1, userInfo: [NSLocalizedDescriptionKey: "Gemini API Key is missing."])
        }
        
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
        
        AppLog.info("GeminiProvider successfully initialized.", category: .inference)
    }
    
    public func routeIntent(transcription: String, context: AppContext?) async throws -> RouteResult {
        guard let model = model else {
            throw NSError(domain: "GeminiProvider", code: 2, userInfo: [NSLocalizedDescriptionKey: "Model not initialized."])
        }
        
        var prompt = """
        You are EchoFlow, a high-performance audio router for macOS.
        Analyze the following transcribed text from the user. 
        Your ONLY job is to call either the `process_dictation` tool OR the `run_system_command` tool.
        DO NOT respond with conversational text.
        """
        
        if let ctx = context {
            prompt += "\n\nCONTEXT:\n\(ctx.contextualPromptModifier)"
        }
        
        prompt += "\n\nUser Text: \"\(transcription)\""
        
        AppLog.debug("Requesting generative route from Gemini...", category: .inference)
        let response = try await model.generateContent(prompt)
        
        // Parse Function Calling Array
        if let functionCall = response.functionCalls.first {
            AppLog.debug("Gemini selected Function: \(functionCall.name)", category: .routing)
            
            if functionCall.name == "process_dictation",
               let formattedText = functionCall.args["formatted_text"] as? String {
                
                return .dictation(formattedText)
                
            } else if functionCall.name == "run_system_command",
                      let action = functionCall.args["action"] as? String {
                
                var paramsDict: [String: String] = [:]
                if let paramsStr = functionCall.args["parameters"] as? String,
                   let data = paramsStr.data(using: .utf8),
                   let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                    paramsDict = dict
                }
                
                return .command(action: action, parameters: paramsDict)
            }
        }
        
        if let text = response.text {
            AppLog.warning("Gemini hallucinated a non-tool response. Falling back.", category: .routing)
            return .dictation(text)
        }
        
        throw NSError(domain: "GeminiProvider", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid Gemini Response"])
    }
}
