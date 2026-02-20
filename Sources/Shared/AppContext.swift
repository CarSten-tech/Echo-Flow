import Foundation

/// Represents the detected context of the user's current environment.
public struct AppContext {
    /// The name of the frontmost application (e.g., "Xcode", "Mail", "Slack").
    public let applicationName: String
    
    public init(applicationName: String) {
        self.applicationName = applicationName
    }
    
    /// Provides an AI prompt instruction tailored to the active application.
    public var contextualPromptModifier: String {
        switch applicationName.lowercased() {
        case "xcode", "cursor", "visual studio code":
            return "The user is currently dictating into a code editor (\(applicationName)). Prefer standard programming naming conventions (e.g. camelCase for Swift, snake_case for Python) and format technical terms as code if appropriate."
        case "mail", "outlook", "spark":
            return "The user is currently dictating an email (\(applicationName)). Maintain a professional, polite, and cohesive formal tone."
        case "messages", "slack", "discord":
            return "The user is dictating a quick chat message. Keep formatting natural, loose, and do not over-punctuate informal speech."
        case "terminal", "iterm2":
            return "The user is dictating into a terminal. Favour concise, lower-case UNIX-style command outputs without trailing periods where applicable."
        default:
            return "Format the text cleanly for general writing."
        }
    }
}
