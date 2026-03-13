import Foundation

public struct PasswordOptions: Codable, Equatable, Sendable {
    public let length: Int
    public let includeUppercase: Bool
    public let includeLowercase: Bool
    public let includeDigits: Bool
    public let includeSpecial: Bool
    public let minUppercase: Int
    public let minDigits: Int
    public let minSpecial: Int

    public init(length: Int, includeUppercase: Bool, includeLowercase: Bool, includeDigits: Bool, includeSpecial: Bool, minUppercase: Int, minDigits: Int, minSpecial: Int) {
        self.length = length
        self.includeUppercase = includeUppercase
        self.includeLowercase = includeLowercase
        self.includeDigits = includeDigits
        self.includeSpecial = includeSpecial
        self.minUppercase = minUppercase
        self.minDigits = minDigits
        self.minSpecial = minSpecial
    }
}
