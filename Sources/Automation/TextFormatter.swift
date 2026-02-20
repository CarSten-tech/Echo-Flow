import Foundation

/// A deterministic post-processor that applies rule-based formatting 
/// to the generated dictation text before final injection into the system.
public struct TextFormatter {
    
    /// Applies all active formatting rules to the input string.
    public static func format(_ text: String) -> String {
        var formatted = text
        formatted = applyCurrencyRules(formatted)
        formatted = applyTechnicalCasing(formatted)
        return formatted
    }
    
    private static func applyCurrencyRules(_ text: String) -> String {
        var processed = text
        
        // Regex: Number followed by " Euro" or " Euros" -> "Number€"
        let euroPattern = "(\\d+)\\s*[Ee]uro(s)?"
        if let regex = try? NSRegularExpression(pattern: euroPattern, options: []) {
            processed = regex.stringByReplacingMatches(
                in: processed,
                range: NSRange(location: 0, length: processed.utf16.count),
                withTemplate: "$1€"
            )
        }
        
        return processed
    }
    
    private static func applyTechnicalCasing(_ text: String) -> String {
        var processed = text
        
        // Ensure known technical acronyms are properly capitalized
        let replacements: [String: String] = [
            "api": "API",
            "ui": "UI",
            "xpc": "XPC",
            "json": "JSON",
            "macos": "macOS",
            "ios": "iOS",
            "swiftui": "SwiftUI"
        ]
        
        for (key, value) in replacements {
            let pattern = "\\b(?i)\(key)\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                processed = regex.stringByReplacingMatches(
                    in: processed,
                    range: NSRange(location: 0, length: processed.utf16.count),
                    withTemplate: value
                )
            }
        }
        
        return processed
    }
}
