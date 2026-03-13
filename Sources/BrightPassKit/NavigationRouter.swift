import Foundation
import SwiftUI

/// Manages navigation state across the three-level hierarchy:
/// vault list → vault detail → entry detail.
///
/// On macOS this maps to `NavigationSplitView` columns; on iOS it drives
/// a `NavigationStack`. When a vault is locked the router resets to the
/// vault list view.
@available(macOS 14.0, iOS 17.0, *)
@MainActor
@Observable
public class NavigationRouter {

    /// Currently selected vault identifier.
    public var selectedVaultId: String?

    /// Currently selected entry identifier.
    public var selectedEntryId: String?

    /// Navigation path used by `NavigationStack` on iOS.
    public var path = NavigationPath()

    @ObservationIgnored private var lockObserver: NSObjectProtocol?

    public init() {
        lockObserver = NotificationCenter.default.addObserver(
            forName: .vaultLocked, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.returnToVaultList()
            }
        }
    }

    deinit {
        if let lockObserver {
            NotificationCenter.default.removeObserver(lockObserver)
        }
    }

    // MARK: - Navigation

    /// Navigates to the vault detail view for the given vault.
    public func navigateToVault(_ id: String) {
        selectedVaultId = id
        selectedEntryId = nil
    }

    /// Navigates to the entry detail view for the given entry
    /// within the currently selected vault.
    public func navigateToEntry(_ id: String) {
        selectedEntryId = id
    }

    /// Clears all selection state and resets the navigation path.
    /// Called when the vault is locked (manually or by timeout).
    public func returnToVaultList() {
        selectedVaultId = nil
        selectedEntryId = nil
        path = NavigationPath()
    }

    /// Pops the navigation stack back to the root (vault list).
    public func popToRoot() {
        returnToVaultList()
    }
}
