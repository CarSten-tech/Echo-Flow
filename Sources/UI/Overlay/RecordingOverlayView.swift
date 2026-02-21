import SwiftUI
import AppKit
import Combine

// MARK: - Native Vibrancy View

struct VibrancyView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var cornerRadius: CGFloat = 20
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = cornerRadius
        view.layer?.cornerCurve = .continuous
        view.layer?.masksToBounds = true
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.layer?.cornerRadius = cornerRadius
    }
}

// MARK: - Recording Overlay

public struct RecordingOverlayView: View {
    
    @ObservedObject var audioEngine: AudioEngine
    @ObservedObject var speechService: AppleSpeechService
    @ObservedObject var liveInjector: LiveTextInjector
    
    private let barCount = 5
    private let minHeight: CGFloat = 4.0
    private let maxHeight: CGFloat = 18.0
    
    public init(audioEngine: AudioEngine, speechService: AppleSpeechService, liveInjector: LiveTextInjector) {
        self.audioEngine = audioEngine
        self.speechService = speechService
        self.liveInjector = liveInjector
    }
    
    private var shouldShowText: Bool {
        !liveInjector.isInTextField && !speechService.partialTranscription.isEmpty
    }
    
    private var cornerRadius: CGFloat {
        shouldShowText ? 14 : 22
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // ── Fixed-layout Header (Centered) ──
            HStack(spacing: 0) {
                Spacer() // Left balance
                
                // Fixed-width mic container
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.red.opacity(0.25), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 10
                            )
                        )
                        .frame(width: 20, height: 20)
                        .opacity(audioEngine.isRecording ? 1 : 0)
                    
                    Image(systemName: "mic.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(audioEngine.isRecording ? .red : .white.opacity(0.6))
                }
                .frame(width: 24)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: audioEngine.isRecording)
                
                Spacer().frame(width: 8)
                
                // Waveform bars
                HStack(spacing: 3) {
                    ForEach(0..<barCount, id: \.self) { index in
                        WaveformBar(
                            level: audioEngine.audioLevel,
                            index: index,
                            totalBars: barCount,
                            minHeight: minHeight,
                            maxHeight: maxHeight
                        )
                    }
                }
                .frame(height: maxHeight)
                
                Spacer() // Right balance
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(width: shouldShowText ? 280 : 140)
            
            // ── Live Text ──
            if shouldShowText {
                Rectangle()
                    .fill(.white.opacity(0.1))
                    .frame(height: 0.5)
                    .padding(.horizontal, 12)
                
                Text(speechService.partialTranscription)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center) // Centered text for the user
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .transition(.opacity)
            }
        }
        // Applying a rigid minWidth when text is visible to keep it centered
        .frame(width: shouldShowText ? 280 : 140)
        // ── Background ──
        .background(
            VibrancyView(
                material: .hudWindow,
                blendingMode: .behindWindow,
                cornerRadius: cornerRadius
            )
        )
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.35), .white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        // ── Animations ──
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: audioEngine.isRecording)
        .animation(.easeOut(duration: 0.25), value: shouldShowText)
        .opacity(audioEngine.isRecording ? 1.0 : 0.0)
        .scaleEffect(audioEngine.isRecording ? 1.0 : 0.92)
    }
}

// MARK: - Waveform Bar

fileprivate struct WaveformBar: View {
    var level: Float
    var index: Int
    var totalBars: Int
    var minHeight: CGFloat
    var maxHeight: CGFloat
    
    private var jitterHeight: CGFloat {
        // Apply square root scaling to make low levels more visible
        let scaledLevel = CGFloat(sqrt(level))
        guard scaledLevel > 0.02 else { return minHeight }
        
        // Use a stable multiplier for the jitter
        let time = Date().timeIntervalSince1970
        let multiplier = sin(Double(index) * 1.5 + time * 10.0)
        let absoluteMultiplier = CGFloat(abs(multiplier))
        let heightRange = maxHeight - minHeight
        let targetHeight = minHeight + (heightRange * scaledLevel * absoluteMultiplier)
        
        return max(minHeight, min(targetHeight, maxHeight))
    }
    
    var body: some View {
        Capsule()
            .fill(.white.opacity(0.75))
            .frame(width: 3.5, height: jitterHeight)
            .animation(.linear(duration: 0.1), value: jitterHeight)
    }
}
