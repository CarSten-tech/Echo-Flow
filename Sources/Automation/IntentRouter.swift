import Foundation

/// Defines the outcome of the semantic routing
public enum RouteResult {
    case dictation(String)
    case command(action: String, parameters: [String: String])
    case unknown
}

/// Automates the decision process to determine if speech is dictation or a command.
public final class IntentRouter: ObservableObject {
    
    // We would inject GeminiStreamer or use it natively
    private let textAnalyzer = GeminiStreamer()
    
    public init() {}
    
    /// Routes the incoming transcription string to the proper output lane.
    public func route(transcription: String) async -> RouteResult {
        do {
            let (intent, formattedText) = try await textAnalyzer.analyzeIntent(from: transcription)
            
            if intent == "COMMAND" {
                // E.g. formattedText might be "Send an email to mark"
                // Extract action and parameters here.
                return .command(action: "send_email", parameters: ["recipient": "mark", "body": formattedText])
            } else {
                return .dictation(formattedText)
            }
        } catch {
            print("Routing error: \(error)")
            // Fallback to strict dictation
            return .dictation(transcription)
        }
    }
}
