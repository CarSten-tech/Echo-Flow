import Foundation
import SwiftUI

/// Defines the supported AI Providers within EchoFlow.
public enum AIProviderType: String, CaseIterable, Identifiable, Codable {
    case dictationOnly = "None (Dictation Only)"
    case gemini = "Google Gemini"
    case openAI = "OpenAI (GPT)"
    case claude = "Anthropic Claude"
    case mistral = "Mistral AI"
    case deepseek = "DeepSeek"
    case localCustom = "Local API (Ollama/LMStudio)"
    
    public var id: String { self.rawValue }
}

/// Recording activation mode.
public enum RecordingMode: String, CaseIterable, Identifiable {
    case pushToTalk = "Hold to Talk"
    case toggleToTalk = "Press to Start/Stop"
    
    public var id: String { self.rawValue }
}

/// Stores the user's configuration for the BYOM (Bring Your Own Model) architecture.
public final class ModelSettings: ObservableObject {
    public static let shared = ModelSettings()
    
    @AppStorage("recordingMode") public var recordingMode: RecordingMode = .pushToTalk
    @AppStorage("selectedAIProvider") public var selectedProvider: AIProviderType = .dictationOnly
    @AppStorage("audioGain") public var audioGain: Double = 1.0
    
    // --- Specific API Keys ---
    // In a highly secure enterprise app, we would store these in Keychain.
    // For this prototype/MVP configuration, AppStorage works.
    
    @AppStorage("geminiAPIKey") public var geminiAPIKey: String = ""
    @AppStorage("openAIAPIKey") public var openAIAPIKey: String = ""
    @AppStorage("claudeAPIKey") public var claudeAPIKey: String = ""
    @AppStorage("mistralAPIKey") public var mistralAPIKey: String = ""
    @AppStorage("deepseekAPIKey") public var deepseekAPIKey: String = ""
    
    // --- Selected Models per Provider ---
    
    @AppStorage("geminiModel") public var geminiModel: String = "gemini-2.0-flash"
    @AppStorage("openAIModel") public var openAIModel: String = "gpt-4o"
    @AppStorage("claudeModel") public var claudeModel: String = "claude-3-5-sonnet-20241022"
    @AppStorage("mistralModel") public var mistralModel: String = "mistral-large-latest"
    @AppStorage("deepseekModel") public var deepseekModel: String = "deepseek-chat"
    
    // --- Local API ---
    
    @AppStorage("localAPIEndpoint") public var localAPIEndpoint: String = "http://localhost:11434/v1/chat/completions"
    @AppStorage("localModelName") public var localModelName: String = "llama3"
    
    /// Available models per provider.
    public static let availableModels: [AIProviderType: [String]] = [
        .gemini: [
            "gemini-2.0-flash",
            "gemini-2.0-flash-lite",
            "gemini-1.5-flash",
            "gemini-1.5-pro"
        ],
        .openAI: [
            "gpt-4o",
            "gpt-4o-mini",
            "gpt-4-turbo",
            "gpt-3.5-turbo"
        ],
        .claude: [
            "claude-3-5-sonnet-20241022",
            "claude-3-5-haiku-20241022",
            "claude-3-opus-20240229"
        ],
        .mistral: [
            "mistral-large-latest",
            "mistral-small-latest",
            "open-mistral-nemo",
            "codestral-latest"
        ],
        .deepseek: [
            "deepseek-chat",
            "deepseek-reasoner"
        ]
    ]
    
    private init() {}
    
    /// Helper to determine if the selected provider is ready to be used.
    public var isConfigured: Bool {
        switch selectedProvider {
        case .dictationOnly:
            return true // No configuration needed
        case .gemini:
            return !geminiAPIKey.isEmpty
        case .openAI:
            return !openAIAPIKey.isEmpty
        case .claude:
            return !claudeAPIKey.isEmpty
        case .mistral:
            return !mistralAPIKey.isEmpty
        case .deepseek:
            return !deepseekAPIKey.isEmpty
        case .localCustom:
            return !localAPIEndpoint.isEmpty && !localModelName.isEmpty
        }
    }
}
