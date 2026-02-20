import Foundation

// Moving RouteResult to Shared so it's globally accessible and doesn't clutter IntentRouter.
public enum RouteResult: Equatable {
    case dictation(String)
    case command(action: String, parameters: [String: String])
    case unknown
}
