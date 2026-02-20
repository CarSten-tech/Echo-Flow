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
    
    private func getHUDHeight() -> CGFloat {
        let sizePref = UserDefaults.standard.string(forKey: "hudSize") ?? "Medium"
        switch sizePref {
        case "Small": return 40
        case "Large": return 70
        default: return 50
        }
    }
    
    private func pillContentView(transcription: String, level: Float) -> AnyView {
        let sizePref = UserDefaults.standard.string(forKey: "hudSize") ?? "Medium"
        let fontStyle: Font.TextStyle = sizePref == "Small" ? .caption : (sizePref == "Large" ? .title3 : .body)
        let height = getHUDHeight()
        
        let circleSize: CGFloat = CGFloat(10 + (level * 20))
        let textToShow = transcription.isEmpty ? "Listening..." : transcription
        
        // Break up expression to help the Swift 5.9 type checker
        let content = ZStack {
            VisualEffectView()
                .clipShape(Capsule())
                
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: circleSize, height: circleSize)
                    .animation(.linear(duration: 0.1), value: level)
                
                Text(textToShow)
                    .font(.system(fontStyle, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
        }
        .frame(height: height)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Echo Flow Dictation HUD")
        .accessibilityValue(textToShow)
        .accessibilityHint("Displays real-time dictation text and microphone levels.")
        .accessibilityAddTraits(.updatesFrequently)
        
        return AnyView(content)
    }
}
