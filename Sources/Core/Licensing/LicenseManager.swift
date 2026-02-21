import Foundation
import SwiftUI
import Shared

/// Manages interaction with the Lemon Squeezy API to validate and store application license keys.
public final class LicenseManager: ObservableObject {
    
    public static let shared = LicenseManager()
    
    /// Tracks if the app has been successfully activated. Persisted securely.
    @AppStorage("isLicenseValid") public private(set) var isLicenseValid: Bool = false
    
    /// A temporary developer override to allow testing before setting up a real Store.
    private let betaTestingKey = "BETA-TESTER"
    
    private init() {
        // Upon initialization (app launch), check if we already have a stored valid state
        // In a highly secure app, we would re-validate the key silently on launch periodically,
        // but for now, trusting the local boolean + keychain presence is sufficient.
        verifyLocalState()
    }
    
    /// Checks the keychain and the AppStorage to ensure they are synchronized.
    private func verifyLocalState() {
        if let storedKey = try? KeychainService.load(key: "EchoFlowLicenseKey"), !storedKey.isEmpty {
            // We have a key. We assume it's valid if 'isLicenseValid' is true.
            // If we want to be strict, we could call 'validate(key: storedKey)' here.
            AppLog.info("License Manager: Key found in secure storage.", category: .general)
        } else {
            // No key found, force false to be safe
            isLicenseValid = false
        }
    }
    
    /// Validates a given License Key string against the Lemon Squeezy API.
    /// - Parameter key: The raw UUID/Format string provided by the user.
    /// - Returns: True if valid, false otherwise.
    public func validate(key: String) async throws -> Bool {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { return false }
        
        // --- Developer Override Bypass ---
        if trimmedKey == betaTestingKey {
            AppLog.debug("License Manager: Accepted Beta Tester Override Key.", category: .general)
            try secureActivation(with: trimmedKey)
            return true
        }
        
        // --- Lemon Squeezy REST API ---
        let url = URL(string: "https://api.lemonsqueezy.com/v1/licenses/validate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Note: The /validate endpoint does not strictly require a Bearer token, it just needs the key payload.
        
        let payload: [String: Any] = [
            "license_key": trimmedKey
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        
        AppLog.debug("License Manager: Requesting validation from Lemon Squeezy...", category: .general)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "LicenseManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid network response."])
            }
            
            // Expected JSON structure from Lemon Squeezy
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                
                // If the key is totally garbage, Lemon Squeezy returns an error JSON or 404
                if let error = json["error"] as? String {
                    AppLog.warning("License Validation Failed: \(error)", category: .general)
                    return false
                }
                
                // If it's a real key, it returns a "valid" boolean
                if let isValid = json["valid"] as? Bool {
                    if isValid {
                        try secureActivation(with: trimmedKey)
                        return true
                    } else {
                        // Key might be valid format but expired/revoked
                        AppLog.warning("License Validation Failed: Key exists but is inactive/revoked.", category: .general)
                        return false
                    }
                }
            }
            
            // Fallback for unexpected JSON format
            let statusCodeStr = "HTTP \(httpResponse.statusCode)"
            AppLog.warning("License Validation Failed: \(statusCodeStr).", category: .general)
            return false
            
        } catch {
            AppLog.error("License Validation Error: \(error.localizedDescription)", category: .general)
            throw error
        }
    }
    
    /// Locks the app and removes the key from secure storage.
    public func deactivate() throws {
        try KeychainService.delete(key: "EchoFlowLicenseKey")
        DispatchQueue.main.async {
            self.isLicenseValid = false
        }
        AppLog.info("License Manager: App deactivated and key removed.", category: .general)
    }
    
    /// Synchronizes the valid state to UI and saves the key securely.
    private func secureActivation(with validatedKey: String) throws {
        try KeychainService.save(key: "EchoFlowLicenseKey", secret: validatedKey)
        DispatchQueue.main.async {
            self.isLicenseValid = true
        }
        AppLog.info("License Manager: Successfully authenticated and secured key.", category: .general)
    }
}
