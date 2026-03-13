// BrightPassAutoFill — AutoFill Credential Provider Extension
//
// In a real Xcode project, this target would be an app extension (not an executable).
// The system launches the extension and instantiates CredentialProviderViewController
// automatically via the NSExtension configuration in Info.plist.
//
// This main.swift exists only to satisfy Swift Package Manager's executable target
// requirement. When building as an actual app extension in Xcode, this file is not needed.

import Foundation

#if canImport(AuthenticationServices)
import AuthenticationServices
import BrightPassKit

// Extension entry point placeholder for SPM compatibility.
// The real entry point is CredentialProviderViewController, invoked by the system.
print("BrightPass AutoFill Credential Provider extension — not intended to run standalone.")
#else
print("AuthenticationServices is not available on this platform.")
#endif
