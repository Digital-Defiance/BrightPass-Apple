import Foundation

// MARK: - Vault Locked Notification

public extension Notification.Name {
    /// Posted when the auto-lock timer fires or the vault is manually locked.
    static let vaultLocked = Notification.Name("BrightPassVaultLocked")
}

// MARK: - AutoLockManager

/// Manages automatic vault locking based on user inactivity and app lifecycle events.
@available(macOS 14.0, iOS 17.0, *)
@MainActor
@Observable
public class AutoLockManager {

    /// Configurable inactivity timeout in minutes, clamped to [1, 60].
    /// Uses a backing store to avoid infinite recursion with @Observable's
    /// synthesized accessors when clamping in didSet.
    public var timeoutMinutes: Int {
        get { _timeoutMinutes }
        set { _timeoutMinutes = max(1, min(60, newValue)) }
    }
    @ObservationIgnored private var _timeoutMinutes: Int = 15

    /// Whether the vault is currently locked.
    public var isLocked: Bool = false

    @ObservationIgnored private var inactivityTimer: Timer?
    @ObservationIgnored private var acceleratedTimer: Timer?

    @ObservationIgnored private let acceleratedInterval: TimeInterval = 5 * 60

    public init() {}

    // MARK: - Standard Inactivity Timer

    /// Resets the inactivity timer on user interaction.
    public func resetTimer() {
        inactivityTimer?.invalidate()
        inactivityTimer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(timeoutMinutes) * 60,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.lock()
            }
        }
    }

    // MARK: - Accelerated Timer (iOS Background)

    /// Starts a 5-minute accelerated lock timer for iOS background.
    public func startAcceleratedTimer() {
        acceleratedTimer?.invalidate()
        acceleratedTimer = Timer.scheduledTimer(
            withTimeInterval: acceleratedInterval,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.lock()
            }
        }
    }

    /// Cancels the accelerated timer and resumes the standard timer.
    public func cancelAcceleratedTimer() {
        acceleratedTimer?.invalidate()
        acceleratedTimer = nil
        resetTimer()
    }

    // MARK: - Lock

    /// Locks the vault and posts a `.vaultLocked` notification.
    public func lock() {
        isLocked = true
        NotificationCenter.default.post(name: .vaultLocked, object: self)
    }
}
