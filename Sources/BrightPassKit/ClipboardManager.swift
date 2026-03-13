import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Manages sensitive clipboard operations with automatic 30-second expiration.
/// - On iOS: uses `UIPasteboard` with `localOnly` and `expirationDate` options.
/// - On macOS: uses `NSPasteboard` with a `DispatchSourceTimer` for cleanup.
@available(macOS 14.0, iOS 17.0, *)
@MainActor
public class ClipboardManager {

    public static let expirationInterval: TimeInterval = 30

    /// The date of the last sensitive copy, used by `clearIfExpired()`.
    public private(set) var lastCopyDate: Date?

    /// Tracks whether the last copy was configured as local-only (non-syncing).
    public private(set) var lastCopyLocalOnly: Bool = false

    /// Tracks the expiration date set on the last copy operation.
    public private(set) var lastCopyExpirationDate: Date?

    #if os(macOS)
    private var cleanupTimer: DispatchSourceTimer?
    private var copyChangeCount: Int = 0
    #endif

    public init() {}

    /// Copies a sensitive value to the clipboard with a 30-second expiration.
    /// The item is marked as local-only (no Universal Clipboard sync on iOS).
    public func copySensitive(_ value: String) {
        let now = Date()
        lastCopyDate = now
        lastCopyLocalOnly = true
        lastCopyExpirationDate = now.addingTimeInterval(Self.expirationInterval)

        #if os(iOS)
        UIPasteboard.general.setItems(
            [[UIPasteboard.typeAutomatic: value]],
            options: [
                .localOnly: true,
                .expirationDate: lastCopyExpirationDate!
            ]
        )
        #elseif os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
        copyChangeCount = pasteboard.changeCount
        scheduleCleanupTimer()
        #endif
    }

    /// Clears the clipboard if the expiration interval has elapsed since the last copy.
    public func clearIfExpired() {
        guard let copyDate = lastCopyDate else { return }
        guard Date().timeIntervalSince(copyDate) >= Self.expirationInterval else { return }
        clearClipboard()
        lastCopyDate = nil
        lastCopyLocalOnly = false
        lastCopyExpirationDate = nil
    }
}

// MARK: - Platform-Specific Helpers

@available(macOS 14.0, iOS 17.0, *)
extension ClipboardManager {

    #if os(macOS)
    private func scheduleCleanupTimer() {
        cleanupTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + Self.expirationInterval)
        timer.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.clearClipboardIfOwned()
            }
        }
        cleanupTimer = timer
        timer.resume()
    }

    private func clearClipboardIfOwned() {
        let pasteboard = NSPasteboard.general
        if pasteboard.changeCount == copyChangeCount {
            pasteboard.clearContents()
        }
        lastCopyDate = nil
        lastCopyLocalOnly = false
        lastCopyExpirationDate = nil
        cleanupTimer?.cancel()
        cleanupTimer = nil
    }
    #endif

    fileprivate func clearClipboard() {
        #if os(iOS)
        UIPasteboard.general.items = []
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        cleanupTimer?.cancel()
        cleanupTimer = nil
        #endif
    }
}
