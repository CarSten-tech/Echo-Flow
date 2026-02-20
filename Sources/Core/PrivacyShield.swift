import Foundation
import Carbon

/// Safeguards user privacy by detecting if macOS is currently in a "Secure Input" state
/// (e.g. typing in a password field, 1Password, or Terminal secure prompt).
public struct PrivacyShield {
    
    /// Checks if Secure Event Input is currently enabled system-wide.
    /// Returns true if it IS active (meaning we should NOT record).
    public static var isSecureInputActive: Bool {
        // IsSecureEventInputEnabled returns a Boolean indicating if ANY
        // application has requested secure input.
        let isSecure = IsSecureEventInputEnabled()
        
        if isSecure {
            AppLog.warning("Secure Input detected! Blocking audio capture.", category: .privacy)
        }
        
        return isSecure
    }
    
    /// Use this wrapper before executing any voice capture.
    /// Throws an error if secure input is active.
    public static func assertSafeInputEnvironment() throws {
        if isSecureInputActive {
            throw PrivacyError.secureInputActive
        }
        AppLog.debug("Privacy check passed. Environment is safe for capture.", category: .privacy)
    }
    
    public enum PrivacyError: Error, LocalizedError {
        case secureInputActive
        
        public var errorDescription: String? {
            switch self {
            case .secureInputActive:
                return "Audio capture is disabled because a secure input field (e.g. password) is currently active."
            }
        }
    }
    
    /// Scans text for likely Personal Identifiable Information (PII) like Credit Cards,
    /// and redacts them locally before cloud transmission or injection.
    public static func redactPII(from text: String) -> String {
        var redacted = text
        
        // Matches basic 13-16 digit credit cards with optional spaces/dashes
        let ccPattern = "\\b(?:\\d[ -]*?){13,16}\\b"
        if let regex = try? NSRegularExpression(pattern: ccPattern, options: []) {
            redacted = regex.stringByReplacingMatches(
                in: redacted,
                range: NSRange(location: 0, length: redacted.utf16.count),
                withTemplate: "[REDACTED-CC]"
            )
        }
        
        // Basic match for US Social Security Numbers
        let ssnPattern = "\\b\\d{3}-\\d{2}-\\d{4}\\b"
        if let regex = try? NSRegularExpression(pattern: ssnPattern, options: []) {
            redacted = regex.stringByReplacingMatches(
                in: redacted,
                range: NSRange(location: 0, length: redacted.utf16.count),
                withTemplate: "[REDACTED-SSN]"
            )
        }
        
        if redacted != text {
            AppLog.warning("PII detected and redacted locally.", category: .privacy)
        }
        
        return redacted
    }
}
