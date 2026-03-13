import Foundation

/// Response from `POST /api/user/request-direct-login`.
/// Contains the hex-encoded challenge buffer and server public key for ECIES direct challenge auth.
public struct DirectLoginChallenge: Codable, Equatable, Sendable {
    /// Hex-encoded challenge buffer (timestamp + nonce + server signature).
    public let challenge: String
    public let message: String
    /// Hex-encoded server ECIES public key.
    public let serverPublicKey: String

    public init(challenge: String, message: String, serverPublicKey: String) {
        self.challenge = challenge
        self.message = message
        self.serverPublicKey = serverPublicKey
    }
}

/// Response from `POST /api/user/direct-challenge`.
/// Contains the JWT, user profile, and server public key after successful challenge verification.
public struct DirectChallengeResponse: Codable, Equatable, Sendable {
    public let message: String
    public let user: UserProfile
    /// JWT token with 7-day expiry.
    public let token: String
    public let serverPublicKey: String

    public init(message: String, user: UserProfile, token: String, serverPublicKey: String) {
        self.message = message
        self.user = user
        self.token = token
        self.serverPublicKey = serverPublicKey
    }
}

/// Response from `GET /api/user/verify`.
/// Wraps the user profile with a message field.
public struct VerifyTokenResponse: Codable, Equatable, Sendable {
    public let message: String
    public let user: UserProfile

    public init(message: String, user: UserProfile) {
        self.message = message
        self.user = user
    }
}

/// A role object returned by the server.
public struct UserRole: Codable, Equatable, Sendable {
    public let _id: String
    public let name: String
    public let admin: Bool
    public let member: Bool
    public let child: Bool
    public let system: Bool
    public let createdAt: String?
    public let updatedAt: String?
    public let createdBy: String?
    public let updatedBy: String?

    public init(_id: String, name: String, admin: Bool, member: Bool, child: Bool, system: Bool,
                createdAt: String? = nil, updatedAt: String? = nil,
                createdBy: String? = nil, updatedBy: String? = nil) {
        self._id = _id
        self.name = name
        self.admin = admin
        self.member = member
        self.child = child
        self.system = system
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.createdBy = createdBy
        self.updatedBy = updatedBy
    }
}

/// Flattened role privilege flags.
public struct RolePrivileges: Codable, Equatable, Sendable {
    public let admin: Bool
    public let member: Bool
    public let child: Bool
    public let system: Bool

    public init(admin: Bool, member: Bool, child: Bool, system: Bool) {
        self.admin = admin
        self.member = member
        self.child = child
        self.system = system
    }
}

/// User profile returned in auth responses.
public struct UserProfile: Codable, Equatable, Sendable {
    public let id: String
    public let username: String
    public let email: String
    public let roles: [UserRole]
    public let rolePrivileges: RolePrivileges?
    public let emailVerified: Bool
    public let timezone: String
    public let siteLanguage: String
    public let darkMode: Bool
    public let currency: String
    public let directChallenge: Bool
    public let lastLogin: String?

    public init(id: String, username: String, email: String, roles: [UserRole],
                rolePrivileges: RolePrivileges? = nil,
                emailVerified: Bool, timezone: String, siteLanguage: String,
                darkMode: Bool, currency: String, directChallenge: Bool, lastLogin: String?) {
        self.id = id
        self.username = username
        self.email = email
        self.roles = roles
        self.rolePrivileges = rolePrivileges
        self.emailVerified = emailVerified
        self.timezone = timezone
        self.siteLanguage = siteLanguage
        self.darkMode = darkMode
        self.currency = currency
        self.directChallenge = directChallenge
        self.lastLogin = lastLogin
    }
}


/// Response from `POST /api/user/register` and `POST /api/user/login` (password-based fallback).
public struct AuthResponse: Codable, Equatable, Sendable {
    public let message: String
    public let data: AuthResponseData

    public init(message: String, data: AuthResponseData) {
        self.message = message
        self.data = data
    }
}

/// Payload nested inside `AuthResponse`.
public struct AuthResponseData: Codable, Equatable, Sendable {
    public let token: String
    public let memberId: String
    public let energyBalance: Int

    public init(token: String, memberId: String, energyBalance: Int) {
        self.token = token
        self.memberId = memberId
        self.energyBalance = energyBalance
    }
}
