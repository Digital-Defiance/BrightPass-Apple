import SwiftUI

/// Displays a warning banner when a password is shared with other entries.
@available(macOS 14.0, iOS 17.0, *)
public struct DuplicatePasswordWarningView: View {
    let result: DuplicatePasswordResult
    var onShowDuplicates: (() -> Void)?

    public init(result: DuplicatePasswordResult, onShowDuplicates: (() -> Void)? = nil) {
        self.result = result
        self.onShowDuplicates = onShowDuplicates
    }

    public var body: some View {
        if result.isDuplicate {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)

                Text("This password is shared with \(result.duplicateCount) other \(result.duplicateCount == 1 ? "entry" : "entries")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                if let onShowDuplicates {
                    Button("View Duplicates") {
                        onShowDuplicates()
                    }
                    .font(.subheadline)
                    .buttonStyle(.borderless)
                }
            }
            .padding(10)
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityElement(children: .combine)
        }
    }
}
