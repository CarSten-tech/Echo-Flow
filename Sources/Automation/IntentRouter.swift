import Foundation
import Shared
import GoogleGenerativeAI

/// Automates the decision process to determine if speech is dictation or a command
/// using configurable AI models (BYOM).
public final class IntentRouter: ObservableObject {
    
    /// The offline inference fallback used when APIs are unreachable.
    private let localFallback = MLXLocalInferenceService()
    
    public init() {}
    
    /// Instantiates the active Provider based on user settings.
    private func getActiveProvider() throws -> LLMProviderProtocol {
        let settings = ModelSettings.shared
        
        switch settings.selectedProvider {
        case .dictationOnly:
            // This should never be called in dictation-only mode
            throw NSError(domain: "IntentRouter", code: 0, userInfo: [NSLocalizedDescriptionKey: "No LLM provider in Dictation Only mode."])
        case .gemini:
            return GeminiProvider(apiKey: settings.geminiAPIKey, modelName: settings.geminiModel)
        case .openAI:
            return OpenAICompatibleProvider(
                baseURL: "https://api.openai.com/v1/chat/completions",
                apiKey: settings.openAIAPIKey,
                modelName: settings.openAIModel
            )
        case .claude:
            return AnthropicProvider(apiKey: settings.claudeAPIKey, model: settings.claudeModel)
        case .mistral:
            return OpenAICompatibleProvider(
                baseURL: "https://api.mistral.ai/v1/chat/completions",
                apiKey: settings.mistralAPIKey,
                modelName: settings.mistralModel
            )
        case .deepseek:
            return OpenAICompatibleProvider(
                baseURL: "https://api.deepseek.com/chat/completions",
                apiKey: settings.deepseekAPIKey,
                modelName: settings.deepseekModel
            )
        case .localCustom:
            return OpenAICompatibleProvider(
                baseURL: settings.localAPIEndpoint,
                apiKey: "dummy-key",
                modelName: settings.localModelName
            )
        }
    }
    
    /// Evaluates the user's spoken transcription against the active system context.
    public func route(transcription: String, context: AppContext? = nil) async -> RouteResult {
        // Dictation-Only Mode: Skip LLM entirely, return raw transcription
        if ModelSettings.shared.selectedProvider == .dictationOnly {
            AppLog.info("Dictation-Only mode: bypassing LLM routing.", category: .routing)
            return .dictation(transcription)
        }
        
        do {
            let provider = try getActiveProvider()
            try provider.setup()
            
            AppLog.debug("Requesting generative route from \(ModelSettings.shared.selectedProvider.rawValue)...", category: .inference)
            return try await provider.routeIntent(transcription: transcription, context: context)
            
        } catch {
            AppLog.warning("Primary Provider failed or not configured: \(error.localizedDescription)", category: .routing)
            AppLog.info("Triggering Local MLX/CoreML Fallback...", category: .inference)
            return (try? await localFallback.evaluateLocally(text: transcription, context: context)) ?? .dictation(transcription)
        }
    }
}

