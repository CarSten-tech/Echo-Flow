import Foundation

/// Manages a self-learning dictionary of domain-specific terms or user names.
/// These terms are fed back into the speech recognition engine to improve accuracy.
public final class VocabularyManager {
    
    /// Shared singleton instance for global vocabulary access.
    public static let shared = VocabularyManager()
    
    // Using UserDefaults for lightweight storage of the vocabulary array.
    private let storageKey = "EchoFlow.Vocabulary"
    
    private var words: Set<String> {
        get {
            let array = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
            return Set(array)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: storageKey)
        }
    }
    
    private init() {}
    
    /// Adds a new term to the local vocabulary.
    ///
    /// - Parameter word: The custom word or phrase to learn.
    public func addTerm(_ word: String) {
        var currentWords = words
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty, !currentWords.contains(trimmed) else { return }
        
        currentWords.insert(trimmed)
        words = currentWords
        print("[VocabularyManager] Learned new term: '\(trimmed)'.")
    }
    
    /// Exports the current dictionary as a comma-separated string suitable for
    /// injection into Whisper's `initialPrompt` configuration.
    public func buildWhisperPrompt() -> String {
        return words.joined(separator: ", ")
    }
    
    /// Clears the learned vocabulary.
    public func clearVocabulary() {
        words.removeAll()
        print("[VocabularyManager] Vocabulary cleared.")
    }
}
