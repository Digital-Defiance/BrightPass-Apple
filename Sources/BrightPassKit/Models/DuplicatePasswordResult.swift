import Foundation

public struct DuplicatePasswordResult: Equatable, Sendable {
    public let isDuplicate: Bool
    public let duplicateCount: Int
    public let duplicateEntryIds: [String]

    public init(isDuplicate: Bool, duplicateCount: Int, duplicateEntryIds: [String]) {
        self.isDuplicate = isDuplicate
        self.duplicateCount = duplicateCount
        self.duplicateEntryIds = duplicateEntryIds
    }
}
