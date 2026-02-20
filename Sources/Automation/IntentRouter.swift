import Foundation
import Shared
import GoogleGenerativeAI

/// Automates the decision process to determine if speech is dictation or a command
/// using Gemini Function Calling.
///
/// `IntentRouter` processes raw transcribed text and evaluates it contextually.
/// It decides between injecting text directly (`.dictation`) or generating an
/// actionable payload (`.command`) via the `WorkflowHandler`.
public final class IntentRouter: ObservableObject {
    
    // We would inject GeminiProvider via DI in a real app
    private let textAnalyzer = GeminiProvider()
    private let localFallback = CoreMLLocalInferenceService()
    
    // Fallback if initialization fails
    private var isSetup = false
    
    public init() {
        do {
            try textAnalyzer.setup()
            isSetup = true
        } catch {
            AppLog.error("IntentRouter failed to setup GeminiProvider: \(error)", category: .routing)
        }
    }
    
    /// Evaluates the user's spoken transcription against the active system context.
    ///
    /// - Parameters:
    ///   - transcription: The raw spoken text transcribed by WhisperKit.
    ///   - context: The current active `AppContext` (e.g., active application name) used to tailor the LLM prompt. Defaults to `nil`.
    /// - Returns: A `RouteResult` indicating whether the text should be typed or executed as an AppleScript command.
    public func route(transcription: String, context: AppContext? = nil) async -> RouteResult {
        guard isSetup else {
            AppLog.warning("GeminiProvider unavailable. Falling back to Local Inference.", category: .routing)
            return (try? await localFallback.evaluateLocally(text: transcription, context: context)) ?? .dictation(transcription)
        }
        
        // System Prompt to force the LLM into the tool-calling persona
        var prompt = """
        You are EchoFlow, a high-performance audio router for macOS.
        Analyze the following transcribed text from the user. 
        Your ONLY job is to call either the `process_dictation` tool OR the `run_system_command` tool.
        DO NOT respond with conversational text.
        """
        
        if let ctx = context {
            prompt += "\n\nCONTEXT:\n\(ctx.contextualPromptModifier)"
        }
        
        prompt += """
        
        User Text: "\(transcription)"
        """
        
        do {
            // For routing, we don't necessarily need streaming since we need the tool call payload,
            // but we use the standardized generation method.
            guard let model = textAnalyzer.model else { return .dictation(transcription) }
            
            AppLog.debug("Requesting generative route from Gemini...", category: .inference)
            let response = try await model.generateContent(prompt)
            
            // Check if the model decided to call a function
            if let functionCall = response.functionCalls.first {
                AppLog.debug("Gemini selected Function: \(functionCall.name)", category: .routing)
                
                if functionCall.name == "process_dictation",
                   let args = functionCall.args as? [String: Any],
                   let formattedText = args["formatted_text"] as? String {
                    
                    return .dictation(formattedText)
                    
                } else if functionCall.name == "run_system_command",
                          let args = functionCall.args as? [String: Any],
                          let action = args["action"] as? String {
                    
                    var paramsDict: [String: String] = [:]
                    if let paramsStr = args["parameters"] as? String,
                       let data = paramsStr.data(using: String.Encoding.utf8),
                       let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                        paramsDict = dict
                    }
                    
                    return .command(action: action, parameters: paramsDict)
                }
            }
            
            // If the model failed to follow instructions and returned raw text
            if let text = response.text {
                AppLog.warning("Gemini hallucinated a non-tool response. Falling back.", category: .routing)
                return .dictation(text)
            }
            
        } catch {
            AppLog.error("Routing error from GeminiProvider: \(error.localizedDescription)", category: .routing)
            return (try? await localFallback.evaluateLocally(text: transcription, context: context)) ?? .dictation(transcription)
        }
        
        return .dictation(transcription)
    }
}

