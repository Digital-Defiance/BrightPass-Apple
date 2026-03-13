import Foundation

public struct DecryptedVault: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let entries: [EntryPropertyRecord]

    public init(id: String, name: String, entries: [EntryPropertyRecord]) {
        self.id = id
        self.name = name
        self.entries = entries
    }
}
