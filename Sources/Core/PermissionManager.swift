import Foundation
import AVFoundation

/// Manages and requests system permissions required for EchoFlow.
public final class PermissionManager: ObservableObject {
    @Published public private(set) var hasMicrophoneAccess: Bool = false
    
    public init() {
        checkMicrophoneAccess()
    }
    
    /// Checks current microphone authorization status
    public func checkMicrophoneAccess() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        DispatchQueue.main.async {
            self.hasMicrophoneAccess = (status == .authorized)
        }
    }
    
    /// Requests microphone access from the user
    public func requestMicrophoneAccess() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        DispatchQueue.main.async {
            self.hasMicrophoneAccess = granted
        }
        return granted
    }
}
