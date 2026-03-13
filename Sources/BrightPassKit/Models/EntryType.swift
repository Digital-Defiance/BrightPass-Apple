import Foundation

public enum EntryType: String, Codable, Equatable, CaseIterable, Sendable {
    case login
    case secureNote
    case creditCard
    case identityDocument
}
