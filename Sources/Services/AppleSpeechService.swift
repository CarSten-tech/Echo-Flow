import Foundation
import Speech
import AVFoundation

/// In-process speech recognition using Apple's built-in SFSpeechRecognizer.
/// Used as a fallback when the WhisperKit XPC service is not available (e.g., during development).
public final class AppleSpeechService: ObservableObject {
    
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    /// The latest partial transcription (updated in real-time during recording).
    @Published public private(set) var partialTranscription: String = ""
    
    /// Whether a final result has been received.
    private var finalResult: String?
    private var finalContinuation: CheckedContinuation<String, Never>?
    
    public init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "de-DE"))
    }
    
    /// Starts a new recognition session. Call `feedBuffer()` to provide audio data.
    public func startListening() throws {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw NSError(domain: "AppleSpeechService", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Speech recognizer not available."])
        }
        
        // Reset state
        recognitionTask?.cancel()
        recognitionTask = nil
        finalResult = nil
        finalContinuation = nil
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        
        // Enable on-device recognition if available (macOS 13+)
        if #available(macOS 13, *) {
            request.requiresOnDeviceRecognition = speechRecognizer.supportsOnDeviceRecognition
            if speechRecognizer.supportsOnDeviceRecognition {
                AppLog.info("Using on-device speech recognition (fully offline).", category: .audio)
            }
        }
        
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let text = result.bestTranscription.formattedString
                
                DispatchQueue.main.async {
                    self.partialTranscription = text
                }
                
                // When the final result arrives, resolve the continuation
                if result.isFinal {
                    self.finalResult = text
                    self.finalContinuation?.resume(returning: text)
                    self.finalContinuation = nil
                }
            }
            
            if let error = error {
                AppLog.warning("Speech recognition error: \(error.localizedDescription)", category: .audio)
                // On error, resolve with whatever we have
                let currentText = self.partialTranscription
                self.finalContinuation?.resume(returning: currentText)
                self.finalContinuation = nil
            }
        }
        
        self.recognitionRequest = request
        DispatchQueue.main.async {
            self.partialTranscription = ""
        }
        AppLog.info("Apple Speech recognition started.", category: .audio)
    }
    
    /// Feeds a live audio buffer into the recognizer.
    public func feedBuffer(_ buffer: AVAudioPCMBuffer) {
        recognitionRequest?.append(buffer)
    }
    
    /// Stops recognition and waits for the final transcription result.
    /// This ensures the last word is not cut off.
    public func stopListening() async -> String {
        // Signal that audio has ended — this tells SFSpeech to finalize
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        // If we already have a final result, return it immediately
        if let finalResult = finalResult {
            cleanup()
            return finalResult
        }
        
        // Wait for the final result (with a timeout)
        let result = await withCheckedContinuation { (continuation: CheckedContinuation<String, Never>) in
            self.finalContinuation = continuation
            
            // Safety timeout: if no final result in 3 seconds, return what we have
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                guard let self = self, self.finalContinuation != nil else { return }
                let fallback = self.partialTranscription
                self.finalContinuation?.resume(returning: fallback)
                self.finalContinuation = nil
            }
        }
        
        cleanup()
        AppLog.info("Apple Speech final result: \(result.prefix(50))...", category: .audio)
        return result
    }
    
    private func cleanup() {
        recognitionTask?.cancel()
        recognitionTask = nil
        finalResult = nil
    }
}
