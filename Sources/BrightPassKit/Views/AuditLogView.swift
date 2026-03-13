import SwiftUI

/// Displays the audit trail for a vault as a scrollable list of log entries.
///
/// Each entry shows the action type, member ID, timestamp, and optional metadata.
///
/// **Validates: Requirements 11.1, 11.2, 11.3, 11.4, 11.5**
@available(macOS 14.0, iOS 17.0, *)
public struct AuditLogView: View {

    @Bindable var viewModel: AuditLogViewModel

    private let vaultId: String
    private let onDismiss: (() -> Void)?

    public init(viewModel: AuditLogViewModel, vaultId: String, onDismiss: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.vaultId = vaultId
        self.onDismiss = onDismiss
    }

    public var body: some View {
        List {
            if viewModel.entries.isEmpty && !viewModel.isLoading {
                Text("No audit log entries")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Audit log is empty")
            } else {
                ForEach(viewModel.entries) { entry in
                    auditEntryRow(entry)
                }
            }
        }
        .navigationTitle("Audit Log")
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .accessibilityLabel("Loading audit log")
            }
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") { viewModel.error = nil }
        } message: {
            if let error = viewModel.error {
                Text(error.userMessage)
            }
        }
        .task {
            await viewModel.loadAuditLog(vaultId: vaultId)
        }
    }

    // MARK: - Row

    private func auditEntryRow(_ entry: AuditLogEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.action)
                    .font(.headline)
                Spacer()
                Text(entry.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Member: \(entry.memberId)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let metadata = entry.metadata, !metadata.isEmpty {
                ForEach(metadata.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                    Text("\(key): \(value)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.action) by \(entry.memberId)")
    }
}
