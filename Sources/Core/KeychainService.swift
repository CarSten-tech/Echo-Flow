import Foundation
import Security

/// Simple utility for secure storage of API keys using the macOS Keychain.
public struct KeychainService {
    
    public enum KeychainError: Error {
        case itemNotFound
        case insertionFailed(OSStatus)
        case deletionFailed(OSStatus)
        case unhandledError(OSStatus)
    }
    
    /// Saves a secret string to the Keychain securely.
    public static func save(key: String, secret: String) throws {
        guard let secretData = secret.data(using: .utf8) else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: secretData
        ]
        
        // Delete any existing item first
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.insertionFailed(status)
        }
    }
    
    /// Retrieves a secret string from the Keychain.
    public static func load(key: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        guard status == errSecSuccess, let data = dataTypeRef as? Data, let secret = String(data: data, encoding: .utf8) else {
            throw KeychainError.itemNotFound
        }
        
        return secret
    }
    
    /// Deletes a secret from the Keychain.
    public static func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deletionFailed(status)
        }
    }
}
