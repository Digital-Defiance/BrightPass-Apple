import Foundation
@testable import BrightPassKit

/// In-memory implementation of `KeychainStoreProtocol` for use in tests.
/// No actual Keychain access — all data lives in dictionaries.
final class MockKeychainStore: KeychainStoreProtocol {

    private var jwt: String?
    private var masterPasswordHashes: [String: String] = [:]   // vaultId -> hash
    private var biometricFlags: [String: Bool] = [:]            // vaultId -> isBiometric

    func saveJWT(_ token: String) throws {
        jwt = token
    }

    func loadJWT() throws -> String? {
        return jwt
    }

    func deleteJWT() throws {
        jwt = nil
    }

    func saveMasterPasswordHash(_ hash: String, vaultId: String, biometricProtected: Bool) throws {
        masterPasswordHashes[vaultId] = hash
        biometricFlags[vaultId] = biometricProtected
    }

    func loadMasterPasswordHash(vaultId: String) throws -> String? {
        return masterPasswordHashes[vaultId]
    }

    func deleteMasterPasswordHash(vaultId: String) throws {
        masterPasswordHashes.removeValue(forKey: vaultId)
        biometricFlags.removeValue(forKey: vaultId)
    }

    func hasBiometricProtectedHash(vaultId: String) throws -> Bool {
        return biometricFlags[vaultId] ?? false
    }

    // MARK: - Encrypted Private Key

    private var encryptedKeys: [String: Data] = [:]  // memberId -> encrypted key data

    func saveEncryptedPrivateKey(_ data: Data, memberId: String) throws {
        encryptedKeys[memberId] = data
    }

    func loadEncryptedPrivateKey(memberId: String) throws -> Data? {
        return encryptedKeys[memberId]
    }

    func deleteEncryptedPrivateKey(memberId: String) throws {
        encryptedKeys.removeValue(forKey: memberId)
    }

    // MARK: - Test Helpers

    /// Reset all stored data.
    func reset() {
        jwt = nil
        masterPasswordHashes.removeAll()
        biometricFlags.removeAll()
        encryptedKeys.removeAll()
    }
}
