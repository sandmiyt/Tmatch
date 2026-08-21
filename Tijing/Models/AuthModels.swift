import Foundation

struct AuthCredentials: Decodable {
    let username: String?
    let email: String?
}

struct AuthResponse: Decodable {
    let token: String
    let user: User
    let credentials: AuthCredentials?
}

struct LoginBody: Encodable {
    let nickname: String?
    let username: String?
    let password: String
}

struct RegisterBody: Encodable {
    let nickname: String
    let password: String
    let email: String
    let emailCode: String

    enum CodingKeys: String, CodingKey {
        case nickname, password, email
        case emailCode = "email_code"
    }
}

struct EmailBody: Encodable { let email: String }
struct AccountBody: Encodable { let account: String }

struct RecoveryResetBody: Encodable {
    let account: String
    let emailCode: String
    let newPassword: String
    enum CodingKeys: String, CodingKey {
        case account
        case emailCode = "email_code"
        case newPassword = "new_password"
    }
}

struct CodeResponse: Decodable {
    let ok: Bool?
    let email: String?
    let expiresIn: Int?
    let resendIn: Int?

    enum CodingKeys: String, CodingKey {
        case ok, email
        case expiresIn = "expires_in"
        case resendIn = "resend_in"
    }
}

struct RecoveryResponse: Decodable {
    let token: String?
    let user: User?
    let username: String?
    let email: String?
    let bannedUntil: String?
    let ok: Bool?
    enum CodingKeys: String, CodingKey {
        case token, user, username, email, ok
        case bannedUntil = "banned_until"
    }
}
