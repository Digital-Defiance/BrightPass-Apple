import Foundation

public struct AutofillPayload: Codable, Equatable, Sendable {
    public let entryId: String
    public let title: String
    public let username: String
    public let password: String
    public let url: String

    public init(entryId: String, title: String, username: String, password: String, url: String) {
        self.entryId = entryId
        self.title = title
        self.username = username
        self.password = password
        self.url = url
    }
}
