import Foundation
import BrightPassKit

#if canImport(AuthenticationServices)
import AuthenticationServices
#endif

#if canImport(SwiftUI)
import SwiftUI

/// Minimal SwiftUI credential picker for the AutoFill extension.
///
/// Displays a list of matching credentials (title + username) for the user to select,
/// or a "No saved credentials match" message when the list is empty.
@available(macOS 14.0, iOS 17.0, *)
struct CredentialPickerView: View {
    let credentials: [AutofillPayload]
    let onSelect: (AutofillPayload) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if credentials.isEmpty {
                    ContentUnavailableView(
                        "No Saved Credentials Match",
                        systemImage: "key.slash",
                        description: Text("No saved credentials match this site.")
                    )
                } else {
                    List(credentials, id: \.entryId) { credential in
                        Button {
                            onSelect(credential)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(credential.title)
                                    .font(.headline)
                                Text(credential.username)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Choose a Credential")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
    }
}

#endif
