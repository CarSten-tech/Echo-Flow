import Foundation
import ApplicationServices

/// Manages macOS Accessibility permissions required for UI scripting,
/// global hotkeys, and injecting events (like pasting text).
public final class AccessibilityManager: ObservableObject {
    
    @Published public private(set) var isTrusted: Bool = false
    
    public init() {
        checkStatus(promptUser: false)
    }
    
    /// Checks if the application is currently trusted by the Accessibility subsystem.
    ///
    /// - Parameter promptUser: If `true`, macOS will present the standard System Settings
    ///                         prompt asking the user to grant permission if not already granted.
    public func checkStatus(promptUser: Bool) {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: promptUser]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.isTrusted != accessEnabled {
                self.isTrusted = accessEnabled
                AppLog.info("Accessibility Trust Status changed to: \(accessEnabled)", category: .privacy)
            }
        }
    }
    
    /// Continuously poll permission status. Often used when the app is foregrounded
    /// or when a settings window is active.
    public func startPolling() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            let currentState = AXIsProcessTrusted()
            if currentState {
                // If permission is suddenly granted, update state and stop polling.
                DispatchQueue.main.async {
                    self.isTrusted = true
                    AppLog.info("Accessibility permission granted via background poll.", category: .privacy)
                }
                timer.invalidate()
            }
        }
    }
}
