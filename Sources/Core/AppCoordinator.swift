import Foundation
import Shared
import AVFoundation
import KeyboardShortcuts
import AppKit
import Speech
import Combine

/// The central nervous system of EchoFlow.
/// Wires together audio capture, semantic routing, and OS execution.
public final class AppCoordinator: ObservableObject {
    
    /// Manages accessibility permissions required for text injection.
    private let accessibilityManager = AccessibilityManager()
    
    /// The local audio capture engine.
    private let audioEngine = AudioEngine()
    
    /// In-process speech recognition (Apple's SFSpeechRecognizer). 
    private let speechService = AppleSpeechService()
    
    /// Streams partial text directly into the active text field (when applicable).
    private let liveInjector = LiveTextInjector()
    
    /// Routes transcribed text to either a dictation injection or an executable AppleScript command.
    private let intentRouter = IntentRouter()
    
    /// Executes native system interactions.
    private let workflowHandler = WorkflowHandler()
    
    /// Subscription for partial transcription updates.
    private var partialSub: AnyCancellable?
    
    // Global State
    
    /// Indicates whether the system is currently recording or processing audio.
    @Published public private(set) var isProcessing = false
    
    /// Initializes the AppCoordinator and attaches the global hotkey listener.
    public init() {
        Task { @MainActor in
            // Initialize the Liquid Glass Overlay, passing liveInjector for context-aware display
            RecordingOverlayManager.shared.setup(
                with: self.audioEngine,
                speechService: self.speechService,
                liveInjector: self.liveInjector
            )
        }
        
        // Hotkey: Key Down
        KeyboardShortcuts.onKeyDown(for: .toggleDictation) { [weak self] in
            guard let self = self else { return }
            
            // 0. License Verification
            guard LicenseManager.shared.isLicenseValid else {
                AppLog.warning("License Enforcement: Attempted dictation without valid license.", category: .general)
                let alert = NSAlert()
                alert.messageText = "License Required"
                alert.informativeText = "EchoFlow requires a valid license key to function. Please open Settings -> License to activate."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
                return
            }
            
            // 1. Accessibility Verification
            guard self.accessibilityManager.isTrusted else {
                self.accessibilityManager.checkStatus(promptUser: true)
                return
            }
            
            let mode = ModelSettings.shared.recordingMode
            
            switch mode {
            case .pushToTalk:
                // Hold to record
                if !self.audioEngine.isRecording {
                    self.startRecording()
                }
            case .toggleToTalk:
                // Press once = start, press again = stop
                if self.audioEngine.isRecording {
                    self.stopRecordingAndProcess()
                } else {
                    self.startRecording()
                }
            }
        }
        
        // Hotkey: Key Up (only matters for push-to-talk)
        KeyboardShortcuts.onKeyUp(for: .toggleDictation) { [weak self] in
            guard let self = self else { return }
            
            let mode = ModelSettings.shared.recordingMode
            if mode == .pushToTalk && self.audioEngine.isRecording {
                self.stopRecordingAndProcess()
            }
        }
    }
    
    private func startRecording() {
        do {
            // Detect if we're in a text field BEFORE recording starts
            liveInjector.beginSession()
            
            // Start in-process speech recognition
            try speechService.startListening()
            
            // Wire live audio capture to Apple Speech
            audioEngine.onBufferReceived = { [weak self] buffer in
                self?.speechService.feedBuffer(buffer)
            }
            
            // If we're in a text field, stream partial results directly into it
            if liveInjector.isInTextField {
                partialSub = speechService.$partialTranscription
                    .receive(on: DispatchQueue.main)
                    .dropFirst() // Skip the initial empty value
                    .removeDuplicates()
                    .throttle(for: .milliseconds(300), scheduler: DispatchQueue.main, latest: true)
                    .sink { [weak self] partial in
                        guard let self = self, !partial.isEmpty else { return }
                        Task { @MainActor in
                            self.liveInjector.updatePartial(partial)
                        }
                    }
            }
            
            try audioEngine.startRecording()
            isProcessing = true
            AppLog.info("Started recording. TextField mode: \(liveInjector.isInTextField)", category: .audio)
        } catch {
            AppLog.error("Failed to start recording: \(error)", category: .audio)
            isProcessing = false
        }
    }
    
    private func stopRecordingAndProcess() {
        audioEngine.stopRecording()
        audioEngine.onBufferReceived = nil
        partialSub?.cancel()
        partialSub = nil
        AppLog.info("Recording stopped. Processing audio...", category: .audio)
        
        Task {
            // Wait for the final transcription (ensures last word is captured)
            let rawTranscription = await speechService.stopListening()
            
            guard !rawTranscription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                AppLog.warning("Empty transcription received. Skipping.", category: .audio)
                await MainActor.run { self.isProcessing = false }
                return
            }
            
            var transcription = StreamTransformer.smooth(chunk: rawTranscription)
            transcription = PrivacyShield.redactPII(from: transcription)
            
            let finalTranscription = transcription
            
            // If we were streaming into a text field, finalize there
            let wasInjectedLive = await MainActor.run {
                self.liveInjector.endSession(finalText: finalTranscription)
            }
            
            if wasInjectedLive {
                // Text is already in the text field — skip routing
                AppLog.info("Live injection finalized. Skipping LLM routing.", category: .routing)
            } else {
                // Not in a text field — use normal routing pipeline
                let context = AppContextDetector.getCurrentContext()
                let route = await intentRouter.route(transcription: transcription, context: context)
                await handleRouteResult(route)
            }
            
            await MainActor.run {
                self.isProcessing = false
            }
        }
    }
    
    /// Resolves the intended action determined by the LLM routing sequence.
    private func handleRouteResult(_ result: RouteResult) async {
        switch result {
        case .dictation(let finalString):
            let formattedString = TextFormatter.format(finalString)
            AppLog.info("Routing -> Dictation", category: .routing)
            await TextInjector.inject(text: formattedString)
            
        case .command(let action, let params):
            AppLog.info("Routing -> Command: \(action)", category: .routing)
            workflowHandler.executeCommand(action: action, parameters: params)
            
        case .unknown:
            AppLog.warning("Routing -> Unknown intent. Ignoring.", category: .routing)
        }
    }
}
