import Foundation
import GoogleGenerativeAI

/// Defines structured tools (Function Calling) for the Gemini API.
/// This enforces strict JSON schemas for the model to adhere to when deciding actions.
public struct EchoFlowTools {
    
    /// The primary tool suite provided to the Gemini model to decide
    /// how to route a user's transcribed audio.
    public static let routingTools = Tool(functionDeclarations: [
        processDictationFunction,
        runSystemCommandFunction
    ])
    
    // MARK: - Function Declarations
    
    /// Declares the "Dictation" lane. If the user is just dictating text (e.g., an email body),
    /// Gemini should call this function with the cleaned, punctuated text.
    private static let processDictationFunction = FunctionDeclaration(
        name: "process_dictation",
        description: "Use this function when the user's intent is simply to dictate text. You must correct minor grammar/transcription errors and output the final cleanly formatted text.",
        parameters: [
            "formatted_text": Schema(
                type: .string,
                description: "The fully corrected and punctuated text intended for the dictation."
            )
        ]
    )
    
    /// Declares the "Command" lane. If the user is giving a command to the operating system
    /// (e.g., 'Open Safari', 'Draft an email to Mark'), Gemini should call this function.
    private static let runSystemCommandFunction = FunctionDeclaration(
        name: "run_system_command",
        description: "Use this function when the user intends to execute a command on macOS, control an application, or trigger a workflow. DO NOT use this for standard text dictation.",
        parameters: [
            "action": Schema(
                type: .string,
                description: "The primary action to take, e.g., 'open_app', 'send_email'."
            ),
            "parameters": Schema(
                type: .string, // Using a JSON string since dictionary parameters can be complex for the current SDK wrapper
                description: "A valid JSON string containing the required parameters for the action (e.g., {\"app_name\": \"Safari\"})."
            )
        ]
    )
}
