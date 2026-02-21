import Foundation
import AppKit
import Combine

/// Streams partial speech recognition results directly into the active text field.
/// Uses a robust hybrid approach: Accessibility for detection, and a combination
/// of direct setting and hotkeys for injection.
public final class LiveTextInjector: ObservableObject {
    
    /// Whether we are currently successfully injecting into a text field.
    @Published public private(set) var isInTextField: Bool = false
    
    private var focusedElement: AXUIElement?
    private var previousPartialLength: Int = 0
    private var lastInjectedText: String = ""
    
    public init() {}
    
    /// Checks if a text field is focused and captures it.
    public func detectTextFieldFocus() {
        guard AXIsProcessTrusted() else {
            isInTextField = false
            return
        }
        
        let systemWide = AXUIElementCreateSystemWide()
        var focused: AnyObject?
        let result = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused)
        
        guard result == .success, let element = focused else {
            isInTextField = false
            return
        }
        
        let axElement = element as! AXUIElement
        var roleValue: AnyObject?
        AXUIElementCopyAttributeValue(axElement, kAXRoleAttribute as CFString, &roleValue)
        
        if let role = roleValue as? String {
            let textRoles = [
                kAXTextFieldRole as String,
                kAXTextAreaRole as String,
                "AXComboBox",
                "AXSearchField"
            ]
            let detected = textRoles.contains(role)
            self.isInTextField = detected
            self.focusedElement = detected ? axElement : nil
        } else {
            self.isInTextField = false
            self.focusedElement = nil
        }
    }
    
    public func beginSession() {
        previousPartialLength = 0
        lastInjectedText = ""
        detectTextFieldFocus()
    }
    
    /// Injects partial text using a select-backwards-and-replace method.
    /// This is the most compatible way across different Mac apps (including browser text areas).
    @MainActor
    public func updatePartial(_ newText: String) {
        guard isInTextField, !newText.isEmpty else { return }
        guard newText != lastInjectedText else { return }
        
        // Use general pasteboard for injection
        let pasteboard = NSPasteboard.general
        
        // 1. Select the text we previously injected
        if previousPartialLength > 0 {
            selectBackward(count: previousPartialLength)
            usleep(15_000) // 15ms
        }
        
        // 2. Paste new partial
        pasteboard.clearContents()
        pasteboard.setString(newText, forType: .string)
        emitPasteCommand()
        
        previousPartialLength = newText.count
        lastInjectedText = newText
    }
    
    @MainActor
    public func endSession(finalText: String) -> Bool {
        guard isInTextField else { return false }
        
        if previousPartialLength > 0 {
            selectBackward(count: previousPartialLength)
            usleep(15_000)
        }
        
        // Final paste with backup/restore of clipboard to be polite
        let pasteboard = NSPasteboard.general
        let backup = pasteboard.string(forType: .string)
        
        pasteboard.clearContents()
        pasteboard.setString(finalText, forType: .string)
        emitPasteCommand()
        
        if let backup = backup {
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(backup, forType: .string)
            }
        }
        
        previousPartialLength = 0
        lastInjectedText = ""
        focusedElement = nil
        return true
    }
    
    private func selectBackward(count: Int) {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        let leftArrowKeyCode: CGKeyCode = 0x7B
        
        for _ in 0..<count {
            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: leftArrowKeyCode, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: leftArrowKeyCode, keyDown: false) else { continue }
            
            keyDown.flags = .maskShift
            keyUp.flags = .maskShift
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }
    }
    
    private func emitPasteCommand() {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        let vKeyCode: CGKeyCode = 0x09
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else { return }
        
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
