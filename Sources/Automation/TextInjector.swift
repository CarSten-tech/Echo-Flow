import Foundation
import AppKit
import CoreGraphics

/// Responsible for injecting transcribed text into the currently active macOS application
/// using a high-performance clipboard swap technique.
public struct TextInjector {
    
    /// Injects text into the active text field by bypassing the native copy-paste buffer.
    /// It temporarily stores the user's clipboard, inserts the dictated text, synthesizes a Cmd+V keystroke,
    /// and then asynchronously restores the original clipboard to avoid destroying user data.
    ///
    /// - Parameter text: The cleaned and formatted text ready for injection.
    @MainActor public static func inject(text: String) {
        // 1. Ensure we have Accessibility rights to send synthetic key events
        guard AXIsProcessTrusted() else {
            AppLog.error("Missing Accessibility Privileges. Cannot inject text.", category: .routing)
            return
        }
        
        let pasteboard = NSPasteboard.general
        
        // 2. Backup the user's current clipboard contents so we don't destroy their copied data
        var backupItems: [NSPasteboardItem] = []
        if let currentItems = pasteboard.pasteboardItems {
            for item in currentItems {
                let newItem = NSPasteboardItem()
                for type in item.types {
                    if let data = item.data(forType: type) {
                        newItem.setData(data, forType: type)
                    }
                }
                backupItems.append(newItem)
            }
        }
        
        // 3. Set the generated text to the general pasteboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // 4. Synthesize Cmd+V
        emitPasteCommand()
        
        // 5. Restore clipboard backup asynchronously to ensure the App had time to consume the paste
        Task { [backupItems] in
            do {
                // Wait 0.3 seconds to allow slower apps to process the Cmd+V
                try await Task.sleep(nanoseconds: 300_000_000)
                
                pasteboard.clearContents()
                pasteboard.writeObjects(backupItems)
                AppLog.debug("Clipboard restored.", category: .routing)
            } catch {
                AppLog.error("Clipboard restoration task was cancelled or failed: \(error)", category: .routing)
            }
        }
    }
    
    /// Emits a synthetic Command+V key event using CoreGraphics.
    private static func emitPasteCommand() {
        let vKeyCode: CGKeyCode = 0x09 // Virtual key code for 'v'
        
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            AppLog.error("Failed to create CGEventSource.", category: .routing)
            return
        }
        
        // Create Key Down and Key Up events
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            return
        }
        
        // Apply Cmd modifier flag
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        
        // Post events to the currently active application
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        
        AppLog.info("Injected Cmd+V synthetic event.", category: .routing)
    }
}
