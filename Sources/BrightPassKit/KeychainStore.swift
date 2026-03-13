import Foundation
import Security

// MARK: - Protocol

/// Secure storage protocol for JWT tokens and biometric-protected master password hashes.
/// Shared between the main app and AutoFill extension via a Keychain access group.
public protocol KeychainStoreProtocol {
    func saveJWT(_ token: String) throws
    func loadJWT() throws -> String?
    func deleteJWT() throws
    func saveMasterPasswordHash(_ hash: String, vaultId: String, biometricProtected: Bool) throws
    func loadMasterPasswordHash(vaultId: String) throws -> String?
    func deleteMasterPasswordHash(vaultId: String) throws
    func hasBiometricProtectedHash(vaultId: String) throws -> Bool
    // ECIES key storage for direct challenge auth
    func saveEncryptedPrivateKey(_ data: Data, memberId: String) throws
    func loadEncryptedPrivateKey(memberId: String) throws -> Data?
    func deleteEncryptedPrivateKey(memberId: String) throws
}

// MARK: - Errors

public enum KeychainError: Error, Equatable {
    case saveFailed(status: OSStatus)
    case loadFailed(status: OSStatus)
    case deleteFailed(status: OSStatus)
    case accessControlCreationFailed
    case dataConversionFailed
}

// MARK: - Implementation

/// Concrete Keychain store using the Security framework.
/// Uses a shared access group so the main app and AutoFill extension can both read the JWT.
public final class KeychainStore: KeychainStoreProtocol {

    private let service: String
    private let accessGroup: String?

    private static let jwtAccount = "com.brightpass.jwt"
    private static let hashAccountPrefix = "com.brightpass.masterHash."
    private static let biometricFlagPrefix = "com.brightpass.biometricFlag."

    /// - Parameters:
    ///   - service: Keychain service identifier. Defaults to the app bundle ID.
    ///   - accessGroup: Shared Keychain access group for main app + AutoFill extension.
    public init(service: String = "com.brightpass.app",
                accessGroup: String? = "group.com.brightpass.shared") {
        self.service = service
        self.accessGroup = accessGroup
    }

    // MARK: - JWT

    public func saveJWT(_ token: String) throws {
        try deleteItemIfExists(account: Self.jwtAccount)
        let query = baseQuery(account: Self.jwtAccount, value: token)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status: status)
        }
    }

    public func loadJWT() throws -> String? {
        return try loadItem(account: Self.jwtAccount)
    }

    public func deleteJWT() throws {
        try deleteItem(account: Self.jwtAccount)
    }

    // MARK: - Master Password Hash

    public func saveMasterPasswordHash(_ hash: String, vaultId: String, biometricProtected: Bool) throws {
        let account = Self.hashAccountPrefix + vaultId
        try deleteItemIfExists(account: account)

        var query = baseQuery(account: account, value: hash)

        if biometricProtected {
            guard let accessControl = SecAccessControlCreateWithFlags(
                kCFAllocatorDefault,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                .biometryCurrentSet,
                nil
            ) else {
                throw KeychainError.accessControlCreationFailed
            }
            query[kSecAttrAccessControl as String] = accessControl
        }

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status: status)
        }

        // Persist the biometric flag separately so we can query it without triggering biometric prompt
        try saveBiometricFlag(biometricProtected, vaultId: vaultId)
    }

    public func loadMasterPasswordHash(vaultId: String) throws -> String? {
        let account = Self.hashAccountPrefix + vaultId
        return try loadItem(account: account)
    }

    public func deleteMasterPasswordHash(vaultId: String) throws {
        let account = Self.hashAccountPrefix + vaultId
        try deleteItem(account: account)
        try deleteBiometricFlag(vaultId: vaultId)
    }

    public func hasBiometricProtectedHash(vaultId: String) throws -> Bool {
        let account = Self.biometricFlagPrefix + vaultId
        guard let value = try loadItem(account: account) else { return false }
        return value == "true"
    }

    // MARK: - Private Helpers

    private func baseQuery(account: String, value: String? = nil) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        if let value, let data = value.data(using: .utf8) {
            query[kSecValueData as String] = data
        }
        return query
    }

    private func loadItem(account: String) throws -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw KeychainError.loadFailed(status: status)
        }
        guard let data = result as? Data, let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.dataConversionFailed
        }
        return string
    }

    private func deleteItem(account: String) throws {
        let query = baseQuery(account: account)
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status: status)
        }
    }

    private func deleteItemIfExists(account: String) throws {
        let query = baseQuery(account: account)
        let status = SecItemDelete(query as CFDictionary)
        // Ignore "not found" — we're just cleaning up before a save
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.deleteFailed(status: status)
        }
    }

    private func saveBiometricFlag(_ enabled: Bool, vaultId: String) throws {
        let account = Self.biometricFlagPrefix + vaultId
        try deleteItemIfExists(account: account)
        let query = baseQuery(account: account, value: enabled ? "true" : "false")
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status: status)
        }
    }

    private func deleteBiometricFlag(vaultId: String) throws {
        let account = Self.biometricFlagPrefix + vaultId
        try deleteItemIfExists(account: account)
    }

    // MARK: - Encrypted Private Key (ECIES Direct Challenge Auth)

    private static let encryptedKeyPrefix = "com.brightpass.encryptedKey."

    public func saveEncryptedPrivateKey(_ data: Data, memberId: String) throws {
        let account = Self.encryptedKeyPrefix + memberId
        try deleteItemIfExists(account: account)
        var query = baseQuery(account: account)
        query[kSecValueData as String] = data
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status: status)
        }
    }

    public func loadEncryptedPrivateKey(memberId: String) throws -> Data? {
        let account = Self.encryptedKeyPrefix + memberId
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw KeychainError.loadFailed(status: status)
        }
        return result as? Data
    }

    public func deleteEncryptedPrivateKey(memberId: String) throws {
        let account = Self.encryptedKeyPrefix + memberId
        try deleteItem(account: account)
    }
}
