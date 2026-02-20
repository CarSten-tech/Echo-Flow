import Foundation
import AppKit
import Shared

/// Detects the currently active application and UI context.
public struct AppContextDetector {
    
    /// Retrieves the current context by querying macOS for the frontmost application.
    public static func getCurrentContext() -> AppContext {
        let defaultContext = AppContext(applicationName: "Unknown")
        
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
              let appName = frontmostApp.localizedName else {
            return defaultContext
        }
        
        AppLog.debug("Detected active application: \(appName)", category: .routing)
        
        return AppContext(applicationName: appName)
    }
}
