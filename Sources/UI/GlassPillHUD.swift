import SwiftUI
import AppKit

/// Wraps an NSVisualEffectView for use in SwiftUI arrays to build the Glass Pill.
struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .hudWindow
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// The programmatic floating interface providing dictated text feedback.
public class GlassPillHUD {
    private var window: NSWindow?
    
    public init() {}
    
    public func show(transcription: String, audioLevel: Float) {
        if window == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 60),
                styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.backgroundColor = .clear
            panel.hasShadow = true
            
            let contentView = NSHostingView(rootView: pillContentView(transcription: transcription, level: audioLevel))
            panel.contentView = contentView
            
            // Center near bottom of primary screen
            if let screen = NSScreen.main {
                let screenRect = screen.visibleFrame
                let panelX = screenRect.origin.x + (screenRect.width - panel.frame.width) / 2
                let panelY = screenRect.origin.y + 100 // 100px from bottom dock area
                panel.setFrameOrigin(NSPoint(x: panelX, y: panelY))
            }
            
            self.window = panel
        } else if let hostingView = window?.contentView as? NSHostingView<AnyView> {
            hostingView.rootView = pillContentView(transcription: transcription, level: audioLevel)
        }
        
        window?.orderFront(nil)
    }
    
    public func hide() {
        window?.orderOut(nil)
    }
    
    private func pillContentView(transcription: String, level: Float) -> AnyView {
        AnyView(
            ZStack {
                VisualEffectView()
                    .clipShape(Capsule())
                    
                HStack(spacing: 12) {
                    // Simple simulated waveform circle based on audio level
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: CGFloat(10 + (level * 20)), height: CGFloat(10 + (level * 20)))
                        .animation(.linear(duration: 0.1), value: level)
                    
                    Text(transcription.isEmpty ? "Listening..." : transcription)
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 50)
        )
    }
}
