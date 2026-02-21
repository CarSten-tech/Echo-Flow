import SwiftUI
import CoreGraphics
import AVFoundation

public struct PermissionsView: View {
    @State private var hasMicAccess = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    @State private var hasAccessibilityAccess = AXIsProcessTrusted()
    @State private var timer: Timer?

    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            Text("Permissions Required")
                .font(.largeTitle)
                .bold()
            
            Text("EchoFlow needs the following permissions to work properly.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 15) {
                PermissionRow(
                    title: "Microphone",
                    description: "Required to record your dictations.",
                    isGranted: hasMicAccess,
                    action: requestMicrophone
                )
                
                PermissionRow(
                    title: "Accessibility",
                    description: "Required to inject text into your active application.",
                    isGranted: hasAccessibilityAccess,
                    action: requestAccessibility
                )
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.windowBackgroundColor)))
            
            Spacer()
        }
        .padding()
        .onAppear {
            startPolling()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func requestMicrophone() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                self.hasMicAccess = granted
            }
        }
    }
    
    private func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    // Fallback to polling for Accessibility since there's no native callback for granting access
    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            let micStatus = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
            let axStatus = AXIsProcessTrusted()
            
            if micStatus != hasMicAccess { hasMicAccess = micStatus }
            if axStatus != hasAccessibilityAccess { hasAccessibilityAccess = axStatus }
        }
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title).font(.headline)
                Text(description).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .imageScale(.large)
            } else {
                Button("Grant Access", action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}
