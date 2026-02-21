import SwiftUI
import Shared

public struct ProviderSettingsView: View {
    @ObservedObject var settings = ModelSettings.shared
    
    @State private var connectionStatus: ConnectionStatus = .idle
    @State private var statusMessage: String = ""
    
    enum ConnectionStatus {
        case idle, testing, success, failure
    }
    
    public init() {}
    
    public var body: some View {
        Form {
            Section(header: Text("AI Provider Selection")) {
                Picker("Provider", selection: $settings.selectedProvider) {
                    ForEach(AIProviderType.allCases) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                .pickerStyle(.radioGroup)
                .onChange(of: settings.selectedProvider) { _ in
                    connectionStatus = .idle
                    statusMessage = ""
                }
                
                Text(providerDescription(for: settings.selectedProvider))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            
            Section(header: Text("Configuration")) {
                switch settings.selectedProvider {
                case .dictationOnly:
                    Label("No configuration needed.", systemImage: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    Text("Speech is transcribed locally via WhisperKit and typed directly — no cloud AI, no API key, fully offline.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                
                case .gemini:
                    SecureField("Gemini API Key", text: $settings.geminiAPIKey)
                        .textFieldStyle(.roundedBorder)
                    Picker("Model", selection: $settings.geminiModel) {
                        ForEach(ModelSettings.availableModels[.gemini] ?? [], id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    Text("Get a Gemini API Key from Google AI Studio.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                case .openAI:
                    SecureField("OpenAI API Key", text: $settings.openAIAPIKey)
                        .textFieldStyle(.roundedBorder)
                    Picker("Model", selection: $settings.openAIModel) {
                        ForEach(ModelSettings.availableModels[.openAI] ?? [], id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    Text("Requires an active OpenAI platform account.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                case .claude:
                    SecureField("Anthropic API Key", text: $settings.claudeAPIKey)
                        .textFieldStyle(.roundedBorder)
                    Picker("Model", selection: $settings.claudeModel) {
                        ForEach(ModelSettings.availableModels[.claude] ?? [], id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    Text("Requires an active Anthropic Console account.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                case .mistral:
                    SecureField("Mistral API Key", text: $settings.mistralAPIKey)
                        .textFieldStyle(.roundedBorder)
                    Picker("Model", selection: $settings.mistralModel) {
                        ForEach(ModelSettings.availableModels[.mistral] ?? [], id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    Text("Requires an active Mistral AI platform account.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                case .deepseek:
                    SecureField("DeepSeek API Key", text: $settings.deepseekAPIKey)
                        .textFieldStyle(.roundedBorder)
                    Picker("Model", selection: $settings.deepseekModel) {
                        ForEach(ModelSettings.availableModels[.deepseek] ?? [], id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    Text("Requires an active DeepSeek platform account.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                case .localCustom:
                    TextField("Local/Custom API Endpoint", text: $settings.localAPIEndpoint)
                        .textFieldStyle(.roundedBorder)
                    TextField("Model Name (e.g., llama3)", text: $settings.localModelName)
                        .textFieldStyle(.roundedBorder)
                    
                    Text("Ensure your local server (e.g., Ollama or LMStudio) is running.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Connection Test Section
            Section {
                HStack {
                    Button(action: testConnection) {
                        HStack(spacing: 6) {
                            if connectionStatus == .testing {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(connectionStatus == .testing ? "Testing..." : "Test Connection")
                        }
                    }
                    .disabled(currentAPIKey.isEmpty || connectionStatus == .testing)
                    
                    Spacer()
                    
                    // Status Badge
                    if connectionStatus == .success {
                        Label("Connected", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.callout.bold())
                    } else if connectionStatus == .failure {
                        Label("Failed", systemImage: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.callout.bold())
                    }
                }
                
                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundColor(connectionStatus == .success ? .green : .red)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(20)
        .frame(width: 480, height: 480)
    }
    
    /// The currently active API key based on the selected provider.
    private var currentAPIKey: String {
        switch settings.selectedProvider {
        case .dictationOnly: return "local"
        case .gemini: return settings.geminiAPIKey
        case .openAI: return settings.openAIAPIKey
        case .claude: return settings.claudeAPIKey
        case .mistral: return settings.mistralAPIKey
        case .deepseek: return settings.deepseekAPIKey
        case .localCustom: return settings.localAPIEndpoint
        }
    }
    
    /// Sends a lightweight test request to the selected provider's API.
    private func testConnection() {
        connectionStatus = .testing
        statusMessage = ""
        
        Task {
            do {
                let (url, headers, body) = try buildTestRequest()
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.timeoutInterval = 10
                for (key, value) in headers {
                    request.setValue(value, forHTTPHeaderField: key)
                }
                request.httpBody = body
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                await MainActor.run {
                    if (200...299).contains(httpResponse.statusCode) {
                        connectionStatus = .success
                        statusMessage = "✅ API key is valid. Provider connected successfully."
                    } else {
                        connectionStatus = .failure
                        let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                        statusMessage = "HTTP \(httpResponse.statusCode): \(errorBody.prefix(120))"
                    }
                }
            } catch {
                await MainActor.run {
                    connectionStatus = .failure
                    statusMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// Builds a minimal test request for each provider.
    private func buildTestRequest() throws -> (URL, [(String, String)], Data) {
        switch settings.selectedProvider {
        case .dictationOnly:
            throw NSError(domain: "ProviderSettings", code: 0, userInfo: [NSLocalizedDescriptionKey: "No connection test needed in Dictation Only mode."])
        case .gemini:
            let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(settings.geminiModel):generateContent?key=\(settings.geminiAPIKey)")!
            let body = try JSONSerialization.data(withJSONObject: [
                "contents": [["parts": [["text": "Reply with OK"]]]]
            ])
            return (url, [("Content-Type", "application/json")], body)
            
        case .openAI:
            let url = URL(string: "https://api.openai.com/v1/chat/completions")!
            let body = try JSONSerialization.data(withJSONObject: [
                "model": "gpt-4o-mini",
                "messages": [["role": "user", "content": "Reply with OK"]],
                "max_tokens": 5
            ])
            return (url, [
                ("Content-Type", "application/json"),
                ("Authorization", "Bearer \(settings.openAIAPIKey)")
            ], body)
            
        case .claude:
            let url = URL(string: "https://api.anthropic.com/v1/messages")!
            let body = try JSONSerialization.data(withJSONObject: [
                "model": "claude-3-5-sonnet-20241022",
                "max_tokens": 5,
                "messages": [["role": "user", "content": "Reply with OK"]]
            ])
            return (url, [
                ("Content-Type", "application/json"),
                ("x-api-key", settings.claudeAPIKey),
                ("anthropic-version", "2023-06-01")
            ], body)
            
        case .mistral:
            let url = URL(string: "https://api.mistral.ai/v1/chat/completions")!
            let body = try JSONSerialization.data(withJSONObject: [
                "model": "mistral-small-latest",
                "messages": [["role": "user", "content": "Reply with OK"]],
                "max_tokens": 5
            ])
            return (url, [
                ("Content-Type", "application/json"),
                ("Authorization", "Bearer \(settings.mistralAPIKey)")
            ], body)
            
        case .deepseek:
            let url = URL(string: "https://api.deepseek.com/v1/chat/completions")!
            let body = try JSONSerialization.data(withJSONObject: [
                "model": "deepseek-chat",
                "messages": [["role": "user", "content": "Reply with OK"]],
                "max_tokens": 5
            ])
            return (url, [
                ("Content-Type", "application/json"),
                ("Authorization", "Bearer \(settings.deepseekAPIKey)")
            ], body)
            
        case .localCustom:
            let endpoint = settings.localAPIEndpoint.isEmpty ? "http://localhost:11434" : settings.localAPIEndpoint
            let url = URL(string: "\(endpoint)/v1/chat/completions")!
            let body = try JSONSerialization.data(withJSONObject: [
                "model": settings.localModelName.isEmpty ? "llama3" : settings.localModelName,
                "messages": [["role": "user", "content": "Reply with OK"]],
                "max_tokens": 5
            ])
            return (url, [("Content-Type", "application/json")], body)
        }
    }
    
    private func providerDescription(for type: AIProviderType) -> String {
        switch type {
        case .dictationOnly: return "Pure local dictation. No AI routing, no cloud, fully offline."
        case .gemini: return "Google's fast and highly capable Gemini 1.5 model. (Recommended)"
        case .openAI: return "OpenAI's GPT-4o models for maximum reliability."
        case .claude: return "Anthropic's powerful Claude 3.5 Sonnet model."
        case .mistral: return "Mistral's open-weight language models via their API."
        case .deepseek: return "DeepSeek V3 for fast and affordable intelligence."
        case .localCustom: return "Bring your own local offline LLM (Ollama) or custom proxy."
        }
    }
}
