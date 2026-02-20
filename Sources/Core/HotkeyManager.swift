import Foundation
import Carbon
import AppKit

/// Registers a global hotkey (e.g., Cmd+Shift+D) to trigger dictation system-wide.
public class HotkeyManager: ObservableObject {
    
    public var onHotkeyPressed: (() -> Void)?
    private var eventMonitor: Any?
    
    public init() {
        setupGlobalMonitor()
    }
    
    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    private func setupGlobalMonitor() {
        // Accessibility permissions are required for this to work natively via NSEvent.
        // A robust implementation would use Carbon's RegisterEventHotKey for lower-level grabs.
        let options: NSEvent.EventTypeMask = [.keyDown]
        
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: options) { [weak self] event in
            // Basic check for Cmd + Shift + D (key code 2)
            if event.modifierFlags.contains(.command) &&
               event.modifierFlags.contains(.shift) &&
               event.keyCode == 2 {
                
                AppLog.debug("Global Hotkey triggered.", category: .general)
                
                // Assert PrivacyShield before notifying the delegate
                do {
                    try PrivacyShield.assertSafeInputEnvironment()
                    DispatchQueue.main.async {
                        self?.onHotkeyPressed?()
                    }
                } catch {
                    AppLog.error("Hotkey intercepted but recording blocked: \(error.localizedDescription)", category: .privacy)
                    // We could trigger a visual "blocked" warning here
                }
            }
        }
        
        if eventMonitor != nil {
            AppLog.info("Global Event Monitor registered successfully.", category: .general)
        } else {
            AppLog.warning("Failed to register Global Event Monitor. Ensure Accessibility permissions are granted.", category: .general)
        }
    }
}
