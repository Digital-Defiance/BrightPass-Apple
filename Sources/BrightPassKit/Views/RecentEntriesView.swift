import SwiftUI

/// Displays the most recently accessed vault entries.
/// Can be embedded in VaultDetailView or a main screen as a "Recently Used" section.
@available(macOS 14.0, iOS 17.0, *)
public struct RecentEntriesView: View {
    var tracker: RecentEntriesTracker
    let onSelectEntry: (RecentEntryReference) -> Void

    public init(tracker: RecentEntriesTracker,
                onSelectEntry: @escaping (RecentEntryReference) -> Void) {
        self.tracker = tracker
        self.onSelectEntry = onSelectEntry
    }

    public var body: some View {
        Group {
            if tracker.recentEntries.isEmpty {
                ContentUnavailableView("No Recent Entries",
                                       systemImage: "clock",
                                       description: Text("Entries you access will appear here."))
            } else {
                List(tracker.recentEntries) { entry in
                    Button {
                        onSelectEntry(entry)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title)
                                .font(.body)
                            Text("Vault: \(entry.vaultId)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(entry.title), vault \(entry.vaultId)")
                }
            }
        }
        .navigationTitle("Recently Used")
    }
}
