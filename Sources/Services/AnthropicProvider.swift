import Foundation
import Shared

/// A provider that wraps the Anthropic "Messages API" (Claude).
public final class AnthropicProvider: LLMProviderProtocol {
    
    private let apiKey: String
    private let model: String
    
    private let endpointURL = URL(string: "https://api.anthropic.com/v1/messages")!
    
    public init(apiKey: String, model: String = "claude-3-5-sonnet-20241022") {
        self.apiKey = apiKey
        self.model = model
    }
    
    public func setup() throws {
        guard !apiKey.isEmpty else {
            throw NSError(domain: "AnthropicProvider", code: 1, userInfo: [NSLocalizedDescriptionKey: "Anthropic API Key is missing."])
        }
    }
    
    public func routeIntent(transcription: String, context: AppContext?) async throws -> RouteResult {
        let systemPrompt = """
        You are EchoFlow, a high-performance audio router for macOS.
        Analyze the following transcribed text from the user.
        If the text is regular dictation, respond ONLY with: [DICTATE] followed by the cleaned text.
        If the text is a system command (e.g., open an app, send an email), respond ONLY with: [SYSTEM] followed by a JSON object like {"action":"open_app","parameters":{"name":"Safari"}}.
        DO NOT respond with conversational text.
        """
        
        var userMessage = ""
        if let ctx = context {
            userMessage += "[CONTEXT]\n\(ctx.contextualPromptModifier)\n\n"
        }
        userMessage += "[TRANSCRIPTION]\n\(transcription)"
        
        // Construct the Anthropic JSON Request
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": systemPrompt,
            "messages": [
                [
                    "role": "user",
                    "content": userMessage
                ]
            ],
            "temperature": 0.0
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AnthropicProvider", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URLResponse"])
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown Error"
            AppLog.error("Anthropic API Error (\(httpResponse.statusCode)): \(errorMsg)", category: .routing)
            throw NSError(domain: "AnthropicProvider", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        
        // Parse the Anthropic Response
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        guard let responseDict = json as? [String: Any],
              let contentArray = responseDict["content"] as? [[String: Any]],
              let firstContent = contentArray.first,
              let textResponse = firstContent["text"] as? String else {
            throw NSError(domain: "AnthropicProvider", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to parse Claude JSON response."])
        }
        
        let cleanedResponse = textResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleanedResponse.hasPrefix("[DICTATE]") {
            let dictationString = cleanedResponse.replacingOccurrences(of: "[DICTATE]", with: "").trimmingCharacters(in: .whitespaces)
            return .dictation(dictationString)
            
        } else if cleanedResponse.hasPrefix("[SYSTEM]") {
            let encodedString = cleanedResponse.replacingOccurrences(of: "[SYSTEM]", with: "").trimmingCharacters(in: .whitespaces)
            guard let jsonData = encodedString.data(using: .utf8),
                  let jsonCommand = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any],
                  let action = jsonCommand["action"] as? String else {
                return .unknown
            }
            
            let params = jsonCommand["parameters"] as? [String: String] ?? [:]
            return .command(action: action, parameters: params)
        }
        
        return .unknown
    }
}
