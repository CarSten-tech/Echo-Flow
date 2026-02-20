import Foundation
import CoreVideo
import IOSurface

/// Manages zero-copy shared memory buffering between the Main UI App and the XPC Engine.
/// This approach reduces IPC latency by passing memory descriptors via XPC
/// rather than copying `Data` back and forth.
public struct IOSurfaceManager {
    
    /// Creates a shared memory surface optimized for audio buffer transfer.
    ///
    /// - Parameter bufferSize: The size in bytes required for the audio frame.
    /// - Returns: An IOSurfaceRef that can be safely passed across XPC boundaries, or nil on failure.
    public static func createSharedAudioSurface(bufferSize: Int) -> IOSurfaceRef? {
        let properties: [CFString: Any] = [
            kIOSurfaceWidth: bufferSize,
            kIOSurfaceHeight: 1,
            kIOSurfaceBytesPerElement: 1,
            kIOSurfacePixelFormat: kCVPixelFormatType_OneComponent8
        ]
        
        guard let surface = IOSurfaceCreate(properties as CFDictionary) else {
            print("[IOSurfaceManager] ERROR: Failed to allocate zero-copy IOSurface.")
            return nil
        }
        
        print("[IOSurfaceManager] Successfully allocated shared IOSurface (Size: \(bufferSize) bytes).")
        return surface
    }
}
