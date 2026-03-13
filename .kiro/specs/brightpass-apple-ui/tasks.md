# Implementation Plan: BrightPass Apple UI

## Overview

Incremental implementation of the BrightPass Apple UI as a Swift Package with a shared `BrightPassKit` library and platform-specific SwiftUI app targets. Tasks build from foundational data models and service layer up through view models and views, with property-based and unit tests woven in alongside each component. All code is Swift targeting iOS 17+ and macOS 13+. Authentication uses the ECIES direct challenge flow (two-step passwordless login with mnemonic-derived secp256k1 keys), leveraging existing crypto primitives from the brightchain-apple package.

## Tasks

- [ ] 1. Set up Swift Package structure and foundational types
  - [x] 1.1 Create the Swift Package with `BrightPassKit` library target, iOS app target, macOS app target, and `BrightPassKitTests` test target
    - Define `Package.swift` with platform support for macOS 13+ and iOS 17+
    - Add SwiftCheck (0.12.0+) as a test dependency
    - Create directory structure: `Sources/BrightPassKit/`, `Sources/BrightPassiOS/`, `Sources/BrightPassmacOS/`, `Tests/BrightPassKitTests/PropertyTests/`, `Tests/BrightPassKitTests/UnitTests/`
    - _Requirements: 18.1, 18.2, 18.3, 18.4, 18.5_

  - [x] 1.2 Implement all Codable data models in `BrightPassKit`
    - Create `VaultMetadata`, `DecryptedVault`, `EntryType`, `EntryPropertyRecord`, `VaultEntry`, `EntryFields` (discriminated union with custom Codable), `LoginFields`, `SecureNoteFields`, `CreditCardFields`, `IdentityDocumentFields`
    - Create `GeneratedPassword`, `PasswordOptions`, `TotpCode`, `BreachCheckResult`, `AutofillPayload`, `AuditLogEntry`, `SharedMember`, `SharePermission`, `EmergencyAccessConfig`, `ImportResult`, `ImportSource`, `AuthToken`, `APIError`
    - Create `RecentEntryReference`, `DuplicatePasswordResult`, `PasswordStrengthLevel`, `SortOption`, `ExportFormat`, `AppearanceMode`
    - All models conform to `Codable`, `Equatable`, and `Identifiable` where applicable
    - Configure shared `JSONEncoder`/`JSONDecoder` with `.iso8601` date strategy
    - _Requirements: 1.5, 1.7, 19.1, 19.3, 24.1, 25.2, 27.1, 29.1, 30.3, 31.1_

  - [x] 1.3 Write property tests for JSON round-trip (Property 1)
    - **Property 1: JSON Serialization Round-Trip**
    - Implement custom `Arbitrary` conformances for all Codable model types
    - Verify encode-then-decode produces equal value for every model type
    - **Validates: Requirements 1.7, 19.2**

  - [x] 1.4 Write property test for malformed JSON (Property 4)
    - **Property 4: Malformed JSON Throws DecodingError**
    - For each model type, generate JSON payloads with missing required fields and verify `DecodingError` is thrown
    - **Validates: Requirements 19.4**

- [x] 2. Implement service layer — ErrorMapper, ConfigurationManager, KeychainStore
  - [x] 2.1 Implement `AppError` enum and `ErrorMapper`
    - Create `AppError` with cases: `.networkUnavailable`, `.sessionExpired`, `.validationError`, `.serverError`, `.decodingFailure`, `.unknown`
    - Implement `isRetryable` and `userMessage` computed properties
    - Implement `ErrorMapper.map(_:)` with URLError, APIError, and DecodingError handling
    - _Requirements: 17.1, 17.2, 17.3, 17.4_

  - [x] 2.2 Write property tests for error mapping (Properties 26, 27)
    - **Property 26: HTTP Error Mapping Produces Correct Category**
    - **Property 27: Recoverable Errors Are Retryable**
    - Generate random URLError codes and APIError statuses, verify correct AppError classification and retryable flag
    - **Validates: Requirements 17.1, 17.2, 17.3, 17.4**

  - [x] 2.3 Implement `ConfigurationManager`
    - `@Observable` class with `baseURL` property
    - Support `.development` (localhost:8080) and `.production` (brightchain.org) environments
    - _Requirements: 1.4_

  - [x] 2.4 Implement `KeychainStoreProtocol` and `KeychainStore`
    - Define protocol with JWT and master password hash CRUD methods
    - Implement using Security framework (`SecItemAdd`, `SecItemCopyMatching`, `SecItemDelete`)
    - Biometric-protected items use `SecAccessControlCreateWithFlags` with `.biometryCurrentSet`
    - Shared Keychain access group for main app and AutoFill extension
    - _Requirements: 12.7, 12.8, 15.2, 15.6_

  - [x] 2.5 Write property test for biometric disable removes hash (Property 24)
    - **Property 24: Biometric Disable Removes Stored Hash**
    - Using `MockKeychainStore`, verify that after saving then deleting a master password hash, `loadMasterPasswordHash` returns nil
    - **Validates: Requirements 15.6**

  - [x] 2.6 Write unit tests for KeychainStore
    - Test store/load/delete JWT token flow
    - Test biometric access control flag configuration
    - Test shared access group setup
    - _Requirements: 12.7, 12.8_

- [-] 3. Implement APIClient
  - [x] 3.1 Implement `APIClientProtocol` and `APIClient`
    - Define protocol with all async methods (auth direct challenge, auth password fallback, registration, vaults, vault rename, entries, password generation, TOTP, breach check, autofill, audit log, sharing, emergency access, import, master password change, export)
    - Include `requestDirectLogin()`, `submitDirectChallenge(challenge:signature:username:)`, `refreshToken()`, `logout()`, `verifyToken()` for ECIES direct challenge auth
    - Include `login(username:password:)`, `register(username:email:password:)` as password-based fallback endpoints
    - Include `renameVault(id:name:)`, `changeMasterPassword(vaultId:currentPassword:newPassword:)`, `exportEntries(vaultId:format:)` endpoints
    - Implement concrete `APIClient` with `URLSession`, base URL from `ConfigurationManager`, JWT from `KeychainStore`
    - All endpoints prefixed with appropriate API paths (e.g., `/api/user` for auth)
    - Attach Bearer token to every request's Authorization header
    - On 401 response: clear JWT via `KeychainStore.deleteJWT()`, post `.sessionExpired` notification
    - Map non-2xx responses to `APIError` via `ErrorMapper`
    - Use shared `JSONDecoder` with `.iso8601` date strategy
    - _Requirements: 1.1, 1.2, 1.3, 1.5, 1.6, 20.2, 20.9, 21.3, 22.3, 23.3, 25.3_

  - [x] 3.2 Implement `MockURLProtocol` for test infrastructure
    - Create custom `URLProtocol` subclass for intercepting and stubbing HTTP requests in tests
    - Support configurable response status codes and JSON bodies
    - _Requirements: 1.1_

  - [x] 3.3 Write property tests for APIClient (Properties 2, 3)
    - **Property 2: JWT Bearer Token Attachment**
    - **Property 3: API Error Decoding Preserves Fields**
    - Verify every request includes correct Authorization header for any JWT string
    - Verify APIError JSON round-trip preserves all fields
    - **Validates: Requirements 1.2, 1.6**

  - [x] 3.4 Write unit tests for APIClient
    - Test 401 handling clears JWT and posts notification
    - Test base URL configuration for dev/prod
    - Test network timeout produces `.networkUnavailable` error
    - Test malformed JSON response produces `.decodingFailure`
    - _Requirements: 1.3, 1.4, 1.6_

- [x] 4. Checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [-] 5. Implement vault management view model and views
  - [x] 5.1 Implement `VaultListViewModel`
    - `@Observable` class with `vaults`, `isLoading`, `error` properties
    - `loadVaults()` fetches from API and populates list
    - `createVault()` appends new vault to list without full refresh on success
    - `deleteVault()` removes vault from list by ID on success
    - _Requirements: 2.1, 2.2, 2.3, 2.7, 2.8_

  - [x] 5.2 Write property tests for vault management (Properties 5, 6)
    - **Property 5: Vault Creation Adds to List**
    - **Property 6: Vault Deletion Removes from List**
    - Verify list count increases by one after creation and decreases by one after deletion
    - **Validates: Requirements 2.2, 2.8**

  - [x] 5.3 Implement `VaultDetailViewModel`
    - `@Observable` class with `vault`, `entries`, `searchQuery`, `typeFilter`, `favoritesOnly`, `isLoading`, `error`
    - `openVault()` and `openVaultBiometric()` for vault unlock
    - `searchEntries()` sends query to API
    - `filterEntries()` applies local type and favorite filters with AND logic
    - `lockVault()` clears all decrypted data and state
    - `deleteEntry()` and `refreshEntries()`
    - _Requirements: 2.4, 2.5, 2.6, 4.1, 4.2, 4.3, 4.4, 4.5, 4.6_

  - [x] 5.4 Write property tests for search and filter (Properties 10, 11)
    - **Property 10: Search Results Match Query**
    - **Property 11: Filter Results Satisfy Predicate**
    - Verify all search results contain query substring; verify filter results match type and favorite predicate
    - **Validates: Requirements 4.3, 4.4, 4.5**

  - [x] 5.5 Write property test for lock clears data (Property 19)
    - **Property 19: Lock Clears All Decrypted Data**
    - Verify vault is nil, entries is empty, searchQuery is empty after `lockVault()`
    - **Validates: Requirements 12.1, 12.6**

  - [x] 5.6 Implement `VaultListView` (iOS) and vault list sidebar (macOS)
    - iOS: `NavigationStack`-based list with pull-to-refresh, vault name/entry count/last modified
    - macOS: Sidebar column in `NavigationSplitView`
    - Create vault button, delete with confirmation dialog
    - _Requirements: 2.1, 2.3, 2.7, 13.2, 13.3_

  - [x] 5.7 Implement `MasterPasswordPromptView`
    - Sheet for master password input
    - Biometric option when enabled for the vault
    - Error display for incorrect password
    - _Requirements: 2.4, 2.6, 15.3, 15.5_

  - [x] 5.8 Implement `VaultDetailView` with search and filter
    - Entry list with search bar at top
    - Type filter chips and favorite toggle
    - Clear search restores full list
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6_

- [-] 6. Implement entry CRUD view models and views
  - [x] 6.1 Implement `EntryDetailViewModel`
    - `@Observable` class with `entry`, `isEditing`, `isPasswordVisible`, `isLoading`, `error`
    - `loadEntry()`, `saveEntry()`, `deleteEntry()`
    - Password masking with toggle
    - _Requirements: 3.8, 3.9, 3.10, 16.4_

  - [x] 6.2 Write property tests for entry management (Properties 7, 8, 9)
    - **Property 7: Entry Creation Adds to List**
    - **Property 8: Entry Update Reflects Changes**
    - **Property 9: Entry Deletion Removes from List**
    - Verify list count changes and field updates after CRUD operations
    - **Validates: Requirements 3.7, 3.9, 3.10**

  - [x] 6.3 Implement `EntryDetailView`
    - Display full entry details with masked password fields and reveal toggle
    - Copy actions for password and other sensitive fields
    - Edit and delete actions with confirmation dialog for delete
    - _Requirements: 3.8, 3.10, 16.4_

  - [x] 6.4 Implement `EntryFormView` with type-specific forms
    - Login: site URL, username, password, optional TOTP secret, tags, favorite toggle
    - Credit card: cardholder name, card number, expiration, CVV, tags, favorite
    - Secure note: title, encrypted text content, tags, favorite
    - Identity document: name, email, phone, address, custom fields, tags, favorite
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_

  - [x] 6.5 Write unit tests for entry management
    - Test type-specific form field validation
    - Test CRUD edge cases (empty fields, duplicate entries)
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_

- [x] 7. Checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [-] 8. Implement password generator, TOTP, and breach check
  - [x] 8.1 Implement `PasswordGeneratorViewModel`
    - `@Observable` class with length (clamped 8–128), character set toggles, minimum counts
    - `generate()` calls API and stores result
    - `options` computed property builds `PasswordOptions`
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

  - [x] 8.2 Write property tests for password generator (Properties 12, 13)
    - **Property 12: Generated Password Length Matches Options**
    - **Property 13: Generated Password Respects Character Constraints**
    - Verify length and character set constraints for randomly generated options
    - **Validates: Requirements 5.2, 5.3, 5.4**

  - [x] 8.3 Implement `PasswordGeneratorView`
    - Length slider, character set toggles, minimum count steppers
    - Generate button, copy to clipboard action
    - "Use Password" action when accessed from entry form
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7_

  - [x] 8.4 Implement `TOTPViewModel` and `TOTPDisplayView`
    - `@Observable` class with `currentCode`, `remainingSeconds`, refresh task
    - `startCodeGeneration()` requests code from API, starts countdown, auto-refreshes on expiry
    - `stopCodeGeneration()` cancels refresh task
    - `copyCode()` copies via `ClipboardManager`
    - View shows 6-digit code with countdown ring animation
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_

  - [xc] 8.5 Write property test for TOTP code format (Property 14)
    - **Property 14: TOTP Code Format**
    - Verify code is exactly 6 decimal digit characters
    - **Validates: Requirements 6.1**

  - [x] 8.6 Implement `BreachCheckViewModel` and `BreachCheckView`
    - `@Observable` class with `result`, `isLoading`, `error`
    - `checkPassword()` calls API breach-check endpoint
    - View shows breach count with warning or safe confirmation
    - Loading indicator while request is in progress
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

  - [x] 8.7 Write unit tests for password generator, TOTP, and breach check
    - Test boundary lengths (8, 128), all-toggles-off edge case
    - Test TOTP timer expiry and invalid secret validation
    - Test breached/not-breached display states and loading indicator
    - _Requirements: 5.2, 6.1, 6.2, 7.3, 7.4, 7.5_

- [x] 9. Implement sharing, emergency access, import, and audit log
  - [x] 9.1 Implement `ShareVaultViewModel` and `ShareVaultView`
    - `@Observable` class with `sharedMembers`, `isLoading`, `error`
    - `loadSharedMembers()`, `shareVault()`, `revokeAccess()` (removes member from list on success)
    - View: share form with member ID and permission level, member list with revoke action
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

  - [x] 9.2 Write property test for revoke share (Property 15)
    - **Property 15: Revoke Share Removes Member**
    - Verify shared member list no longer contains revoked member
    - **Validates: Requirements 8.5**

  - [x] 9.3 Implement `EmergencyAccessViewModel` and `EmergencyAccessView`
    - `@Observable` class with `config`, `isLoading`, `error`
    - `loadConfig()`, `configure()`, `recover()` (validates share count >= threshold before API call)
    - View: configuration form (N shares, T threshold), recovery share input, config display
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7_

  - [x] 9.4 Write property test for insufficient shares (Property 16)
    - **Property 16: Insufficient Shares Produces Error**
    - Verify recovery with fewer than T shares produces error without API call
    - **Validates: Requirements 9.7**

  - [x] 9.5 Implement `ImportViewModel` and `ImportView`
    - `@Observable` class with `selectedSource`, `result`, `isLoading`, `error`
    - `importFile()` sends file to API import endpoint
    - View: source selection (1Password, LastPass, Bitwarden, Chrome, Firefox, KeePass, Dashlane), file picker, result summary
    - Refresh entry list after successful import
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_

  - [x] 9.6 Implement `AuditLogViewModel` and `AuditLogView`
    - `@Observable` class with `entries`, `isLoading`, `error`
    - `loadAuditLog()` fetches and sorts by timestamp descending
    - View: scrollable list showing action, member ID, timestamp, metadata
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5_

  - [x] 9.7 Write property tests for audit log (Properties 17, 18)
    - **Property 17: Audit Log Entries Contain Required Fields**
    - **Property 18: Audit Log Reverse Chronological Order**
    - Verify non-empty required fields and descending timestamp order
    - **Validates: Requirements 11.3, 11.4**

  - [x] 9.8 Write unit tests for sharing, emergency access, import, and audit log
    - Test share/revoke confirmation flows
    - Test emergency access config display and recovery success
    - Test each import source format and error summary
    - Test empty audit log and metadata display
    - _Requirements: 8.3, 8.5, 9.3, 9.6, 10.2, 10.4, 11.3_

- [x] 10. Checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [-] 11. Implement auto-lock, clipboard, biometric unlock, and navigation
  - [x] 11.1 Implement `AutoLockManager`
    - `@Observable` class with `timeoutMinutes` (default 15, clamped 1–60), `isLocked`
    - `resetTimer()` resets inactivity timer on user interaction
    - `startAcceleratedTimer()` on iOS background (5-minute timer)
    - `cancelAcceleratedTimer()` on foreground return
    - `lock()` sets `isLocked = true`, posts `.vaultLocked` notification
    - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5, 12.6_

  - [x] 11.2 Write property test for auto-lock timeout range (Property 20)
    - **Property 20: Auto-Lock Timeout Range Validation**
    - Verify any integer assigned to `timeoutMinutes` is clamped to [1, 60]
    - **Validates: Requirements 12.3**

  - [x] 11.3 Implement `ClipboardManager`
    - `copySensitive()` sets clipboard with `localOnly = true` and 30-second expiration on iOS
    - macOS: `NSPasteboard` with `DispatchSourceTimer` for 30-second cleanup
    - `clearIfExpired()` for manual cleanup
    - _Requirements: 16.1, 16.2, 16.3_

  - [x] 11.4 Write property test for clipboard expiration (Property 25)
    - **Property 25: Clipboard Sensitive Copy Sets Expiration**
    - Verify clipboard item is configured with `localOnly = true` and ~30-second expiration
    - **Validates: Requirements 16.1**

  - [x] 11.5 Implement `NavigationRouter`
    - `@Observable` class with `selectedVaultId`, `selectedEntryId`, `path`
    - `navigateToVault()`, `navigateToEntry()`, `returnToVaultList()`, `popToRoot()`
    - `returnToVaultList()` clears all selection state and resets path on vault lock
    - _Requirements: 13.1, 13.4, 13.5_

  - [x] 11.6 Write property test for lock resets navigation (Property 21)
    - **Property 21: Lock Resets Navigation to Vault List**
    - Verify `selectedVaultId` is nil, `selectedEntryId` is nil, and path is empty after lock
    - **Validates: Requirements 13.5**

  - [x] 11.7 Implement biometric unlock flow in `VaultDetailViewModel`
    - Check if biometric is enabled for vault via `KeychainStore`
    - Call `LAContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics)`
    - On success: retrieve stored hash, open vault via API
    - On failure: fall back to `MasterPasswordPromptView`
    - Enable/disable biometric per vault in settings
    - _Requirements: 15.1, 15.2, 15.3, 15.4, 15.5, 15.6_

  - [x] 11.8 Write unit tests for auto-lock, clipboard, navigation, and biometric
    - Test default timeout (15 min), background/foreground transitions
    - Test 30-second clipboard expiry and masked field toggle
    - Test platform-specific navigation and breadcrumb titles
    - Test biometric enable/disable flow and fallback to password
    - _Requirements: 12.1, 12.2, 12.4, 12.5, 13.2, 13.3, 15.1, 15.5, 16.2_

- [x] 12. Implement autofill credential provider extension
  - [x] 12.1 Create AutoFill Credential Provider extension target
    - Implement `CredentialProviderViewController` as `ASCredentialProviderViewController` subclass
    - Register via `com.apple.authentication-services-credential-provider-extension` entitlement
    - Share Keychain access group with main app for JWT token access
    - _Requirements: 14.1_

  - [x] 12.2 Implement autofill lookup and credential selection
    - Receive service identifiers from system, query API via `APIClient.autofillLookup()`
    - Display minimal credential picker list (title + username) if matches found
    - Provide `ASPasswordCredential(user:, password:)` on selection
    - Display "No saved credentials match" message if no matches
    - _Requirements: 14.2, 14.3, 14.4, 14.5_

  - [x] 12.3 Write property tests for autofill (Properties 22, 23)
    - **Property 22: Autofill Returns URL-Matching Entries**
    - **Property 23: Autofill Payload Contains Correct Credentials**
    - Verify returned entries match service identifier URL and contain non-empty username/password
    - **Validates: Requirements 14.2, 14.4**

  - [x] 12.4 Write unit tests for autofill provider
    - Test no-match message display
    - Test credential selection flow
    - _Requirements: 14.3, 14.5_

- [x] 13. Wire platform-specific navigation and adaptive layout
  - [x] 13.1 Implement `MainSplitView` for macOS with `NavigationSplitView`
    - Sidebar: vault list, Content: entry list, Detail: entry detail
    - Breadcrumb/navigation title reflecting current position
    - _Requirements: 13.2, 13.4, 13.6_

  - [x] 13.2 Wire iOS `NavigationStack` with push/pop navigation
    - Three-level hierarchy: vault list → vault detail → entry detail
    - Navigation title reflecting current position
    - _Requirements: 13.1, 13.3, 13.4, 13.6_

  - [x] 13.3 Implement `SettingsView`
    - Auto-lock timeout slider (1–60 minutes)
    - Biometric toggle per vault
    - API environment picker (dev/prod)
    - _Requirements: 12.3, 15.1, 1.4_

  - [x] 13.4 Implement error presentation layer
    - Inline validation errors on forms
    - Dismissible banner for network/server errors with retry button for retryable errors
    - Modal sheet for session expiration with login flow
    - Loading indicators: inline `ProgressView` for actions, full-screen overlay for vault unlock
    - _Requirements: 17.1, 17.2, 17.3, 17.4, 17.5_

- [-] 14. Implement authentication and registration
  - [x] 14.1 Port `SDKWrapperProtocol`, `KeyringProtocol`, and `SimpleKeyring` into BrightPassKit
    - Copy `SDKWrapperProtocol` (mnemonic validation, key derivation, signing) from brightchain-apple
    - Copy `KeyringProtocol` and `SimpleKeyring` (AES-GCM key encryption via Keychain) from brightchain-apple
    - Copy `FallbackSDKWrapper` (pure Swift BIP39/P256 implementation) from brightchain-apple
    - Add `MemberResult` struct to BrightPassKit
    - _Requirements: 20.2, 20.7, 20.8_

  - [x] 14.2 Add direct challenge auth models to BrightPassKit
    - Create `DirectLoginChallenge`, `DirectChallengeResponse`, `UserProfile`, `AuthResponse`, `AuthResponseData` Codable structs
    - Add `requestDirectLogin()`, `submitDirectChallenge()`, `refreshToken()`, `logout()`, `verifyToken()` to `APIClientProtocol`
    - Add `register(username:email:password:)` and `login(username:password:)` as fallback methods
    - Update `KeychainStoreProtocol` with `saveEncryptedPrivateKey`, `loadEncryptedPrivateKey`, `deleteEncryptedPrivateKey`
    - _Requirements: 20.2, 20.3, 20.8, 20.9_

  - [x] 14.3 Implement `AuthViewModel` with ECIES direct challenge flow
    - `@Observable` class with `username`, `mnemonic`, `isLoading`, `error`, `isAuthenticated`, `isMnemonicValid`
    - `login()` executes: validate mnemonic → derive keys → request challenge → sign challenge → submit → store JWT + encrypted private key
    - `logout()` clears JWT, encrypted private key, posts `.sessionExpired` notification
    - `validateMnemonic()` updates `isMnemonicValid` on every keystroke
    - `refreshTokenIfNeeded()` checks JWT expiry and refreshes if within 1 day
    - Observe `Notification.Name.sessionExpired` to handle 401-triggered logouts
    - _Requirements: 20.2, 20.3, 20.5, 20.6, 20.7, 20.9_

  - [x] 14.4 Implement `LoginView`
    - Username (or email) input field and mnemonic phrase text area with "Log In" button
    - Real-time mnemonic validation indicator (12 BIP39 words check)
    - Display error message on authentication failure with retry
    - "Don't have an account? Register" link navigating to `RegistrationView`
    - _Requirements: 20.1, 20.4, 20.7_

  - [x] 14.5 Write property test for successful authentication stores JWT and keys (Property 28)
    - **Property 28: Successful Authentication Stores JWT and Keys**
    - Verify that after a successful direct challenge login, the JWT is stored in `KeychainStore`, the encrypted private key is stored, and `isAuthenticated` is `true`
    - **Validates: Requirements 20.3, 20.8**

  - [x] 14.6 Write property test for logout clears JWT, keys, and resets navigation (Property 29)
    - **Property 29: Logout Clears JWT, Keys, and Resets Navigation**
    - Verify that after `logout()`, `KeychainStore.loadJWT()` returns nil, `loadEncryptedPrivateKey(memberId:)` returns nil, `isAuthenticated` is `false`, and `NavigationRouter` has nil selections
    - **Validates: Requirements 20.5**

  - [x] 14.7 Implement `RegistrationViewModel`
    - `@Observable` class with `username`, `email`, `password`, `confirmPassword`, `passwordStrength`, `isLoading`, `error`, `fieldErrors`, `generatedMnemonic`, `hasSavedMnemonic`
    - `register()` validates password match, sends `POST /api/user/register`, generates mnemonic, derives keys, displays mnemonic
    - `confirmMnemonicSaved()` completes registration by storing JWT and encrypted private key
    - `evaluatePasswordStrength()` delegates to `PasswordStrengthEvaluator`
    - _Requirements: 21.1, 21.2, 21.3, 21.4, 21.5, 21.7_

  - [x] 14.8 Implement `RegistrationView`
    - Username, email, password, and confirm password fields with "Create Account" button
    - Real-time `PasswordStrengthMeterView` next to password field
    - Mnemonic display step with "I have saved my mnemonic" confirmation
    - Display field-level validation errors from API response
    - "Already have an account? Log In" link navigating to `LoginView`
    - _Requirements: 21.1, 21.2, 21.5, 21.6, 21.7_

  - [x] 14.9 Write unit tests for authentication and registration
    - Test direct challenge login flow: mnemonic validation → key derivation → challenge request → signing → submission → JWT storage
    - Test login failure displays error and allows retry
    - Test logout clears JWT, encrypted private key, and resets navigation
    - Test registration with mismatched passwords shows field error
    - Test registration success generates mnemonic and requires confirmation
    - Test 401 notification triggers logout flow
    - Test mnemonic validation rejects invalid phrases
    - Test token refresh flow
    - _Requirements: 20.2, 20.3, 20.4, 20.5, 20.6, 20.7, 21.3, 21.4, 21.5, 21.7_

- [x] 15. Implement master password change and vault rename
  - [x] 15.1 Implement `MasterPasswordChangeViewModel`
    - `@Observable` class with `currentPassword`, `newPassword`, `confirmNewPassword`, `isLoading`, `error`, `isSuccess`
    - `changePassword(vaultId:)` validates `newPassword == confirmNewPassword` (sets validation error without API call if not), sends change request to `APIClient.changeMasterPassword(vaultId:currentPassword:newPassword:)`
    - On success with biometric enabled: updates stored hash in `KeychainStore` with new password hash, sets `isSuccess = true`
    - _Requirements: 22.1, 22.2, 22.3, 22.4, 22.5, 22.6_

  - [x] 15.2 Implement `MasterPasswordChangeView`
    - Form with current password, new password, and confirmation fields
    - Success confirmation display after password change
    - Error display for incorrect current password
    - _Requirements: 22.1, 22.2, 22.5_

  - [x] 15.3 Write property test for password change confirmation mismatch (Property 30)
    - **Property 30: Password Change Confirmation Mismatch Validation**
    - Verify that for any two non-equal password strings as new password and confirmation, the view model sets a validation error without making an API call
    - **Validates: Requirements 22.6**

  - [x] 15.4 Write property test for biometric hash update after password change (Property 31)
    - **Property 31: Biometric Hash Update After Password Change**
    - Verify that for a vault with biometric enabled, after a successful password change, the hash in `KeychainStore` corresponds to the new password
    - **Validates: Requirements 22.4**

  - [x] 15.5 Implement `VaultRenameViewModel`
    - `@Observable` class with `newName`, `isLoading`, `error`
    - `renameVault(vaultId:)` sends rename request to `APIClient.renameVault(id:name:)`
    - On success: optimistic UI update — modifies vault name in `VaultListViewModel.vaults` array and `VaultDetailViewModel.vault` without full refresh
    - _Requirements: 23.1, 23.2, 23.3, 23.4_

  - [x] 15.6 Implement `VaultRenameView`
    - Inline editing field or rename dialog pre-populated with current vault name
    - Accessible from vault detail view and context menu on vault list item
    - _Requirements: 23.1, 23.2_

  - [x] 15.7 Write property test for vault rename optimistic update (Property 32)
    - **Property 32: Vault Rename Optimistic Update**
    - Verify that after a successful rename, the vault's name in `VaultListViewModel.vaults` equals the new name and the array count is unchanged
    - **Validates: Requirements 23.4**

  - [x] 15.8 Write unit tests for master password change and vault rename
    - Test password change with mismatched confirmation shows error without API call
    - Test successful password change updates biometric hash
    - Test incorrect current password displays error
    - Test vault rename updates name in both vault list and vault detail
    - Test vault rename with empty name validation
    - _Requirements: 22.3, 22.4, 22.5, 22.6, 23.3, 23.4_

- [x] 16. Implement entry sorting and data export
  - [x] 16.1 Implement `EntrySortViewModel`
    - `@Observable` class with `selectedSort: SortOption` defaulting to `.nameAscending`
    - `sortEntries(_:)` applies the selected sort comparator to the entry list
    - Called after filtering in `VaultDetailViewModel.filterEntries()` so sort applies to filtered results
    - Session-scoped persistence (in-memory only)
    - _Requirements: 24.1, 24.2, 24.3, 24.4_

  - [x] 16.2 Add sort control to `VaultDetailView`
    - Sort picker/menu on the vault detail view with all `SortOption` cases
    - Wire sort selection to `EntrySortViewModel` and re-render entry list
    - _Requirements: 24.1, 24.2_

  - [x] 16.3 Write property test for sort order correctness on filtered entries (Property 33)
    - **Property 33: Sort Order Correctness on Filtered Entries**
    - Verify that for any list of entries, any filter, and any sort option, the result is both correctly filtered AND correctly sorted
    - **Validates: Requirements 24.2, 24.4**

  - [x] 16.4 Implement `ExportViewModel`
    - `@Observable` class with `selectedFormat: ExportFormat`, `exportedData`, `isLoading`, `error`
    - `exportEntries(vaultId:)` sends export request to `APIClient.exportEntries(vaultId:format:)`
    - On success: stores returned `Data` in `exportedData` for view layer to present save/share dialog
    - _Requirements: 25.1, 25.2, 25.3, 25.5_

  - [x] 16.5 Implement `ExportView`
    - Format picker (CSV/JSON) with export confirmation button
    - iOS: present `UIActivityViewController` share sheet with exported data
    - macOS: present `NSSavePanel` file save dialog with exported data
    - Error display on export failure
    - _Requirements: 25.1, 25.2, 25.4, 25.5_

  - [x] 16.6 Write unit tests for entry sorting and data export
    - Test each sort option produces correct ordering
    - Test sort applied after filter
    - Test CSV and JSON export format selection
    - Test export error display
    - _Requirements: 24.1, 24.2, 24.4, 25.2, 25.3, 25.5_

- [x] 17. Checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 18. Implement onboarding, theming, and favorites
  - [x] 18.1 Implement `OnboardingViewModel`
    - `@Observable` class with `currentStep`, `isOnboardingComplete`
    - `shouldShowOnboarding` reads `onboarding-complete` flag from `UserDefaults`
    - `nextStep()` advances the step, `skip()` and `completeOnboarding()` both set `UserDefaults` flag and `isOnboardingComplete = true`
    - _Requirements: 26.1, 26.2, 26.3, 26.4_

  - [x] 18.2 Implement `OnboardingView`
    - Multi-step welcome flow with vault/entry creation guidance
    - "Skip" action on each step to exit onboarding
    - Present only when `shouldShowOnboarding` is `true`
    - _Requirements: 26.1, 26.2, 26.3_

  - [x] 18.3 Write property test for onboarding flag round-trip (Property 34)
    - **Property 34: Onboarding Flag Round-Trip**
    - Verify that when `onboarding-complete` key is absent, `shouldShowOnboarding` returns `true`; after `completeOnboarding()` or `skip()`, the key is set and `shouldShowOnboarding` returns `false`
    - **Validates: Requirements 26.1, 26.4**

  - [x] 18.4 Implement `ThemeManager`
    - `@Observable` class with `selectedAppearance: AppearanceMode` defaulting to `.system`
    - Persists to `UserDefaults` on every change via `didSet`
    - `init()` reads stored preference from `UserDefaults`
    - `colorScheme` computed property maps to `ColorScheme?` (nil for system, `.light`, `.dark`)
    - Root view applies `.preferredColorScheme(themeManager.colorScheme)`
    - _Requirements: 27.1, 27.2, 27.3_

  - [x] 18.5 Add appearance picker to `SettingsView`
    - Three-option picker (System, Light, Dark) wired to `ThemeManager.selectedAppearance`
    - Ensure all views use semantic colors from asset catalog for correct adaptation
    - _Requirements: 27.2, 27.4_

  - [x] 18.6 Write property test for theme preference persistence round-trip (Property 35)
    - **Property 35: Theme Preference Persistence Round-Trip**
    - Verify that for any `AppearanceMode`, after setting it on `ThemeManager`, reading `appearance-mode` from `UserDefaults` and constructing an `AppearanceMode` produces the original mode
    - **Validates: Requirements 27.3**

  - [x] 18.7 Implement `FavoritesViewModel`
    - `@Observable` class with `favoriteEntries: [(vaultId: String, entry: EntryPropertyRecord)]`, `isLoading`, `error`
    - `loadFavorites(from:)` iterates entries from all unlocked vaults, filters `isFavorite == true`, stores with vault ID for navigation context
    - _Requirements: 28.1, 28.2, 28.3_

  - [x] 18.8 Implement `FavoritesView`
    - iOS: tab bar item showing aggregated favorites list
    - macOS: sidebar section below vault list
    - Tapping an entry navigates to entry detail within correct vault context
    - _Requirements: 28.1, 28.2, 28.3_

  - [x] 18.9 Write property test for favorites aggregation across unlocked vaults (Property 36)
    - **Property 36: Favorites Aggregation Across Unlocked Vaults**
    - Verify that `favoriteEntries` contains exactly the entries where `isFavorite == true` across all provided vaults, each associated with its correct vault ID
    - **Validates: Requirements 28.2**

  - [x] 18.10 Write unit tests for onboarding, theming, and favorites
    - Test first launch detection and flag persistence
    - Test skip and complete both set flag
    - Test default system appearance mode
    - Test theme persistence and color scheme mapping
    - Test favorites aggregation across multiple vaults
    - Test favorites with empty/no unlocked vaults
    - Test favorites navigation context includes correct vault ID
    - _Requirements: 26.1, 26.3, 26.4, 27.1, 27.2, 27.3, 28.1, 28.2, 28.3_

- [-] 19. Implement recent entries, password strength, and duplicate detection
  - [x] 19.1 Implement `RecentEntriesTracker`
    - `@Observable` class with `recentEntries: [RecentEntryReference]`, `maxCount = 10`
    - `recordAccess(entryId:vaultId:title:)` prepends entry (removing existing reference to same entry first), truncates to `maxCount`
    - `clearEntriesForVault(_:)` removes all entries matching vault ID (called on vault lock)
    - `clearAll()` empties the list
    - Stored locally via `UserDefaults` or local JSON file
    - _Requirements: 29.1, 29.2, 29.4_

  - [x] 19.2 Implement `RecentEntriesView`
    - "Recently Used" section on vault detail view or main screen
    - Display last 10 accessed entries with title and vault context
    - Tapping an entry navigates to entry detail view
    - _Requirements: 29.2, 29.3_

  - [x] 19.3 Write property test for recent entries bounded list (Property 37)
    - **Property 37: Recent Entries Bounded List**
    - Verify that for any sequence of N > 10 entry accesses, `recentEntries` contains at most 10 entries in reverse chronological order
    - **Validates: Requirements 29.1**

  - [x] 19.4 Write property test for vault lock clears recent entries (Property 38)
    - **Property 38: Vault Lock Clears Recent Entries for That Vault**
    - Verify that after `clearEntriesForVault(_:)`, no entries with that vault ID remain, and entries from other vaults are unaffected
    - **Validates: Requirements 29.4**

  - [x] 19.5 Implement `PasswordStrengthEvaluator` and `PasswordStrengthMeterView`
    - `PasswordStrengthEvaluator.evaluate(_:)` scores password based on length, character variety, and absence of common patterns
    - Returns one of four levels: `.weak`, `.fair`, `.good`, `.strong`
    - `PasswordStrengthMeterView` displays color-coded strength bar (red/orange/yellow/green)
    - Integrate into `EntryFormView` next to password field for login entries and into `RegistrationView`
    - _Requirements: 30.1, 30.2, 30.3, 30.4, 30.5_

  - [x] 19.6 Write property test for password strength level and color mapping (Property 39)
    - **Property 39: Password Strength Level and Color Mapping**
    - Verify that for any password string, the evaluator returns one of exactly four levels, and each level maps to its designated color (red, orange, yellow, green)
    - **Validates: Requirements 30.3, 30.4**

  - [x] 19.7 Write property test for password strength monotonicity (Property 40)
    - **Property 40: Password Strength Monotonicity**
    - Verify that appending characters from new character classes produces a strength level greater than or equal to the original
    - **Validates: Requirements 30.5**

  - [x] 19.8 Implement `DuplicatePasswordDetector` and `DuplicatePasswordWarningView`
    - `DuplicatePasswordDetector.detect(entryId:password:allEntries:)` iterates login entries in vault (excluding current), compares passwords, returns `DuplicatePasswordResult`
    - `DuplicatePasswordWarningView` displays warning badge/banner with duplicate count
    - Provides action to navigate to list of entries sharing the same password
    - Integrate into `EntryDetailView` for login entries
    - _Requirements: 31.1, 31.2, 31.3, 31.4_

  - [x] 19.9 Write property test for duplicate password detection (Property 41)
    - **Property 41: Duplicate Password Detection with Accurate Count**
    - Verify that `isDuplicate` is `true` iff at least one other login entry has the same password, and `duplicateCount` equals the exact number of other entries sharing that password
    - **Validates: Requirements 31.1, 31.3**

  - [x] 19.10 Write unit tests for recent entries, password strength, and duplicate detection
    - Test max 10 cap on recent entries
    - Test vault lock clears only that vault's recent entries
    - Test duplicate access updates position in recent list
    - Test each password strength level with boundary cases
    - Test common pattern detection (e.g., "password", "123456")
    - Test no duplicates returns `isDuplicate = false` and `duplicateCount = 0`
    - Test single and multiple duplicate detection
    - Test non-login entries are excluded from duplicate detection
    - _Requirements: 29.1, 29.4, 30.3, 30.5, 31.1, 31.3_

- [-] 20. Wire new features into platform navigation and settings
  - [x] 20.1 Wire `LoginView` and `RegistrationView` as root unauthenticated flow
    - Root view checks `AuthViewModel.isAuthenticated` — shows login/registration when `false`, main app when `true`
    - iOS: present as full-screen flow before `NavigationStack`
    - macOS: present as centered forms in main window when unauthenticated
    - _Requirements: 20.1, 20.3, 21.6_

  - [x] 20.2 Wire `OnboardingView` into app launch flow
    - Present `OnboardingView` after successful first login/registration when `shouldShowOnboarding` is `true`
    - _Requirements: 26.1, 26.4_

  - [x] 20.3 Wire `FavoritesView` and `RecentEntriesView` into main navigation
    - iOS: add Favorites as a tab bar item
    - macOS: add Favorites as a sidebar section below vault list
    - Add "Recently Used" section to vault detail view or main screen
    - _Requirements: 28.1, 29.2_

  - [x] 20.4 Wire vault-level actions into `VaultDetailView`
    - Add "Change Master Password", "Rename", "Export", and sort control to vault detail view toolbar/menu
    - _Requirements: 22.1, 23.1, 24.1, 25.1_

  - [x] 20.5 Update `SettingsView` with appearance picker
    - Add appearance mode picker (System/Light/Dark) wired to `ThemeManager`
    - Apply `.preferredColorScheme(themeManager.colorScheme)` at root view level
    - _Requirements: 27.2, 27.4_

- [x] 21. Final checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document (41 properties total)
- Unit tests validate specific examples, edge cases, and integration points
- All view models use `@Observable` macro (iOS 17+/macOS 14+)
- `MockURLProtocol` and `MockKeychainStore` are used throughout tests for isolation
