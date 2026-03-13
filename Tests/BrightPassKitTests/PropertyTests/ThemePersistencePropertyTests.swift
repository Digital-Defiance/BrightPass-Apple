// Property 35: Theme Preference Persistence Round-Trip
// Validates: Requirements 27.3
//
// For any AppearanceMode, after setting it on ThemeManager, reading
// "appearance-mode" from UserDefaults and constructing an AppearanceMode
// produces the original mode.

import XCTest
@testable import BrightPassKit

@available(macOS 14.0, iOS 17.0, *)
final class ThemePersistencePropertyTests: XCTestCase {

    private func freshDefaults() -> UserDefaults {
        let suite = "test.theme.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    /// Property 35: For every AppearanceMode, setting it on ThemeManager
    /// persists the raw value to UserDefaults, and a new ThemeManager
    /// reading the same defaults produces the same mode.
    @MainActor
    func testThemePreferencePersistenceRoundTrip() {
        for _ in 0..<200 {
            let defaults = freshDefaults()
            let mode = AppearanceMode.allCases.randomElement()!

            // First set a non-system mode to ensure the key exists,
            // then set the target mode. This avoids the edge case where
            // the default is already .system and didSet skips the write.
            let tm = ThemeManager(defaults: defaults)
            let differentMode: AppearanceMode = (mode == .light) ? .dark : .light
            tm.selectedAppearance = differentMode
            tm.selectedAppearance = mode

            // Verify raw value in UserDefaults
            let raw = defaults.string(forKey: "appearance-mode")
            XCTAssertEqual(raw, mode.rawValue,
                           "UserDefaults should contain rawValue '\(mode.rawValue)', got '\(raw ?? "nil")'")

            // Verify round-trip through a new ThemeManager
            let tm2 = ThemeManager(defaults: defaults)
            XCTAssertEqual(tm2.selectedAppearance, mode,
                           "New ThemeManager should read back \(mode), got \(tm2.selectedAppearance)")
        }
    }

    /// Verify default is .system when no key is stored.
    @MainActor
    func testDefaultAppearanceIsSystem() {
        let defaults = freshDefaults()
        let tm = ThemeManager(defaults: defaults)
        XCTAssertEqual(tm.selectedAppearance, .system)
    }

    /// Verify colorScheme mapping for each mode.
    @MainActor
    func testColorSchemeMapping() {
        let defaults = freshDefaults()
        let tm = ThemeManager(defaults: defaults)

        tm.selectedAppearance = .system
        XCTAssertNil(tm.colorScheme)

        tm.selectedAppearance = .light
        XCTAssertEqual(tm.colorScheme, .light)

        tm.selectedAppearance = .dark
        XCTAssertEqual(tm.colorScheme, .dark)
    }
}
