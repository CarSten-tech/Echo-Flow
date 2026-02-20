import Foundation

/// Handles formatting, translation, and intent analysis using the Gemini API.
public final class GeminiStreamer: ObservableObject {
    
    private let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent"
    
    public init() {}
    
    /// Analyzes raw transcribed text to determine if it is a Dictation or Command,
    /// and formats it accordingly.
    public func analyzeIntent(from rawText: String) async throws -> (intent: String, formattedText: String) {
        let apiKey = try KeychainService.load(key: "GeminiAPIKey")
        
        guard let url = URL(string: "\(endpoint)?key=\(apiKey)") else {
            throw URLError(.badURL)
        }
        
        // This is a simplified JSON payload for the Gemini API.
        let prompt = "Analyze the text: '\(rawText)'. If it is a command like 'Send email to X', reply with 'COMMAND|Send email to X'. Otherwise, format it nicely and reply with 'DICTATION|Formatted Text'."
        let requestBody: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        // Mock parsing logic
        // In reality, we'd decode the `GenerateContentResponse` JSON structure.
        return parseResponse(data)
    }
    
    private func parseResponse(_ data: Data) -> (intent: String, formattedText: String) {
        // Simulated parsing: Assume all input is COMMAND for the scaffold
        return ("COMMAND", "Send an email to mark")
    }
}
