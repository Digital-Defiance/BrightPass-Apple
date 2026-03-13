import Foundation

public struct RecentEntryReference: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let entryId: String
    public let vaultId: String
    public let title: String
    public let accessedAt: Date

    public init(id: String, entryId: String, vaultId: String, title: String, accessedAt: Date) {
        self.id = id
        self.entryId = entryId
        self.vaultId = vaultId
        self.title = title
        self.accessedAt = accessedAt
    }
}
