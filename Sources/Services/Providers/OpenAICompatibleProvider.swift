import Foundation
import Shared

/// A universal LLM Provider that speaks the OpenAI Chat Completions API format.
/// This single provider can communicate with actual OpenAI (GPT-4o), Anthropic (via proxy),
/// or completely local instances like Ollama, LMStudio, and Llama.cpp.
public final class OpenAICompatibleProvider: LLMProviderProtocol {
    
    private var baseURL: URL!
    private var apiKey: String
    private var modelName: String
    
    public init(baseURL: String, apiKey: String, modelName: String) {
        self.baseURL = URL(string: baseURL) ?? URL(string: "https://api.openai.com/v1/chat/completions")!
        self.apiKey = apiKey
        self.modelName = modelName
    }
    
    public func setup() throws {
        // Basic validation
        guard baseURL.scheme == "http" || baseURL.scheme == "https" else {
            throw NSError(domain: "OpenAICompatibleProvider", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid Base URL"])
        }
        
        // If we are hitting standard OpenAI, we absolutely need an API key. 
        // Localhost servers (like LMStudio) usually ignore the Bearer token.
        if baseURL.host?.contains("api.openai.com") == true && apiKey.isEmpty {
            throw NSError(domain: "OpenAICompatibleProvider", code: 2, userInfo: [NSLocalizedDescriptionKey: "OpenAI API Key is required."])
        }
    }
    
    public func routeIntent(transcription: String, context: AppContext?) async throws -> RouteResult {
        // We use native URLSession to interact with the API to avoid importing massive custom SDKs
        // just for standard JSON HTTP routing.
        
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        // Define the Tools (Function Calling) exactly as we did for Gemini
        let tools: [[String: Any]] = [
            [
                "type": "function",
                "function": [
                    "name": "process_dictation",
                    "description": "Injects the dictated text directly into the active text field. Correct spelling and grammar gracefully.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "formatted_text": [
                                "type": "string",
                                "description": "The exact, cleaned text to paste into the document. Do not wrap in quotes."
                            ]
                        ],
                        "required": ["formatted_text"]
                    ]
                ]
            ],
            [
                "type": "function",
                "function": [
                    "name": "run_system_command",
                    "description": "Executes a system-level command on macOS (e.g. open an app, send an email, create a reminder). Do not use this for plain typing.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "action": [
                                "type": "string",
                                "description": "The action identifier, e.g., 'open_app', 'send_email'."
                            ],
                            "parameters": [
                                "type": "string",
                                "description": "A JSON-encoded string dictionary containing specific parameters for the chosen action. Example: '{\"app_name\": \"Safari\"}'"
                            ]
                        ],
                        "required": ["action", "parameters"]
                    ]
                ]
            ]
        ]
        
        var systemMessage = """
        You are EchoFlow, a high-performance audio router for macOS.
        Analyze the following transcribed text from the user. 
        Your ONLY job is to call either the `process_dictation` tool OR the `run_system_command` tool.
        DO NOT respond with conversational text.
        """
        
        if let ctx = context {
            systemMessage += "\n\nCONTEXT:\n\(ctx.contextualPromptModifier)"
        }
        
        let payload: [String: Any] = [
            "model": modelName,
            "messages": [
                ["role": "system", "content": systemMessage],
                ["role": "user", "content": transcription]
            ],
            "tools": tools,
            "tool_choice": "auto",
            "temperature": 0.0 // Routing needs to be extremely deterministic
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        
        AppLog.debug("Requesting generative route from \(baseURL.absoluteString)...", category: .inference)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "OpenAICompatibleProvider", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP Response"])
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown Error"
            AppLog.error("API returned \(httpResponse.statusCode): \(errorText)", category: .routing)
            throw NSError(domain: "OpenAICompatibleProvider", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])
        }
        
        // Parse the OpenAI API Response
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any] {
            
            // Check for Tool Calls First
            if let toolCalls = message["tool_calls"] as? [[String: Any]],
               let firstTool = toolCalls.first,
               let function = firstTool["function"] as? [String: Any],
               let functionName = function["name"] as? String,
               let rawArgsStr = function["arguments"] as? String,
               let argsData = rawArgsStr.data(using: .utf8),
               let args = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any] {
                
                AppLog.debug("API selected Function: \(functionName)", category: .routing)
                
                if functionName == "process_dictation", let formattedText = args["formatted_text"] as? String {
                    return .dictation(formattedText)
                } else if functionName == "run_system_command",
                          let action = args["action"] as? String {
                    var paramsDict: [String: String] = [:]
                    if let paramsStr = args["parameters"] as? String,
                       let pData = paramsStr.data(using: .utf8),
                       let dict = try? JSONSerialization.jsonObject(with: pData) as? [String: String] {
                        paramsDict = dict
                    }
                    return .command(action: action, parameters: paramsDict)
                }
            }
            
            // Fallback: If no tools were called, check if there is standard text
            if let textContent = message["content"] as? String, !textContent.isEmpty {
                AppLog.warning("API hallucinated a non-tool response. Falling back.", category: .routing)
                return .dictation(textContent)
            }
        }
        
        AppLog.error("API Response did not match the expected OpenAI JSON format.", category: .routing)
        throw NSError(domain: "OpenAICompatibleProvider", code: 4, userInfo: [NSLocalizedDescriptionKey: "Parse Error"])
    }
}
