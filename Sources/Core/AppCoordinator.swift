import Foundation
import Shared
import AVFoundation

/// The central nervous system of EchoFlow.
/// Wires together audio capture, semantic routing, and OS execution.
public final class AppCoordinator: ObservableObject {
    
    // Core Dependencies
    private let accessibilityManager = AccessibilityManager()
    private let audioEngine = AudioEngine()
    private let whisperService = WhisperService()
    private let intentRouter = IntentRouter()
    private let workflowHandler = WorkflowHandler()
    
    // Global State
    @Published public private(set) var isProcessing = false
    
    public init() {
        // Observe Hotkey Trigger (Conceptual implementation)
        // In a real environment, HotkeyManager would dispatch a notification here
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHotkeyPress),
            name: NSNotification.Name("EchoFlowTriggerPressed"),
            object: nil
        )
    }
    
    @objc private func handleHotkeyPress() {
        // 1. Pre-flight Check
        guard accessibilityManager.isTrusted else {
            accessibilityManager.checkStatus(promptUser: true)
            return
        }
        
        // 2. Start Capture
        if !audioEngine.isRecording {
            startRecording()
        } else {
            stopRecordingAndProcess()
        }
    }
    
    private func startRecording() {
        do {
            try audioEngine.startRecording()
            isProcessing = true
            AppLog.info("Started recording session.", category: .audio)
        } catch {
            AppLog.error("Failed to start AudioEngine: \(error)", category: .audio)
            isProcessing = false
        }
    }
    
    private func stopRecordingAndProcess() {
        audioEngine.stopRecording()
        AppLog.info("Recording stopped. Processing audio...", category: .audio)
        
        // Simulate pulling the final buffer and handing to Whisper
        // In reality, this would be an async stream or completion block
        let dummyFormat = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        let dummyBuffer = AVAudioPCMBuffer(pcmFormat: dummyFormat, frameCapacity: 1024)!
        
        Task {
            // 3. Transcribe
            whisperService.pushBuffer(dummyBuffer)
            let rawTranscription = "simulated transcription äh from whisper mhm" // Stubbed since pushBuffer is stream based
            var transcription = StreamTransformer.smooth(chunk: rawTranscription)
            
            // 3.5 Privacy Check: Redact PII locally
            transcription = PrivacyShield.redactPII(from: transcription)
            
            // 4. Semantic Routing
            let context = AppContextDetector.getCurrentContext()
            let route = await intentRouter.route(transcription: transcription, context: context)
            
            // 5. Execution
            handleRouteResult(route)
            
            DispatchQueue.main.async {
                self.isProcessing = false
            }
        }
    }
    
    private func handleRouteResult(_ result: RouteResult) {
        switch result {
        case .dictation(let finalString):
            let formattedString = TextFormatter.format(finalString)
            AppLog.info("Routing -> Dictation", category: .routing)
            TextInjector.inject(text: formattedString)
            
        case .command(let action, let params):
            AppLog.info("Routing -> Command: \(action)", category: .routing)
            workflowHandler.executeCommand(action: action, parameters: params)
            
        case .unknown:
            AppLog.warning("Routing -> Unknown intent. Ignoring.", category: .routing)
        }
    }
}
