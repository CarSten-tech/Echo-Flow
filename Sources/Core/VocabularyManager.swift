import Foundation
import Shared

/// Manages custom user vocabulary to improve WhisperKit accuracy.
/// Vocabulary can include proper nouns, specific domain terminology, or user names.
public final class VocabularyManager {
    
    private let userDefaultsKey = "EchoFlow_CustomVocabulary"
    
    public init() {}
    
    /// Returns the current custom vocabulary array.
    public func getVocabulary() -> [String] {
        return UserDefaults.standard.stringArray(forKey: userDefaultsKey) ?? []
    }
    
    /// Adds a new term to the vocabulary.
    public func addTerm(_ term: String) {
        let cleanTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTerm.isEmpty else { return }
        
        var current = getVocabulary()
        if !current.contains(cleanTerm) {
            current.append(cleanTerm)
            UserDefaults.standard.set(current, forKey: userDefaultsKey)
            AppLog.info("Added '\(cleanTerm)' to custom vocabulary.", category: .audio)
        }
    }
    
    /// Removes a term from the vocabulary.
    public func removeTerm(_ term: String) {
        var current = getVocabulary()
        current.removeAll { $0 == term }
        UserDefaults.standard.set(current, forKey: userDefaultsKey)
        AppLog.info("Removed '\(term)' from custom vocabulary.", category: .audio)
    }
    
    /// Returns the vocabulary as a comma-separated string suitable for LLM injection or Whisper `initialPrompt`.
    public func getPromptString() -> String {
        return getVocabulary().joined(separator: ", ")
    }
}
