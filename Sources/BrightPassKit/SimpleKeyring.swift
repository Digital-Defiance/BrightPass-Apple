import Foundation
import Security
import CryptoKit

/// AES-GCM keyring using Keychain for key storage.
/// Ported from brightchain-apple/Sources/BrightChainCore/Services/SimpleKeyring.swift.
public final class SimpleKeyring: KeyringProtocol, @unchecked Sendable {

    private let service: String
    private let keyTag: String

    public init(service: String = "com.brightpass.keyring") {
        self.service = service
        self.keyTag = "\(service).encryptionKey"
    }

    public func encrypt(data: Data) throws -> Data {
        let key = try getOrCreateKey()
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw SimpleKeyringError.encryptionFailed
        }
        return combined
    }

    public func decrypt(encryptedData: Data) throws -> Data {
        let key = try getOrCreateKey()
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        return try AES.GCM.open(sealedBox, using: key)
    }

    public func deleteKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: keyTag
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SimpleKeyringError.deletionFailed(status)
        }
    }

    public func hasKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: keyTag,
            kSecReturnData as String: false
        ]
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    // MARK: - Private

    private func getOrCreateKey() throws -> SymmetricKey {
        if let data = try? loadKeyData() {
            return SymmetricKey(data: data)
        }
        let key = SymmetricKey(size: .bits256)
        try saveKey(key)
        return key
    }

    private func loadKeyData() throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: keyTag,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            throw SimpleKeyringError.keyNotFound
        }
        return data
    }

    private func saveKey(_ key: SymmetricKey) throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        try? deleteKey()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: keyTag,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SimpleKeyringError.saveFailed(status)
        }
    }
}

public enum SimpleKeyringError: Error, LocalizedError {
    case keyNotFound
    case encryptionFailed
    case saveFailed(OSStatus)
    case deletionFailed(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .keyNotFound: return "Encryption key not found"
        case .encryptionFailed: return "AES-GCM encryption failed"
        case .saveFailed(let s): return "Failed to save key (OSStatus: \(s))"
        case .deletionFailed(let s): return "Failed to delete key (OSStatus: \(s))"
        }
    }
}
