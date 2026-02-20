import Foundation
import Shared

/// Intercepts and transforms streaming dictation in real-time.
public struct StreamTransformer {
    
    /// A localized list of common conversational filler words to strip out.
    private static let fillerWords: Set<String> = [
        "äh", "ähm", "mhm", "uh", "um", "like"
    ]
    
    /// Smooths a raw transcription chunk by removing filler words before it reaches the IntentRouter.
    ///
    /// - Parameter chunk: The raw transcribed text.
    /// - Returns: A smoothed text string without conversational fillers.
    public static func smooth(chunk: String) -> String {
        var processed = chunk
        for filler in fillerWords {
            // Regex to remove exact filler word matches ignoring case.
            // \b ensures word boundaries (e.g. doesn't strip "uh" from "Uhr").
            // [\s,.]* optionally matches trailing spaces or punctuation usually accompanying fillers.
            let pattern = "(?i)\\b\(filler)\\b[\\s.,]*"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                processed = regex.stringByReplacingMatches(
                    in: processed,
                    options: [],
                    range: NSRange(location: 0, length: processed.utf16.count),
                    withTemplate: ""
                ).trimmingCharacters(in: .whitespaces)
            }
        }
        
        // Clean up any double spaces that might be left behind
        processed = processed.replacingOccurrences(of: "  ", with: " ")
        
        if processed != chunk {
            AppLog.debug("Stream smoothed: '\(chunk)' -> '\(processed)'", category: .routing)
        }
        
        return processed
    }
}
