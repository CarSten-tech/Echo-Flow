import Foundation
import Shared

/// The base protocol that all LLM Providers (Cloud or Local) must implement
/// to be compatible with EchoFlow's Intent Routing engine.
public protocol LLMProviderProtocol {
    /// Attempts to configure and validate the provider (e.g., checking API keys or local server health).
    func setup() throws
    
    /// Evaluates the user's spoken transcription against the active system context.
    ///
    /// - Parameters:
    ///   - transcription: The raw spoken text transcribed by WhisperKit.
    ///   - context: Active application context.
    /// - Returns: A standard RouteResult indicating if it's Dictation or a Command.
    func routeIntent(transcription: String, context: AppContext?) async throws -> RouteResult
}
