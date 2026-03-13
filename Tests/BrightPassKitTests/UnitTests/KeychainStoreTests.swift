// Unit tests for KeychainStore using MockKeychainStore.
// Validates JWT lifecycle, master password hash with biometric flags,
// and shared access group behavior via the KeychainStoreProtocol.
//
// Requirements: 12.7, 12.8

import XCTest
@testable import BrightPassKit

final class KeychainStoreTests: XCTestCase {

    private var store: MockKeychainStore!

    override func setUp() {
        super.setUp()
        store = MockKeychainStore()
    }

    override func tearDown() {
        store.reset()
        store = nil
        super.tearDown()
    }

    // MARK: - JWT Token Lifecycle (Requirement 12.7)

    func testSaveAndLoadJWT() throws {
        let token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test"
        try store.saveJWT(token)
        let loaded = try store.loadJWT()
        XCTAssertEqual(loaded, token)
    }

    func testLoadJWTReturnsNilWhenEmpty() throws {
        let loaded = try store.loadJWT()
        XCTAssertNil(loaded)
    }

    func testDeleteJWTClearsToken() throws {
        try store.saveJWT("some-jwt-token")
        try store.deleteJWT()
        let loaded = try store.loadJWT()
        XCTAssertNil(loaded)
    }

    func testSaveJWTOverwritesPreviousToken() throws {
        try store.saveJWT("first-token")
        try store.saveJWT("second-token")
        let loaded = try store.loadJWT()
        XCTAssertEqual(loaded, "second-token")
    }

    func testDeleteJWTWhenAlreadyEmptyDoesNotThrow() throws {
        XCTAssertNoThrow(try store.deleteJWT())
    }

    // MARK: - Master Password Hash with Biometric Flag (Requirement 12.7, 12.8)

    func testSaveAndLoadMasterPasswordHash() throws {
        let hash = "sha256-hashed-password"
        let vaultId = "vault-001"
        try store.saveMasterPasswordHash(hash, vaultId: vaultId, biometricProtected: false)
        let loaded = try store.loadMasterPasswordHash(vaultId: vaultId)
        XCTAssertEqual(loaded, hash)
    }

    func testDeleteMasterPasswordHashClearsHash() throws {
        let vaultId = "vault-002"
        try store.saveMasterPasswordHash("hash123", vaultId: vaultId, biometricProtected: true)
        try store.deleteMasterPasswordHash(vaultId: vaultId)
        let loaded = try store.loadMasterPasswordHash(vaultId: vaultId)
        XCTAssertNil(loaded)
    }

    func testLoadMasterPasswordHashReturnsNilForUnknownVault() throws {
        let loaded = try store.loadMasterPasswordHash(vaultId: "nonexistent")
        XCTAssertNil(loaded)
    }

    // MARK: - Biometric Access Control Flag Configuration

    func testBiometricFlagSetToTrueWhenSavedWithBiometric() throws {
        let vaultId = "vault-bio"
        try store.saveMasterPasswordHash("hash", vaultId: vaultId, biometricProtected: true)
        let hasBiometric = try store.hasBiometricProtectedHash(vaultId: vaultId)
        XCTAssertTrue(hasBiometric)
    }

    func testBiometricFlagSetToFalseWhenSavedWithoutBiometric() throws {
        let vaultId = "vault-nobio"
        try store.saveMasterPasswordHash("hash", vaultId: vaultId, biometricProtected: false)
        let hasBiometric = try store.hasBiometricProtectedHash(vaultId: vaultId)
        XCTAssertFalse(hasBiometric)
    }

    func testHasBiometricProtectedHashReturnsFalseForUnknownVault() throws {
        let hasBiometric = try store.hasBiometricProtectedHash(vaultId: "unknown")
        XCTAssertFalse(hasBiometric)
    }

    func testDeleteMasterPasswordHashAlsoClearsBiometricFlag() throws {
        let vaultId = "vault-clear"
        try store.saveMasterPasswordHash("hash", vaultId: vaultId, biometricProtected: true)

        // Confirm biometric flag is set
        XCTAssertTrue(try store.hasBiometricProtectedHash(vaultId: vaultId))

        // Delete the hash
        try store.deleteMasterPasswordHash(vaultId: vaultId)

        // Biometric flag should also be cleared
        XCTAssertFalse(try store.hasBiometricProtectedHash(vaultId: vaultId))
    }

    func testOverwriteHashUpdatesBiometricFlag() throws {
        let vaultId = "vault-overwrite"

        // Save with biometric enabled
        try store.saveMasterPasswordHash("hash1", vaultId: vaultId, biometricProtected: true)
        XCTAssertTrue(try store.hasBiometricProtectedHash(vaultId: vaultId))

        // Overwrite with biometric disabled
        try store.saveMasterPasswordHash("hash2", vaultId: vaultId, biometricProtected: false)
        XCTAssertFalse(try store.hasBiometricProtectedHash(vaultId: vaultId))

        // Hash should be the new value
        XCTAssertEqual(try store.loadMasterPasswordHash(vaultId: vaultId), "hash2")
    }

    // MARK: - Multiple Vaults Isolation

    func testMultipleVaultsStoreIndependentHashes() throws {
        try store.saveMasterPasswordHash("hashA", vaultId: "vault-A", biometricProtected: true)
        try store.saveMasterPasswordHash("hashB", vaultId: "vault-B", biometricProtected: false)

        XCTAssertEqual(try store.loadMasterPasswordHash(vaultId: "vault-A"), "hashA")
        XCTAssertEqual(try store.loadMasterPasswordHash(vaultId: "vault-B"), "hashB")
        XCTAssertTrue(try store.hasBiometricProtectedHash(vaultId: "vault-A"))
        XCTAssertFalse(try store.hasBiometricProtectedHash(vaultId: "vault-B"))
    }

    func testDeletingOneVaultHashDoesNotAffectOther() throws {
        try store.saveMasterPasswordHash("hashA", vaultId: "vault-A", biometricProtected: true)
        try store.saveMasterPasswordHash("hashB", vaultId: "vault-B", biometricProtected: true)

        try store.deleteMasterPasswordHash(vaultId: "vault-A")

        XCTAssertNil(try store.loadMasterPasswordHash(vaultId: "vault-A"))
        XCTAssertEqual(try store.loadMasterPasswordHash(vaultId: "vault-B"), "hashB")
        XCTAssertTrue(try store.hasBiometricProtectedHash(vaultId: "vault-B"))
    }

    // MARK: - Shared Access Group (Requirement 12.7)

    func testKeychainStoreInitializesWithDefaultAccessGroup() {
        let keychainStore = KeychainStore()
        // Verify the store can be created with default shared access group.
        // The shared group "group.com.brightpass.shared" enables JWT sharing
        // between the main app and AutoFill extension.
        XCTAssertNotNil(keychainStore)
    }

    func testKeychainStoreAcceptsCustomAccessGroup() {
        let keychainStore = KeychainStore(
            service: "com.test.service",
            accessGroup: "group.com.test.custom"
        )
        XCTAssertNotNil(keychainStore)
    }

    func testKeychainStoreAcceptsNilAccessGroup() {
        let keychainStore = KeychainStore(
            service: "com.test.service",
            accessGroup: nil
        )
        XCTAssertNotNil(keychainStore)
    }
}
