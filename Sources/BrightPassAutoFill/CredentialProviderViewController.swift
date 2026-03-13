import Foundation
import BrightPassKit

#if canImport(AuthenticationServices)
import AuthenticationServices
#endif

#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(AuthenticationServices)

/// AutoFill Credential Provider extension view controller.
///
/// Subclasses `ASCredentialProviderViewController` to integrate with the iOS/macOS
/// system AutoFill framework. Uses the shared Keychain access group to read the JWT
/// token stored by the main app, then queries the BrightPass API for matching credentials.
///
/// Registration requires the `com.apple.authentication-services-credential-provider-extension`
/// entitlement (configured in the Xcode project, documented in `AutoFillEntitlements.swift`).
@available(macOS 14.0, iOS 17.0, *)
public class CredentialProviderViewController: ASCredentialProviderViewController {

    // MARK: - Dependencies

    /// Shared Keychain store using the same access group as the main app.
    private lazy var keychainStore: KeychainStore = {
        KeychainStore(service: "com.brightpass.app", accessGroup: "group.com.brightpass.shared")
    }()

    /// API client configured for production, sharing the JWT via Keychain.
    private lazy var apiClient: APIClient = {
        let config = ConfigurationManager(environment: .production)
        return APIClient(configuration: config, keychain: keychainStore)
    }()

    /// Credentials fetched from the API for the current service identifier.
    private var fetchedCredentials: [AutofillPayload] = []

    // MARK: - ASCredentialProviderViewController Overrides

    /// Called by the system when a credential list is needed for the given service identifiers.
    ///
    /// Extracts the first service identifier, queries the API for matching credentials,
    /// and presents a credential picker view with the results (or a "no matches" message).
    override public func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        guard let identifier = serviceIdentifiers.first else {
            cancelRequest()
            return
        }

        Task {
            do {
                let results = try await apiClient.autofillLookup(serviceIdentifier: identifier.identifier)
                await MainActor.run {
                    self.fetchedCredentials = results
                    self.presentCredentialPicker(credentials: results)
                }
            } catch {
                await MainActor.run {
                    self.extensionContext.cancelRequest(
                        withError: NSError(
                            domain: ASExtensionErrorDomain,
                            code: ASExtensionError.failed.rawValue,
                            userInfo: [NSLocalizedDescriptionKey: "Failed to look up credentials: \(error.localizedDescription)"]
                        )
                    )
                }
            }
        }
    }

    // MARK: - Credential Selection

    /// Completes the AutoFill request with the selected credential.
    ///
    /// Provides the username and password to the system via `ASPasswordCredential`.
    /// - Parameter payload: The autofill payload containing the credential to provide.
    public func selectCredential(_ payload: AutofillPayload) {
        let credential = ASPasswordCredential(user: payload.username, password: payload.password)
        extensionContext.completeRequest(withSelectedCredential: credential, completionHandler: nil)
    }

    /// Cancels the AutoFill request.
    ///
    /// Called when the user dismisses the credential picker without selecting a credential.
    public func cancelRequest() {
        extensionContext.cancelRequest(
            withError: NSError(
                domain: ASExtensionErrorDomain,
                code: ASExtensionError.userCanceled.rawValue,
                userInfo: nil
            )
        )
    }

    // MARK: - Private Helpers

    private func provideCredential(_ payload: AutofillPayload) {
        let credential = ASPasswordCredential(user: payload.username, password: payload.password)
        extensionContext.completeRequest(withSelectedCredential: credential, completionHandler: nil)
    }

    /// Presents the SwiftUI credential picker as a child view controller.
    ///
    /// Shows the list of matching credentials for user selection, or a
    /// "No saved credentials match" message when the list is empty.
    private func presentCredentialPicker(credentials: [AutofillPayload]) {
        #if canImport(SwiftUI)
        let pickerView = CredentialPickerView(
            credentials: credentials,
            onSelect: { [weak self] payload in
                self?.selectCredential(payload)
            },
            onCancel: { [weak self] in
                self?.cancelRequest()
            }
        )

        #if os(iOS)
        let hostingController = UIHostingController(rootView: pickerView)
        addChild(hostingController)
        hostingController.view.frame = view.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
        #elseif os(macOS)
        let hostingController = NSHostingController(rootView: pickerView)
        addChild(hostingController)
        hostingController.view.frame = view.bounds
        hostingController.view.autoresizingMask = [.width, .height]
        view.addSubview(hostingController.view)
        #endif
        #endif
    }
}

#endif
