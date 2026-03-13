import SwiftUI

/// Displays vault sharing controls: a form to add members and a list of current shared members
/// with revoke actions.
///
/// **Validates: Requirements 8.1, 8.2, 8.3, 8.4, 8.5**
@available(macOS 14.0, iOS 17.0, *)
public struct ShareVaultView: View {

    @Bindable var viewModel: ShareVaultViewModel

    private let vaultId: String
    private let onDismiss: (() -> Void)?

    @State private var newMemberId: String = ""
    @State private var selectedPermission: SharePermission = .readOnly
    @State private var showRevokeConfirmation: Bool = false
    @State private var memberToRevoke: SharedMember?

    public init(viewModel: ShareVaultViewModel, vaultId: String, onDismiss: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.vaultId = vaultId
        self.onDismiss = onDismiss
    }

    public var body: some View {
        List {
            shareFormSection
            sharedMembersSection
        }
        .navigationTitle("Share Vault")
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .accessibilityLabel("Loading sharing information")
            }
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") { viewModel.error = nil }
        } message: {
            if let error = viewModel.error {
                Text(error.userMessage)
            }
        }
        .confirmationDialog("Revoke Access", isPresented: $showRevokeConfirmation, presenting: memberToRevoke) { member in
            Button("Revoke", role: .destructive) {
                Task {
                    await viewModel.revokeAccess(vaultId: vaultId, memberId: member.memberId)
                }
            }
        } message: { member in
            Text("Remove \(member.memberId) from this vault?")
        }
        .task {
            await viewModel.loadSharedMembers(vaultId: vaultId)
        }
    }

    // MARK: - Share Form

    private var shareFormSection: some View {
        Section("Add Member") {
            TextField("Member ID", text: $newMemberId)
                .accessibilityLabel("Member ID to share with")
            #if os(iOS)
                .textInputAutocapitalization(.never)
            #endif

            Picker("Permission", selection: $selectedPermission) {
                Text("Read Only").tag(SharePermission.readOnly)
                Text("Read & Write").tag(SharePermission.readWrite)
            }
            .accessibilityLabel("Permission level")

            Button("Share") {
                Task {
                    await viewModel.shareVault(
                        vaultId: vaultId,
                        memberId: newMemberId.trimmingCharacters(in: .whitespacesAndNewlines),
                        permission: selectedPermission
                    )
                    newMemberId = ""
                }
            }
            .disabled(newMemberId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Share vault with member")
        }
    }

    // MARK: - Shared Members List

    private var sharedMembersSection: some View {
        Section("Shared With") {
            if viewModel.sharedMembers.isEmpty && !viewModel.isLoading {
                Text("Not shared with anyone")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.sharedMembers) { member in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(member.memberId)
                                .font(.body)
                            Text(member.permission == .readWrite ? "Read & Write" : "Read Only")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Revoke", role: .destructive) {
                            memberToRevoke = member
                            showRevokeConfirmation = true
                        }
                        .accessibilityLabel("Revoke access for \(member.memberId)")
                    }
                }
            }
        }
    }
}
