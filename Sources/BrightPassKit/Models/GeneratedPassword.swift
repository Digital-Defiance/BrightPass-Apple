import Foundation

public struct GeneratedPassword: Codable, Equatable, Sendable {
    public let password: String
    public let strength: String?

    public init(password: String, strength: String? = nil) {
        self.password = password
        self.strength = strength
    }
}
