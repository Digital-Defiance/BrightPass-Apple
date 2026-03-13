import Foundation

// MARK: - AutoFill Credential Provider Entitlements
//
// This file documents the entitlements required for the BrightPass AutoFill
// Credential Provider extension. These must be configured in the Xcode project
// (or via an .entitlements plist) when building the extension as a real app extension target.
//
// Required Entitlements:
//
// 1. Credential Provider Extension
//    Key:   com.apple.developer.authentication-services.autofill-credential-provider
//    Value: true
//    Purpose: Registers the extension as an AutoFill Credential Provider so the system
//             invokes it when a login form is detected in apps or browsers.
//
// 2. Keychain Access Groups (shared with main app)
//    Key:   keychain-access-groups
//    Value: ["$(AppIdentifierPrefix)group.com.brightpass.shared"]
//    Purpose: Allows the extension to read the JWT token stored by the main app
//             in the shared Keychain access group. Both the main app and this
//             extension must declare the same access group.
//
// 3. App Groups (optional, for shared UserDefaults/files)
//    Key:   com.apple.security.application-groups
//    Value: ["group.com.brightpass.shared"]
//    Purpose: Enables shared container access between the main app and extension
//             for configuration or cached data (if needed beyond Keychain).
//
// Info.plist Configuration:
//
// The extension's Info.plist must include:
//
//   <key>NSExtension</key>
//   <dict>
//       <key>NSExtensionPointIdentifier</key>
//       <string>com.apple.authentication-services-credential-provider-extension</string>
//       <key>NSExtensionPrincipalClass</key>
//       <string>$(PRODUCT_MODULE_NAME).CredentialProviderViewController</string>
//   </dict>

/// Namespace for AutoFill extension entitlement constants.
public enum AutoFillEntitlements {

    /// The extension point identifier for registering as a Credential Provider.
    public static let extensionPointIdentifier = "com.apple.authentication-services-credential-provider-extension"

    /// The shared Keychain access group used by both the main app and this extension.
    public static let sharedKeychainAccessGroup = "group.com.brightpass.shared"

    /// The Keychain service identifier matching the main app's `KeychainStore`.
    public static let keychainService = "com.brightpass.app"
}
