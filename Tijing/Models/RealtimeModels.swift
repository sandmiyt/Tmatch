import Foundation

struct FriendBattleInvite: Decodable, Identifiable, Hashable {
    let id: String
    let roomID: String
    let expiresAt: Double?
    let subject: String?
    let topic: String?
    let inviter: User

    enum CodingKeys: String, CodingKey {
        case id, subject, topic, inviter
        case roomID = "room_id"
        case expiresAt = "expires_at"
    }
}

struct RealtimeEnvelope: Decodable {
    let type: String
    let unread: Int?
    let invite: FriendBattleInvite?
}

struct RealtimeFallbackResponse: Decodable {
    let unread: Int
    let invite: FriendBattleInvite?
}

struct PendingInviteResponse: Decodable {
    let invite: FriendBattleInvite?
}
