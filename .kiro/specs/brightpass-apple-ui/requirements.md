# Requirements Document

## Introduction

BrightPass Apple UI is a native SwiftUI application for iOS and macOS that provides a 1Password-equivalent password management interface. The application communicates with the BrightPass REST API backend, supports all four entry types (login credentials, secure notes, credit cards, identity documents), and leverages the VCBL two-tier storage architecture for fast vault listing and lazy entry decryption. A shared Swift library encapsulates API communication, data models, and state management, while platform-specific SwiftUI views deliver native experiences on both iOS and macOS.

## Glossary

- **BrightPass_App**: The native SwiftUI application running on iOS or macOS
- **API_Client**: The shared Swift networking layer that communicates with the BrightPass REST API
- **Vault_Manager**: The component responsible for vault lifecycle operations (create, open, list, delete, lock)
- **Entry_Manager**: The component responsible for entry CRUD operations within an unlocked vault
- **Password_Generator**: The component that requests cryptographically secure passwords from the API
- **TOTP_Engine**: The component that generates and validates time-based one-time passwords via the API
- **Breach_Checker**: The component that checks passwords against the Have I Been Pwned database via the API
- **Import_Manager**: The component that handles importing entries from other password managers via the API
- **Share_Manager**: The component that manages vault sharing and access revocation
- **Emergency_Access_Manager**: The component that configures and executes Shamir-based emergency vault recovery
- **Audit_Log_Viewer**: The component that displays the append-only audit trail for a vault
- **Auto_Lock_Timer**: The component that locks the vault after a configurable period of inactivity
- **Keychain_Store**: The iOS/macOS Keychain used for secure storage of JWT tokens and session data
- **Entry_Property_Record**: A lightweight metadata record (title, type, tags, URL, favorite) from the VCBL that enables listing and search without decrypting full entries
- **VCBL**: Vault Constituent Block List — the vault index containing header, property records, and block ID array
- **Master_Password_Prompt**: The UI component that collects the master password for vault unlock
- **Navigation_Router**: The component managing navigation state across vault list, vault detail, and entry detail views
- **Configuration_Manager**: The component managing API base URL and environment settings
- **Auth_Manager**: The component responsible for user authentication, registration, session management, and logout
- **Login_Screen**: The UI view presenting email and password fields for user authentication
- **Registration_Screen**: The UI view presenting the account creation form with email, password, and confirmation fields
- **Password_Strength_Evaluator**: The component that evaluates password strength based on length, character variety, and common patterns
- **Direct_Challenge_Flow**: The two-step ECIES passwordless authentication flow: (1) request a server challenge via `/api/user/request-direct-login`, (2) sign the challenge with the member's private key and submit via `/api/user/direct-challenge`
- **ECIES**: Elliptic Curve Integrated Encryption Scheme — the cryptographic framework used for key derivation, signing, and encryption in BrightChain
- **BIP39_Mnemonic**: A 12-word recovery phrase used to deterministically derive the member's secp256k1 key pair
- **Keyring**: The component responsible for encrypting/decrypting the member's private key using AES-GCM with a Keychain-stored symmetric key
- **CryptoServiceProtocol**: Protocol defining ECIES sign/verify operations using secp256k1 keys
- **SDKWrapperProtocol**: Protocol for BrightChain SDK operations including mnemonic generation/validation and key derivation
- **Duplicate_Password_Detector**: The component that identifies entries within a vault that share the same password
- **Export_Manager**: The component that handles exporting vault entries to CSV or JSON format
- **Onboarding_Flow**: The guided first-run experience shown to new users on initial app launch
- **Theme_Manager**: The component managing appearance settings (light, dark, system) and persisting the user's preference
- **Favorites_View**: The UI view that aggregates and displays all favorited entries across unlocked vaults
- **Recent_Entries_Tracker**: The component that tracks and displays the most recently accessed entries within a vault

## Requirements

### Requirement 1: Shared Swift Library and API Client

**User Story:** As a developer, I want a shared Swift library that encapsulates all BrightPass API communication and data models, so that both iOS and macOS targets share identical business logic.

#### Acceptance Criteria

1. THE API_Client SHALL expose async Swift methods for every BrightPass REST API endpoint (vaults, entries, password generation, TOTP, breach check, autofill, audit log, sharing, emergency access, import)
2. THE API_Client SHALL attach a JWT bearer token from the Keychain_Store to the Authorization header of every API request
3. IF the API returns a 401 Unauthorized response, THEN THE API_Client SHALL clear the stored JWT and notify the BrightPass_App to present a re-authentication flow
4. THE Configuration_Manager SHALL allow setting the API base URL to "localhost" for development and "brightchain.org" for production
5. THE API_Client SHALL decode all API responses into strongly-typed Swift structs conforming to Codable
6. THE API_Client SHALL propagate API error responses (status, code, message, details) as typed Swift errors
7. FOR ALL Codable model structs, encoding then decoding SHALL produce an equivalent object (round-trip property)


### Requirement 2: Vault Management

**User Story:** As a user, I want to create, list, open, and delete vaults, so that I can organize my credentials into separate encrypted containers.

#### Acceptance Criteria

1. WHEN the user taps "Create Vault", THE BrightPass_App SHALL present a form requiring a vault name and master password, then send a create request to the API_Client
2. WHEN the API confirms vault creation, THE Vault_Manager SHALL add the new vault to the displayed vault list without requiring a full refresh
3. THE BrightPass_App SHALL display a list of all vaults returned by the API, showing vault name, entry count, and last-modified date for each vault
4. WHEN the user selects a vault from the list, THE Master_Password_Prompt SHALL appear requesting the master password before the vault is opened
5. WHEN the correct master password is provided, THE Vault_Manager SHALL send an open request to the API_Client and display the vault's Entry_Property_Record list
6. IF the master password is incorrect, THEN THE BrightPass_App SHALL display an error message and allow the user to retry
7. WHEN the user requests vault deletion, THE BrightPass_App SHALL present a confirmation dialog before sending the delete request to the API_Client
8. WHEN the API confirms vault deletion, THE Vault_Manager SHALL remove the vault from the displayed list

### Requirement 3: Entry CRUD Operations

**User Story:** As a user, I want to create, view, edit, and delete entries within a vault, so that I can manage my credentials, notes, cards, and identity documents.

#### Acceptance Criteria

1. THE BrightPass_App SHALL support four entry types: login credentials, secure notes, credit cards, and identity documents
2. WHEN the user taps "Add Entry", THE BrightPass_App SHALL present a type-specific form with fields appropriate to the selected entry type
3. WHEN a login entry form is displayed, THE Entry_Manager SHALL provide fields for site URL, username, password, optional TOTP secret, tags, and a favorite toggle
4. WHEN a credit card entry form is displayed, THE Entry_Manager SHALL provide fields for cardholder name, card number, expiration date, CVV, tags, and a favorite toggle
5. WHEN a secure note entry form is displayed, THE Entry_Manager SHALL provide fields for title, encrypted text content, tags, and a favorite toggle
6. WHEN an identity document entry form is displayed, THE Entry_Manager SHALL provide fields for name, email, phone, address, custom fields, tags, and a favorite toggle
7. WHEN the user saves a new entry, THE Entry_Manager SHALL send a create request to the API_Client and update the vault's Entry_Property_Record list upon success
8. WHEN the user selects an entry from the list, THE Entry_Manager SHALL send a get request to the API_Client to decrypt and display the full entry details
9. WHEN the user edits an entry and saves, THE Entry_Manager SHALL send an update request to the API_Client and refresh the entry detail view upon success
10. WHEN the user deletes an entry, THE BrightPass_App SHALL present a confirmation dialog, then send a delete request to the API_Client and remove the entry from the list upon success

### Requirement 4: Entry Search and Filtering

**User Story:** As a user, I want to search and filter entries within a vault, so that I can quickly find specific credentials.

#### Acceptance Criteria

1. THE BrightPass_App SHALL display a search bar at the top of the vault detail view
2. WHEN the user types a search query, THE Entry_Manager SHALL send a search request to the API_Client with the query text
3. THE BrightPass_App SHALL display search results as a filtered list of Entry_Property_Record items matching the query
4. THE BrightPass_App SHALL allow filtering entries by type (login, secure note, credit card, identity document)
5. THE BrightPass_App SHALL allow filtering entries by favorite status
6. WHEN the search query is cleared, THE BrightPass_App SHALL restore the full entry list


### Requirement 5: Password Generator

**User Story:** As a user, I want to generate cryptographically secure passwords with configurable options, so that I can create strong unique passwords for each account.

#### Acceptance Criteria

1. THE BrightPass_App SHALL provide a password generator view accessible from the entry form and as a standalone tool
2. THE Password_Generator SHALL allow configuring password length between 8 and 128 characters
3. THE Password_Generator SHALL allow toggling inclusion of uppercase letters, lowercase letters, digits, and special characters
4. THE Password_Generator SHALL allow setting minimum counts for uppercase, digit, and special character types
5. WHEN the user taps "Generate", THE Password_Generator SHALL send a generate request to the API_Client and display the resulting password
6. THE BrightPass_App SHALL provide a "Copy to Clipboard" action for the generated password
7. WHEN the password generator is accessed from an entry form, THE BrightPass_App SHALL provide an "Use Password" action that populates the entry's password field

### Requirement 6: TOTP/2FA Support

**User Story:** As a user, I want to generate and validate TOTP codes for my login entries, so that I can use two-factor authentication without a separate authenticator app.

#### Acceptance Criteria

1. WHEN a login entry has a TOTP secret configured, THE TOTP_Engine SHALL display a 6-digit code with a countdown timer showing remaining validity
2. WHEN the TOTP code expires (30-second window), THE TOTP_Engine SHALL automatically request a new code from the API_Client
3. THE BrightPass_App SHALL provide a "Copy Code" action for the displayed TOTP code
4. WHEN the user adds or edits a TOTP secret on a login entry, THE TOTP_Engine SHALL validate the secret by generating a test code via the API_Client
5. THE BrightPass_App SHALL display the TOTP code alongside the login entry detail view

### Requirement 7: Breach Detection

**User Story:** As a user, I want to check whether my passwords have appeared in known data breaches, so that I can replace compromised credentials.

#### Acceptance Criteria

1. THE BrightPass_App SHALL provide a breach check action on any entry containing a password field
2. WHEN the user triggers a breach check, THE Breach_Checker SHALL send the password to the API_Client breach-check endpoint
3. IF the API reports the password has been found in breaches, THEN THE BrightPass_App SHALL display the breach count and a warning recommending password change
4. IF the API reports the password has not been found in breaches, THEN THE BrightPass_App SHALL display a confirmation that the password is not known to be compromised
5. WHILE a breach check request is in progress, THE BrightPass_App SHALL display a loading indicator

### Requirement 8: Vault Sharing

**User Story:** As a vault owner, I want to share a vault with other BrightChain members and revoke access when needed, so that teams can collaborate on shared credentials.

#### Acceptance Criteria

1. THE BrightPass_App SHALL provide a "Share Vault" action accessible from the vault detail view
2. WHEN the user initiates vault sharing, THE Share_Manager SHALL present a form to specify the recipient member ID and permission level
3. WHEN the user confirms sharing, THE Share_Manager SHALL send a share request to the API_Client
4. THE BrightPass_App SHALL display the list of members with whom the vault is currently shared
5. WHEN the vault owner selects a shared member and taps "Revoke Access", THE Share_Manager SHALL send a revoke request to the API_Client and remove the member from the shared list upon success


### Requirement 9: Emergency Access

**User Story:** As a vault owner, I want to configure emergency access using Shamir's Secret Sharing, so that trusted contacts can recover my vault if I become unavailable.

#### Acceptance Criteria

1. THE BrightPass_App SHALL provide an "Emergency Access" action accessible from the vault detail view
2. WHEN the user configures emergency access, THE Emergency_Access_Manager SHALL present a form to specify the total number of shares (N) and the recovery threshold (T)
3. WHEN the user confirms the configuration, THE Emergency_Access_Manager SHALL send the configuration to the API_Client
4. THE BrightPass_App SHALL display the current emergency access configuration (share count, threshold, trustee list) for a vault
5. WHEN a user initiates emergency recovery, THE Emergency_Access_Manager SHALL present a form to collect the required number of shares and send a recover request to the API_Client
6. IF recovery succeeds, THEN THE Emergency_Access_Manager SHALL open the recovered vault and display its contents
7. IF fewer than T shares are provided, THEN THE BrightPass_App SHALL display an error indicating insufficient shares for recovery

### Requirement 10: Import from Other Password Managers

**User Story:** As a user switching to BrightPass, I want to import credentials from other password managers, so that I can migrate without manually re-entering entries.

#### Acceptance Criteria

1. THE BrightPass_App SHALL provide an "Import" action accessible from the vault detail view
2. THE Import_Manager SHALL support importing from 1Password (1PUX, CSV), LastPass (CSV), Bitwarden (JSON, CSV), Chrome (CSV), Firefox (CSV), KeePass (XML), and Dashlane (JSON)
3. WHEN the user selects an import source and provides a file, THE Import_Manager SHALL send the file to the API_Client import endpoint
4. WHEN the API returns the import result, THE BrightPass_App SHALL display a summary showing the count of successfully imported entries and any errors
5. WHEN import completes successfully, THE Entry_Manager SHALL refresh the vault's entry list to include the newly imported entries

### Requirement 11: Audit Log

**User Story:** As a vault owner, I want to view the audit trail of all actions performed on my vault, so that I can monitor access and detect unauthorized activity.

#### Acceptance Criteria

1. THE BrightPass_App SHALL provide an "Audit Log" action accessible from the vault detail view
2. WHEN the user opens the audit log, THE Audit_Log_Viewer SHALL request the log entries from the API_Client
3. THE Audit_Log_Viewer SHALL display each log entry showing the action type, member ID, timestamp, and any metadata
4. THE Audit_Log_Viewer SHALL display log entries in reverse chronological order (newest first)
5. THE Audit_Log_Viewer SHALL support scrolling through the full audit history

### Requirement 12: Auto-Lock and Session Security

**User Story:** As a user, I want my vault to automatically lock after a period of inactivity, so that my credentials are protected if I leave my device unattended.

#### Acceptance Criteria

1. WHEN a vault is unlocked and no user interaction occurs for the configured timeout period, THE Auto_Lock_Timer SHALL lock the vault and clear all decrypted data from memory
2. THE BrightPass_App SHALL default the auto-lock timeout to 15 minutes
3. THE BrightPass_App SHALL allow the user to configure the auto-lock timeout between 1 minute and 60 minutes
4. WHEN the application moves to the background on iOS, THE Auto_Lock_Timer SHALL start an accelerated 5-minute lock timer
5. WHEN the application returns to the foreground before the accelerated timer expires, THE Auto_Lock_Timer SHALL cancel the accelerated timer and resume the standard inactivity timer
6. WHEN the vault is locked (manually or by timeout), THE Vault_Manager SHALL clear all decrypted entry data, property records, and master password hashes from memory
7. THE Keychain_Store SHALL store the JWT authentication token securely using the iOS/macOS Keychain with appropriate access control flags
8. THE BrightPass_App SHALL clear the JWT token from the Keychain_Store when the user explicitly logs out


### Requirement 13: Navigation and Layout

**User Story:** As a user, I want intuitive navigation between vault list, vault contents, and entry details, so that I can efficiently manage my credentials on both iOS and macOS.

#### Acceptance Criteria

1. THE Navigation_Router SHALL implement a three-level hierarchy: vault list → vault detail (entry list) → entry detail
2. THE BrightPass_App SHALL use a NavigationSplitView on macOS to display the vault list in a sidebar and content in the detail pane
3. THE BrightPass_App SHALL use a NavigationStack on iOS to provide standard push/pop navigation between views
4. THE BrightPass_App SHALL display a breadcrumb trail or navigation title reflecting the current position in the hierarchy
5. WHEN a vault is locked, THE Navigation_Router SHALL return the user to the vault list view
6. THE BrightPass_App SHALL adapt its layout to the current platform (iOS compact, iOS regular, macOS) using SwiftUI's native adaptive layout system

### Requirement 14: Autofill Integration

**User Story:** As a user, I want BrightPass to provide credential autofill on iOS and macOS, so that I can quickly fill login forms in apps and browsers.

#### Acceptance Criteria

1. THE BrightPass_App SHALL register as a Credential Provider using the iOS/macOS AutoFill Credential Provider extension point
2. WHEN the system requests credentials for a service identifier (URL), THE API_Client SHALL send an autofill request to the API and return matching login entries
3. WHEN matching entries are found, THE BrightPass_App SHALL present a list of matching credentials for the user to select
4. WHEN the user selects a credential, THE BrightPass_App SHALL provide the username and password to the system AutoFill framework
5. IF no matching entries are found for the requested URL, THEN THE BrightPass_App SHALL display a message indicating no saved credentials match

### Requirement 15: Biometric Unlock

**User Story:** As a user, I want to unlock vaults using Face ID or Touch ID, so that I can access my credentials quickly without typing my master password every time.

#### Acceptance Criteria

1. THE BrightPass_App SHALL offer an option to enable biometric unlock (Face ID or Touch ID) for each vault
2. WHEN biometric unlock is enabled, THE Keychain_Store SHALL store the master password hash in the Keychain protected by a biometric access control policy
3. WHEN the user attempts to open a biometrically-enabled vault, THE BrightPass_App SHALL prompt for biometric authentication before retrieving the stored master password hash
4. IF biometric authentication succeeds, THEN THE Vault_Manager SHALL use the retrieved master password hash to unlock the vault via the API_Client
5. IF biometric authentication fails, THEN THE BrightPass_App SHALL fall back to the Master_Password_Prompt for manual entry
6. WHEN the user disables biometric unlock for a vault, THE Keychain_Store SHALL remove the stored master password hash for that vault

### Requirement 16: Clipboard and Sensitive Data Handling

**User Story:** As a user, I want copied passwords and sensitive data to be automatically cleared from the clipboard, so that my credentials are not exposed through clipboard history.

#### Acceptance Criteria

1. WHEN the user copies a password, TOTP code, or other sensitive field, THE BrightPass_App SHALL set the clipboard content with an expiration flag
2. THE BrightPass_App SHALL clear copied sensitive data from the clipboard after 30 seconds
3. THE BrightPass_App SHALL mark clipboard items as sensitive using UIPasteboard's localOnly and expirationDate properties on iOS
4. WHEN displaying password fields in entry detail views, THE BrightPass_App SHALL mask the password by default and provide a toggle to reveal the value


### Requirement 17: Error Handling and Offline Behavior

**User Story:** As a user, I want clear error messages and graceful handling of network failures, so that I understand what went wrong and can take corrective action.

#### Acceptance Criteria

1. IF the API_Client receives a network timeout or connectivity error, THEN THE BrightPass_App SHALL display a user-friendly error message indicating the network is unavailable
2. IF the API_Client receives a server error (5xx), THEN THE BrightPass_App SHALL display a message indicating a server issue and suggest retrying
3. IF the API_Client receives a validation error (4xx with details), THEN THE BrightPass_App SHALL display the specific validation error messages from the API response
4. THE BrightPass_App SHALL provide a retry action on all recoverable error states
5. WHILE an API request is in progress, THE BrightPass_App SHALL display a loading indicator appropriate to the context (inline spinner for actions, full-screen overlay for vault unlock)

### Requirement 18: Swift Package Structure

**User Story:** As a developer, I want the project organized as a Swift Package with shared library and platform-specific app targets, so that code reuse is maximized and platform differences are isolated.

#### Acceptance Criteria

1. THE BrightPass_App SHALL be structured as a Swift Package with a shared library target named "BrightPassKit" containing API client, data models, and state management
2. THE BrightPassKit library SHALL declare platform support for macOS 13+ and iOS 17+ matching the existing BrightChainApple package
3. THE BrightPassKit library SHALL have no dependencies on UIKit or AppKit, using only Foundation and platform-agnostic Swift APIs
4. THE BrightPass_App SHALL include separate app targets for iOS and macOS that depend on BrightPassKit
5. THE BrightPass_App SHALL include a test target with property-based tests using SwiftCheck, matching the testing pattern of the existing BrightChainApple package

### Requirement 19: JSON Serialization Round-Trip

**User Story:** As a developer, I want all API response models to correctly round-trip through JSON encoding and decoding, so that data integrity is preserved across the API boundary.

#### Acceptance Criteria

1. THE API_Client SHALL define Codable structs for VaultMetadata, DecryptedVault, VaultEntry, EntryPropertyRecord, AuditLogEntry, EmergencyAccessConfig, ImportResult, AutofillPayload, GeneratedPassword, TotpCode, and BreachCheckResult
2. FOR ALL Codable model structs, encoding to JSON then decoding from JSON SHALL produce a value equal to the original (round-trip property)
3. THE API_Client SHALL use a configured JSONDecoder with ISO 8601 date decoding strategy for all date fields
4. IF the API returns a JSON response with unexpected or missing fields, THEN THE API_Client SHALL throw a descriptive DecodingError rather than silently producing default values


### Requirement 20: Authentication and Login UI (ECIES Direct Challenge)

**User Story:** As a user, I want to log in to BrightPass using my BrightChain cryptographic identity (mnemonic-derived keys), so that I can access my vaults without a password.

#### Acceptance Criteria

1. THE Login_Screen SHALL display a form with username (or email) and a mnemonic phrase input field, and a "Log In" button
2. WHEN the user taps "Log In", THE Auth_Manager SHALL derive the member's secp256k1 key pair from the mnemonic using BIP39/PBKDF2, then execute the two-step ECIES direct challenge flow: (a) POST `/api/user/request-direct-login` to obtain a server challenge and server public key, (b) sign the challenge with the member's private key, (c) POST `/api/user/direct-challenge` with the signed challenge, username/email, and the original challenge hex
3. WHEN the API returns a successful direct challenge response (JWT token and user data), THE Auth_Manager SHALL store the JWT token in the Keychain_Store, store the encrypted private key in the Keychain via the Keyring, and THE Navigation_Router SHALL navigate to the vault list view
4. IF the API returns an authentication failure (expired challenge, invalid signature, unknown user), THEN THE Login_Screen SHALL display the error message and allow the user to retry
5. WHEN the user taps "Log Out", THE Auth_Manager SHALL clear the JWT token and encrypted private key from the Keychain_Store and THE Navigation_Router SHALL navigate to the Login_Screen
6. IF the API_Client detects an expired or invalid JWT session, THEN THE Auth_Manager SHALL clear the stored JWT and THE Navigation_Router SHALL redirect the user to the Login_Screen
7. THE Auth_Manager SHALL validate the mnemonic phrase (12 BIP39 words) before attempting the direct challenge flow
8. THE Auth_Manager SHALL store the member's encrypted private key (AES-GCM via SimpleKeyring) in the Keychain so that subsequent API requests can be signed without re-entering the mnemonic
9. THE API_Client SHALL support a `GET /api/user/refresh-token` endpoint to exchange a valid JWT for a fresh one before expiration (7-day JWT lifetime)

### Requirement 21: Account Registration

**User Story:** As a new user, I want to create a BrightChain account from the app, so that I can start using BrightPass.

#### Acceptance Criteria

1. THE Registration_Screen SHALL display a form with username, email, and password input fields and a "Create Account" button
2. WHILE the user types in the password field on the Registration_Screen, THE Password_Strength_Evaluator SHALL display a real-time strength indicator
3. WHEN the user taps "Create Account" with valid input, THE Auth_Manager SHALL send a registration request to `POST /api/user/register` with username, email, and password
4. WHEN the API returns a successful registration response (JWT token, memberId, and energyBalance), THE Auth_Manager SHALL generate a BIP39 mnemonic, derive the member's key pair, display the mnemonic for the user to save, store the JWT in the Keychain_Store, and THE Navigation_Router SHALL navigate to the vault list view
5. IF the API returns validation errors during registration (weak password, duplicate username/email), THEN THE Registration_Screen SHALL display the specific validation error messages next to the relevant fields
6. THE Registration_Screen SHALL provide a "Already have an account? Log In" link that navigates to the Login_Screen
7. THE Registration_Screen SHALL require the user to confirm they have saved their mnemonic phrase before completing registration

### Requirement 22: Master Password Change

**User Story:** As a user, I want to change the master password for a vault, so that I can maintain security if my password is compromised.

#### Acceptance Criteria

1. THE BrightPass_App SHALL provide a "Change Master Password" action accessible from the vault detail view
2. WHEN the user initiates a master password change, THE BrightPass_App SHALL present a form requiring the current master password, a new master password, and confirmation of the new master password
3. WHEN the user submits the change password form with valid input, THE Vault_Manager SHALL send a change-password request to the API_Client
4. WHEN the API confirms the master password change, THE BrightPass_App SHALL update any stored biometric master password hashes in the Keychain_Store and display a success confirmation
5. IF the current master password provided is incorrect, THEN THE BrightPass_App SHALL display an error message and allow the user to retry
6. IF the new master password and confirmation do not match, THEN THE BrightPass_App SHALL display a validation error before sending the request

### Requirement 23: Vault Rename

**User Story:** As a user, I want to rename a vault, so that I can keep my vault names organized.

#### Acceptance Criteria

1. THE BrightPass_App SHALL provide a "Rename" action accessible from the vault detail view and from a context menu on the vault list item
2. WHEN the user initiates a rename action, THE BrightPass_App SHALL present an inline editing field or a rename dialog pre-populated with the current vault name
3. WHEN the user confirms the new vault name, THE Vault_Manager SHALL send a rename request to the API_Client
4. WHEN the API confirms the vault rename, THE Vault_Manager SHALL update the displayed vault name in the vault list and vault detail views without requiring a full refresh

### Requirement 24: Entry Sorting

**User Story:** As a user, I want to sort entries within a vault by different criteria, so that I can organize and find entries more easily.

#### Acceptance Criteria

1. THE BrightPass_App SHALL provide a sort control on the vault detail view with the following options: name ascending (A-Z), name descending (Z-A), date modified newest first, date modified oldest first, date created newest first, date created oldest first, and entry type
2. WHEN the user selects a sort option, THE Entry_Manager SHALL reorder the displayed entry list according to the selected criterion
3. THE Entry_Manager SHALL persist the selected sort option for the duration of the current session
4. WHEN a search query or type filter is active, THE Entry_Manager SHALL apply the selected sort order to the filtered results

### Requirement 25: Data Export

**User Story:** As a user, I want to export my vault entries, so that I can back up my data or migrate to another password manager.

#### Acceptance Criteria

1. THE BrightPass_App SHALL provide an "Export" action accessible from the vault detail view
2. THE Export_Manager SHALL support exporting entries in CSV and JSON formats
3. WHEN the user selects an export format and confirms, THE Export_Manager SHALL send an export request to the API_Client export endpoint
4. WHEN the API returns the exported data, THE BrightPass_App SHALL present a file save dialog on macOS or a share sheet on iOS for the user to save the exported file
5. IF the export request fails, THEN THE BrightPass_App SHALL display an error message indicating the reason for failure

### Requirement 26: Onboarding and First-Run Experience

**User Story:** As a new user, I want a guided onboarding experience on first launch, so that I understand how to use BrightPass.

#### Acceptance Criteria

1. WHEN the BrightPass_App launches for the first time (no onboarding-complete flag in UserDefaults), THE Onboarding_Flow SHALL present a welcome screen with an overview of the application
2. THE Onboarding_Flow SHALL guide the user through creating a first vault and adding a first entry with step-by-step instructions
3. THE Onboarding_Flow SHALL provide a "Skip" action on each step that allows the user to exit onboarding and proceed to the main application
4. WHEN the user completes or skips the Onboarding_Flow, THE BrightPass_App SHALL set the onboarding-complete flag in UserDefaults so the flow is not shown on subsequent launches

### Requirement 27: Dark Mode and Theming

**User Story:** As a user, I want the app to support dark mode and follow system appearance settings, so that the app is comfortable to use in any lighting.

#### Acceptance Criteria

1. THE Theme_Manager SHALL default to following the system appearance setting (light or dark)
2. THE BrightPass_App SHALL allow the user to manually override the appearance with three options: light, dark, and system
3. THE Theme_Manager SHALL persist the selected appearance preference in UserDefaults
4. THE BrightPass_App SHALL use semantic colors defined in the asset catalog for all views so that colors adapt correctly to the active appearance mode

### Requirement 28: Favorites View

**User Story:** As a user, I want a dedicated favorites view that shows all favorited entries across all vaults, so that I can quickly access my most-used credentials.

#### Acceptance Criteria

1. THE BrightPass_App SHALL provide a Favorites_View accessible from the main navigation (tab bar on iOS or sidebar section on macOS)
2. THE Favorites_View SHALL aggregate and display all entries marked as favorite from all currently unlocked vaults
3. WHEN the user taps a favorited entry in the Favorites_View, THE Navigation_Router SHALL navigate to the entry detail view within the correct vault context

### Requirement 29: Recently Used Entries

**User Story:** As a user, I want to see recently accessed entries, so that I can quickly re-access credentials I used recently.

#### Acceptance Criteria

1. THE Recent_Entries_Tracker SHALL maintain a list of the last 10 accessed entries, stored locally on the device
2. THE BrightPass_App SHALL display a "Recently Used" section on the vault detail view or main screen showing the tracked entries
3. WHEN the user taps a recently used entry, THE Navigation_Router SHALL navigate to the entry detail view
4. WHEN a vault is locked, THE Recent_Entries_Tracker SHALL clear all recently used entries associated with that vault from the local list

### Requirement 30: Password Strength Indicator

**User Story:** As a user, I want to see a password strength indicator when creating or editing login entries, so that I can ensure my passwords are strong enough.

#### Acceptance Criteria

1. WHEN a login entry form is displayed for creation or editing, THE Password_Strength_Evaluator SHALL display a visual strength meter next to the password field
2. WHILE the user types in the password field, THE Password_Strength_Evaluator SHALL evaluate the password in real time and update the strength meter
3. THE Password_Strength_Evaluator SHALL classify password strength into four levels: weak, fair, good, and strong
4. THE Password_Strength_Evaluator SHALL display the strength level using color coding: red for weak, orange for fair, yellow for good, and green for strong
5. THE Password_Strength_Evaluator SHALL base the evaluation on password length, character variety (uppercase, lowercase, digits, special characters), and absence of common patterns

### Requirement 31: Duplicate Password Detection

**User Story:** As a user, I want to be warned when I'm using the same password across multiple entries, so that I can improve my security posture.

#### Acceptance Criteria

1. WHEN the user views a login entry detail, THE Duplicate_Password_Detector SHALL check whether the entry's password is used by other entries in the same vault
2. IF duplicate passwords are detected, THEN THE BrightPass_App SHALL display a warning badge or banner on the entry detail view
3. THE Duplicate_Password_Detector SHALL display the count of other entries using the same password in the warning message
4. THE BrightPass_App SHALL provide an action in the duplicate warning that navigates to a list of the entries sharing the same password
