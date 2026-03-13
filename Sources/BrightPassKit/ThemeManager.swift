import SwiftUI

/// Manages appearance mode (system, light, dark) with UserDefaults persistence.
/// The root view applies `.preferredColorScheme(themeManager.colorScheme)`.
@available(macOS 14.0, iOS 17.0, *)
@MainActor
@Observable
public class ThemeManager {

    private static let key = "appearance-mode"
    private let defaults: UserDefaults

    public var selectedAppearance: AppearanceMode {
        didSet {
            if oldValue != selectedAppearance {
                defaults.set(selectedAppearance.rawValue, forKey: Self.key)
            }
        }
    }

    /// Maps the current appearance mode to a SwiftUI `ColorScheme`.
    /// Returns `nil` for `.system` so the OS default is used.
    public var colorScheme: ColorScheme? {
        switch selectedAppearance {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.string(forKey: Self.key),
           let mode = AppearanceMode(rawValue: raw) {
            self.selectedAppearance = mode
        } else {
            self.selectedAppearance = .system
        }
    }
}
