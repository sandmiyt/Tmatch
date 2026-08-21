import Foundation

struct User: Codable, Identifiable, Hashable {
    let id: Int
    var username: String?
    var nickname: String
    var rating: Int
    var rank: String
    var wins: Int
    var losses: Int
    var isAdmin: Bool?
    var avatarURL: String?
    var bio: String?
    var gender: String?
    var pendingAvatarURL: String?
    var avatarReviewStatus: String?
    var position: Int?
    var questions: Int?
    var accuracy: Double?
    var winRate: Double?
    var battleCount: Int?
    var friendCount: Int?
    var friendStatus: String?
    var relationID: Int?
    var online: Bool?
    var blockedByMe: Bool?
    var blockedMe: Bool?

    enum CodingKeys: String, CodingKey {
        case id, username, nickname, rating, rank, wins, losses, bio, gender, position, questions, accuracy, online
        case isAdmin = "is_admin"
        case avatarURL = "avatar_url"
        case pendingAvatarURL = "pending_avatar_url"
        case avatarReviewStatus = "avatar_review_status"
        case winRate = "win_rate"
        case battleCount = "battle_count"
        case friendCount = "friend_count"
        case friendStatus = "friend_status"
        case relationID = "relation_id"
        case blockedByMe = "blocked_by_me"
        case blockedMe = "blocked_me"
    }
}

struct StatsResponse: Decodable {
    let questions: Int?
    let correct: Int?
    let accuracy: Double?
    let accuracy7d: Double?
    let questions7d: Int?
    let winRate: Double?
    let battleCount: Int?
    let rating: Int?
    let wins: Int?
    let losses: Int?
    let wrong: Int?
    let favorites: Int?

    enum CodingKeys: String, CodingKey {
        case questions, correct, accuracy, rating, wins, losses, wrong, favorites
        case accuracy7d = "accuracy_7d"
        case questions7d = "questions_7d"
        case winRate = "win_rate"
        case battleCount = "battle_count"
    }
}

struct ProfileBody: Encodable {
    let nickname: String
    let bio: String
    let gender: String
}
