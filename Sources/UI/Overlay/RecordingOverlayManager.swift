import AppKit
import SwiftUI
import Combine

/// Manages the lifecycle of the floating recording pill via `NSPanel`.
@MainActor
public final class RecordingOverlayManager {
    
    public static let shared = RecordingOverlayManager()
    
    private var panel: NSPanel?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    /// Sets up the overlay window. Call this once during app initialization.
    public func setup(with audioEngine: AudioEngine, speechService: AppleSpeechService, liveInjector: LiveTextInjector) {
        guard panel == nil else { return }
        
        let overlayView = RecordingOverlayView(audioEngine: audioEngine, speechService: speechService, liveInjector: liveInjector)
        
        // Wrap in a fixed top-aligned container to prevent window resizing twitches
        let containerView = VStack {
            overlayView
                .padding(.top, 14) // 0.5 cm from the top
            Spacer()
        }
        .frame(width: 280, height: 300)
        
        let hosting = NSHostingController(rootView: containerView)
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = NSColor.clear.cgColor
        
        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 300),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = false
        newPanel.level = .floating
        newPanel.ignoresMouseEvents = true
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        newPanel.contentViewController = hosting
        
        self.panel = newPanel
        
        reposition(on: NSScreen.main)
        
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                self?.reposition(on: NSScreen.main)
            }
            .store(in: &cancellables)
            
        audioEngine.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording in
                guard let self = self, let panel = self.panel else { return }
                if isRecording {
                    self.reposition(on: NSScreen.main)
                    panel.orderFrontRegardless()
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        panel.orderOut(nil)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func reposition(on screen: NSScreen?) {
        guard let panel = panel, let screen = screen else { return }
        
        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        let panelWidth: CGFloat = 280
        let panelHeight: CGFloat = 300
        
        // Center horizontally
        let x = screenFrame.origin.x + (screenFrame.width - panelWidth) / 2
        // Position the 300pt tall invisible window right at the top of the visible frame
        let y = visibleFrame.maxY - panelHeight
        
        panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
    }
}
