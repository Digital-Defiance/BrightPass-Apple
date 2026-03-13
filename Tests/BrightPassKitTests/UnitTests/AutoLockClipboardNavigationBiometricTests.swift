// Unit tests for auto-lock, clipboard, navigation, and biometric unlock
// Validates: Requirements 12.1, 12.2, 12.4, 12.5, 13.2, 13.3, 15.1, 15.5, 16.2

import XCTest
import SwiftUI
@testable import BrightPassKit

// MARK: - Mock Biometric Authenticator

/// Configurable mock for biometric authentication in tests.
private final class MockBiometricAuthenticator: BiometricAuthenticatorProtocol, @unchecked Sendable {
    var canEvaluate: Bool = true
    var evaluateResult: Bool = true

    func canEvaluateBiometrics() -> Bool { canEvaluate }
    func evaluateBiometrics(reason: String) async -> Bool { evaluateResult }
}

// MARK: - Mock APIClient

@available(macOS 14.0, iOS 17.0, *)
private final class MockAPIClient: APIClientProtocol, @unchecked Sendable {

    var openVaultResult: DecryptedVault?
    var openVaultError: Error?

    func openVault(id: String, masterPassword: String) async throws -> DecryptedVault {
        if let err = openVaultError { throw err }
        guard let result = openVaultResult else {
            throw APIError(status: 500, code: "no_mock", message: "No mock vault", details: nil)
        }
        return result
    }

    // Unused stubs
    func requestDirectLogin() async throws -> DirectLoginChallenge { fatalError() }
    func submitDirectChallenge(challenge: String, signature: String, username: String?, email: String?) async throws -> DirectChallengeResponse { fatalError() }
    func refreshToken() async throws -> DirectChallengeResponse { fatalError() }
    func logout() async throws { fatalError() }
    func verifyToken() async throws -> UserProfile { fatalError() }
    func login(username: String, password: String) async throws -> AuthResponse { fatalError() }
    func register(username: String, email: String, password: String) async throws -> AuthResponse { fatalError() }
    func listVaults() async throws -> [VaultMetadata] { fatalError() }
    func createVault(name: String, masterPassword: String) async throws -> VaultMetadata { fatalError() }
    func deleteVault(id: String) async throws { fatalError() }
    func renameVault(id: String, name: String) async throws -> VaultMetadata { fatalError() }
    func listEntries(vaultId: String) async throws -> [EntryPropertyRecord] { fatalError() }
    func getEntry(vaultId: String, entryId: String) async throws -> VaultEntry { fatalError() }
    func createEntry(vaultId: String, entry: VaultEntry) async throws -> VaultEntry { fatalError() }
    func updateEntry(vaultId: String, entryId: String, entry: VaultEntry) async throws -> VaultEntry { fatalError() }
    func deleteEntry(vaultId: String, entryId: String) async throws { fatalError() }
    func searchEntries(vaultId: String, query: String) async throws -> [EntryPropertyRecord] { fatalError() }
    func generatePassword(options: PasswordOptions) async throws -> GeneratedPassword { fatalError() }
    func generateTOTP(secret: String) async throws -> TotpCode { fatalError() }
    func validateTOTPSecret(secret: String) async throws -> TotpCode { fatalError() }
    func checkBreach(password: String) async throws -> BreachCheckResult { fatalError() }
    func autofillLookup(serviceIdentifier: String) async throws -> [AutofillPayload] { fatalError() }
    func getAuditLog(vaultId: String) async throws -> [AuditLogEntry] { fatalError() }
    func shareVault(vaultId: String, memberId: String, permission: SharePermission) async throws { fatalError() }
    func revokeShare(vaultId: String, memberId: String) async throws { fatalError() }
    func listSharedMembers(vaultId: String) async throws -> [SharedMember] { fatalError() }
    func configureEmergencyAccess(vaultId: String, config: EmergencyAccessConfig) async throws { fatalError() }
    func getEmergencyAccessConfig(vaultId: String) async throws -> EmergencyAccessConfig { fatalError() }
    func recoverVault(vaultId: String, shares: [String]) async throws -> DecryptedVault { fatalError() }
    func importEntries(vaultId: String, source: ImportSource, fileData: Data) async throws -> ImportResult { fatalError() }
    func changeMasterPassword(vaultId: String, currentPassword: String, newPassword: String) async throws { fatalError() }
    func exportEntries(vaultId: String, format: ExportFormat) async throws -> Data { fatalError() }
}


// MARK: - AutoLockManager Tests

/// Validates: Requirements 12.1, 12.2, 12.4, 12.5
@available(macOS 14.0, iOS 17.0, *)
@MainActor
final class AutoLockManagerTests: XCTestCase {

    /// Req 12.2: Default timeout is 15 minutes.
    func testDefaultTimeoutIs15Minutes() {
        let manager = AutoLockManager()
        XCTAssertEqual(manager.timeoutMinutes, 15)
    }

    /// Req 12.2: isLocked defaults to false.
    func testDefaultIsLockedFalse() {
        let manager = AutoLockManager()
        XCTAssertFalse(manager.isLocked)
    }

    /// Req 12.1: lock() sets isLocked to true.
    func testLockSetsIsLockedTrue() {
        let manager = AutoLockManager()
        manager.lock()
        XCTAssertTrue(manager.isLocked)
    }

    /// Req 12.1: lock() posts vaultLocked notification.
    func testLockPostsNotification() {
        let manager = AutoLockManager()
        let expectation = expectation(forNotification: .vaultLocked, object: manager)

        manager.lock()

        wait(for: [expectation], timeout: 1.0)
    }

    /// Timeout clamping: values below 1 are clamped to 1.
    func testTimeoutClampedToMinimum() {
        let manager = AutoLockManager()
        manager.timeoutMinutes = 0
        XCTAssertEqual(manager.timeoutMinutes, 1)

        manager.timeoutMinutes = -10
        XCTAssertEqual(manager.timeoutMinutes, 1)
    }

    /// Timeout clamping: values above 60 are clamped to 60.
    func testTimeoutClampedToMaximum() {
        let manager = AutoLockManager()
        manager.timeoutMinutes = 120
        XCTAssertEqual(manager.timeoutMinutes, 60)

        manager.timeoutMinutes = 999
        XCTAssertEqual(manager.timeoutMinutes, 60)
    }

    /// Valid timeout values within range are accepted as-is.
    func testTimeoutAcceptsValidValues() {
        let manager = AutoLockManager()
        for value in [1, 5, 15, 30, 60] {
            manager.timeoutMinutes = value
            XCTAssertEqual(manager.timeoutMinutes, value)
        }
    }

    /// Req 12.4: startAcceleratedTimer creates a timer (does not immediately lock).
    func testStartAcceleratedTimerDoesNotImmediatelyLock() {
        let manager = AutoLockManager()
        manager.startAcceleratedTimer()
        XCTAssertFalse(manager.isLocked, "Accelerated timer should not lock immediately")
    }

    /// Req 12.5: cancelAcceleratedTimer prevents accelerated lock.
    func testCancelAcceleratedTimerPreventsLock() {
        let manager = AutoLockManager()
        manager.startAcceleratedTimer()
        manager.cancelAcceleratedTimer()
        // After cancellation, the manager should still not be locked
        XCTAssertFalse(manager.isLocked)
    }

    /// resetTimer does not immediately lock.
    func testResetTimerDoesNotImmediatelyLock() {
        let manager = AutoLockManager()
        manager.resetTimer()
        XCTAssertFalse(manager.isLocked)
    }

    /// Req 12.5: Foreground return (cancelAcceleratedTimer) resumes standard timer.
    func testBackgroundForegroundTransition() {
        let manager = AutoLockManager()
        // Simulate background entry
        manager.startAcceleratedTimer()
        XCTAssertFalse(manager.isLocked)

        // Simulate foreground return before accelerated timer fires
        manager.cancelAcceleratedTimer()
        XCTAssertFalse(manager.isLocked, "Should not be locked after returning to foreground")
    }
}



// MARK: - ClipboardManager Tests

/// Validates: Requirements 16.2
@available(macOS 14.0, iOS 17.0, *)
@MainActor
final class ClipboardManagerTests: XCTestCase {

    /// Expiration interval is 30 seconds.
    func testExpirationIntervalIs30Seconds() {
        XCTAssertEqual(ClipboardManager.expirationInterval, 30)
    }

    /// copySensitive sets lastCopyDate.
    func testCopySensitiveSetsLastCopyDate() {
        let cm = ClipboardManager()
        XCTAssertNil(cm.lastCopyDate)

        cm.copySensitive("secret123")

        XCTAssertNotNil(cm.lastCopyDate)
    }

    /// copySensitive marks the copy as local-only.
    func testCopySensitiveSetsLocalOnly() {
        let cm = ClipboardManager()
        cm.copySensitive("secret123")
        XCTAssertTrue(cm.lastCopyLocalOnly)
    }

    /// copySensitive sets an expiration date ~30 seconds in the future.
    func testCopySensitiveSetsExpirationDate() {
        let cm = ClipboardManager()
        let before = Date()
        cm.copySensitive("secret123")
        let after = Date()

        guard let expiration = cm.lastCopyExpirationDate, let copyDate = cm.lastCopyDate else {
            XCTFail("Expected expiration and copy dates to be set")
            return
        }

        let interval = expiration.timeIntervalSince(copyDate)
        XCTAssertEqual(interval, 30, accuracy: 1.0, "Expiration should be ~30 seconds after copy")
        XCTAssertGreaterThanOrEqual(expiration, before.addingTimeInterval(30 - 1))
        XCTAssertLessThanOrEqual(expiration, after.addingTimeInterval(30 + 1))
    }

    /// Req 16.2: clearIfExpired does nothing when no copy has been made.
    func testClearIfExpiredNoCopy() {
        let cm = ClipboardManager()
        cm.clearIfExpired()
        // No crash, no state change
        XCTAssertNil(cm.lastCopyDate)
    }

    /// Req 16.2: clearIfExpired does not clear before 30 seconds.
    func testClearIfExpiredBeforeInterval() {
        let cm = ClipboardManager()
        cm.copySensitive("secret123")
        // Immediately call clearIfExpired — should NOT clear since <30s elapsed
        cm.clearIfExpired()
        XCTAssertNotNil(cm.lastCopyDate, "Should not clear before expiration interval")
    }

    /// Password field defaults to masked (isPasswordVisible = false).
    func testPasswordFieldDefaultsMasked() {
        let mock = MockAPIClient()
        let vm = EntryDetailViewModel(apiClient: mock)
        XCTAssertFalse(vm.isPasswordVisible)
    }

    /// togglePasswordVisibility flips the visibility state.
    func testTogglePasswordVisibility() {
        let mock = MockAPIClient()
        let vm = EntryDetailViewModel(apiClient: mock)
        XCTAssertFalse(vm.isPasswordVisible)

        vm.togglePasswordVisibility()
        XCTAssertTrue(vm.isPasswordVisible)

        vm.togglePasswordVisibility()
        XCTAssertFalse(vm.isPasswordVisible)
    }
}


// MARK: - NavigationRouter Tests

/// Validates: Requirements 13.2, 13.3
@available(macOS 14.0, iOS 17.0, *)
@MainActor
final class NavigationRouterTests: XCTestCase {

    /// Initial state: no vault or entry selected, empty path.
    func testInitialState() {
        let router = NavigationRouter()
        XCTAssertNil(router.selectedVaultId)
        XCTAssertNil(router.selectedEntryId)
        XCTAssertTrue(router.path.isEmpty)
    }

    /// navigateToVault sets selectedVaultId and clears selectedEntryId.
    func testNavigateToVault() {
        let router = NavigationRouter()
        router.navigateToVault("vault-1")
        XCTAssertEqual(router.selectedVaultId, "vault-1")
        XCTAssertNil(router.selectedEntryId)
    }

    /// navigateToEntry sets selectedEntryId within the current vault.
    func testNavigateToEntry() {
        let router = NavigationRouter()
        router.navigateToVault("vault-1")
        router.navigateToEntry("entry-1")
        XCTAssertEqual(router.selectedVaultId, "vault-1")
        XCTAssertEqual(router.selectedEntryId, "entry-1")
    }

    /// Navigating to a different vault clears the previous entry selection.
    func testNavigateToNewVaultClearsEntry() {
        let router = NavigationRouter()
        router.navigateToVault("vault-1")
        router.navigateToEntry("entry-1")
        router.navigateToVault("vault-2")
        XCTAssertEqual(router.selectedVaultId, "vault-2")
        XCTAssertNil(router.selectedEntryId)
    }

    /// returnToVaultList clears all selection state and resets path.
    func testReturnToVaultList() {
        let router = NavigationRouter()
        router.navigateToVault("vault-1")
        router.navigateToEntry("entry-1")

        router.returnToVaultList()

        XCTAssertNil(router.selectedVaultId)
        XCTAssertNil(router.selectedEntryId)
        XCTAssertTrue(router.path.isEmpty)
    }

    /// popToRoot behaves the same as returnToVaultList.
    func testPopToRoot() {
        let router = NavigationRouter()
        router.navigateToVault("vault-1")
        router.navigateToEntry("entry-1")

        router.popToRoot()

        XCTAssertNil(router.selectedVaultId)
        XCTAssertNil(router.selectedEntryId)
        XCTAssertTrue(router.path.isEmpty)
    }

    /// Req 13.5: vaultLocked notification resets navigation.
    func testVaultLockedNotificationResetsNavigation() {
        let router = NavigationRouter()
        router.navigateToVault("vault-1")
        router.navigateToEntry("entry-1")

        // Post the notification that AutoLockManager sends on lock
        NotificationCenter.default.post(name: .vaultLocked, object: nil)

        // Give the notification handler a moment to execute on main queue
        let expectation = expectation(description: "Navigation reset")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertNil(router.selectedVaultId)
        XCTAssertNil(router.selectedEntryId)
        XCTAssertTrue(router.path.isEmpty)
    }
}


// MARK: - Biometric Unlock Tests

/// Validates: Requirements 15.1, 15.5
@available(macOS 14.0, iOS 17.0, *)
@MainActor
final class BiometricUnlockTests: XCTestCase {

    private var mockAPI: MockAPIClient!
    private var mockKeychain: MockKeychainStore!
    private var mockBiometric: MockBiometricAuthenticator!

    override func setUp() {
        super.setUp()
        mockAPI = MockAPIClient()
        mockKeychain = MockKeychainStore()
        mockBiometric = MockBiometricAuthenticator()
    }

    /// Req 15.1: Enable biometric stores hash in keychain with biometric protection.
    func testEnableBiometricStoresHash() throws {
        let vm = VaultDetailViewModel(apiClient: mockAPI, keychainStore: mockKeychain, biometricAuthenticator: mockBiometric)

        try vm.enableBiometric(vaultId: "v1", masterPasswordHash: "hash123")

        XCTAssertTrue(vm.isBiometricEnabled(vaultId: "v1"))
        let stored = try mockKeychain.loadMasterPasswordHash(vaultId: "v1")
        XCTAssertEqual(stored, "hash123")
    }

    /// Req 15.1: Disable biometric removes hash from keychain.
    func testDisableBiometricRemovesHash() throws {
        let vm = VaultDetailViewModel(apiClient: mockAPI, keychainStore: mockKeychain, biometricAuthenticator: mockBiometric)

        try vm.enableBiometric(vaultId: "v1", masterPasswordHash: "hash123")
        XCTAssertTrue(vm.isBiometricEnabled(vaultId: "v1"))

        try vm.disableBiometric(vaultId: "v1")

        XCTAssertFalse(vm.isBiometricEnabled(vaultId: "v1"))
        let stored = try mockKeychain.loadMasterPasswordHash(vaultId: "v1")
        XCTAssertNil(stored)
    }

    /// Successful biometric unlock opens the vault.
    func testBiometricUnlockSuccess() async throws {
        let vault = DecryptedVault(id: "v1", name: "Test", entries: [])
        mockAPI.openVaultResult = vault
        try mockKeychain.saveMasterPasswordHash("hash123", vaultId: "v1", biometricProtected: true)
        mockBiometric.canEvaluate = true
        mockBiometric.evaluateResult = true

        let vm = VaultDetailViewModel(apiClient: mockAPI, keychainStore: mockKeychain, biometricAuthenticator: mockBiometric)
        await vm.openVaultBiometric(id: "v1")

        XCTAssertNotNil(vm.vault)
        XCTAssertEqual(vm.vault?.id, "v1")
        XCTAssertFalse(vm.showMasterPasswordFallback)
        XCTAssertNil(vm.error)
    }

    /// Req 15.5: Biometric failure falls back to password prompt.
    func testBiometricFailureFallsBackToPassword() async throws {
        try mockKeychain.saveMasterPasswordHash("hash123", vaultId: "v1", biometricProtected: true)
        mockBiometric.canEvaluate = true
        mockBiometric.evaluateResult = false  // Biometric fails

        let vm = VaultDetailViewModel(apiClient: mockAPI, keychainStore: mockKeychain, biometricAuthenticator: mockBiometric)
        await vm.openVaultBiometric(id: "v1")

        XCTAssertNil(vm.vault)
        XCTAssertTrue(vm.showMasterPasswordFallback, "Should fall back to password prompt on biometric failure")
    }

    /// Biometric not available falls back to password prompt.
    func testBiometricNotAvailableFallsBack() async throws {
        try mockKeychain.saveMasterPasswordHash("hash123", vaultId: "v1", biometricProtected: true)
        mockBiometric.canEvaluate = false  // Biometric not available

        let vm = VaultDetailViewModel(apiClient: mockAPI, keychainStore: mockKeychain, biometricAuthenticator: mockBiometric)
        await vm.openVaultBiometric(id: "v1")

        XCTAssertNil(vm.vault)
        XCTAssertTrue(vm.showMasterPasswordFallback)
    }

    /// No biometric hash configured falls back to password prompt.
    func testNoBiometricConfiguredFallsBack() async {
        // No hash stored — biometric not enabled for this vault
        let vm = VaultDetailViewModel(apiClient: mockAPI, keychainStore: mockKeychain, biometricAuthenticator: mockBiometric)
        await vm.openVaultBiometric(id: "v1")

        XCTAssertNil(vm.vault)
        XCTAssertTrue(vm.showMasterPasswordFallback)
    }

    /// API error during biometric unlock sets error and falls back.
    func testBiometricUnlockAPIErrorFallsBack() async throws {
        try mockKeychain.saveMasterPasswordHash("hash123", vaultId: "v1", biometricProtected: true)
        mockBiometric.canEvaluate = true
        mockBiometric.evaluateResult = true
        mockAPI.openVaultError = APIError(status: 401, code: "invalid", message: "Bad hash", details: nil)

        let vm = VaultDetailViewModel(apiClient: mockAPI, keychainStore: mockKeychain, biometricAuthenticator: mockBiometric)
        await vm.openVaultBiometric(id: "v1")

        XCTAssertNil(vm.vault)
        XCTAssertNotNil(vm.error)
        XCTAssertTrue(vm.showMasterPasswordFallback)
    }

    /// isBiometricEnabled returns false for unconfigured vault.
    func testIsBiometricEnabledFalseByDefault() {
        let vm = VaultDetailViewModel(apiClient: mockAPI, keychainStore: mockKeychain, biometricAuthenticator: mockBiometric)
        XCTAssertFalse(vm.isBiometricEnabled(vaultId: "v1"))
    }
}
