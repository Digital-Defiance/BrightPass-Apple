import Foundation

public enum SharePermission: String, Codable, Equatable, Sendable {
    case readOnly
    case readWrite
}

public struct SharedMember: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let memberId: String
    public let permission: SharePermission

    public init(id: String, memberId: String, permission: SharePermission) {
        self.id = id
        self.memberId = memberId
        self.permission = permission
    }
}
