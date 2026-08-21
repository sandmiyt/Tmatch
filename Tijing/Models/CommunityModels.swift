import Foundation

struct RankingResponse: Decodable {
    let items: [User]
    let season: SeasonPublicInfo?
    let seasonReset: Bool?
    enum CodingKeys: String, CodingKey {
        case items, season
        case seasonReset = "season_reset"
    }
}

struct NotificationListResponse: Decodable {
    let items: [AppNotification]
    let unread: Int?
}

struct AppNotification: Decodable, Identifiable, Hashable {
    let id: Int
    let kind: String
    let title: String
    let content: String
    let relatedUserID: Int?
    let relatedID: FlexibleID?
    let isRead: Bool
    let createdAt: String

    var isFriendChallenge: Bool { kind == "friend_challenge" || kind == "friend_challenge_result" }

    enum CodingKeys: String, CodingKey {
        case id, kind, title, content
        case relatedUserID = "related_user_id"
        case relatedID = "related_id"
        case isRead = "is_read"
        case createdAt = "created_at"
    }
}

enum FlexibleID: Decodable, Hashable {
    case int(Int)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Int.self) { self = .int(value); return }
        self = .string((try? container.decode(String.self)) ?? "")
    }
}

struct FriendListResponse: Decodable {
    let friends: [FriendRelation]
    let incoming: [FriendRelation]
    let outgoing: [FriendRelation]
}

struct FriendRelation: Decodable, Identifiable, Hashable {
    let relationID: Int
    let user: User
    let createdAt: String?
    var id: Int { relationID }
    enum CodingKeys: String, CodingKey {
        case user
        case relationID = "relation_id"
        case createdAt = "created_at"
    }
}

struct UserSearchResponse: Decodable {
    let items: [User]
}

struct PresenceResponse: Decodable {
    let items: [String: Bool]
}

struct ChallengeRoute: Identifiable, Hashable { let id: String }


struct SeasonPublicInfo: Decodable, Hashable {
    let key: String
    let label: String
    let endsAt: String?
    let daysLeft: Int
    let resetRule: String?
    let inheritanceRule: String?

    enum CodingKeys: String, CodingKey {
        case key, label
        case endsAt = "ends_at"
        case daysLeft = "days_left"
        case resetRule = "reset_rule"
        case inheritanceRule = "inheritance_rule"
    }
}

struct SeasonMeResponse: Decodable, Hashable {
    let season: SeasonPublicInfo
    let current: CurrentSeasonProgress
    let previous: SeasonResult?
    let history: [SeasonResult]
}

struct CurrentSeasonProgress: Decodable, Hashable {
    let position: Int
    let rating: Int
    let rank: String
    let startingRating: Int
    let peakRating: Int
    let peakRank: String
    let title: String
    let wins: Int
    let losses: Int
    let battleCount: Int
    let achievements: [SeasonAchievement]
    let achievementCount: Int
    let achievementTotal: Int

    enum CodingKeys: String, CodingKey {
        case position, rating, rank, title, wins, losses, achievements
        case startingRating = "starting_rating"
        case peakRating = "peak_rating"
        case peakRank = "peak_rank"
        case battleCount = "battle_count"
        case achievementCount = "achievement_count"
        case achievementTotal = "achievement_total"
    }
}

struct SeasonAchievement: Decodable, Hashable, Identifiable {
    let key: String
    let title: String
    let description: String
    let icon: String
    var id: String { key }
}

struct SeasonResult: Decodable, Hashable, Identifiable {
    let seasonKey: String
    let seasonLabel: String
    let finalPosition: Int
    let finalRating: Int
    let finalRank: String
    let startingRating: Int
    let peakRating: Int
    let inheritedRating: Int
    let inheritedRank: String
    let wins: Int
    let losses: Int
    let battleCount: Int
    let title: String
    let achievements: [SeasonAchievement]
    let report: SeasonReport?
    let settledAt: String?

    var id: String { seasonKey }
    enum CodingKeys: String, CodingKey {
        case title, wins, losses, achievements, report
        case seasonKey = "season_key"
        case seasonLabel = "season_label"
        case finalPosition = "final_position"
        case finalRating = "final_rating"
        case finalRank = "final_rank"
        case startingRating = "starting_rating"
        case peakRating = "peak_rating"
        case inheritedRating = "inherited_rating"
        case inheritedRank = "inherited_rank"
        case battleCount = "battle_count"
        case settledAt = "settled_at"
    }
}

struct SeasonReport: Decodable, Hashable {
    let summary: String?
    let maxWinStreak: Int?
    let achievementCount: Int?

    enum CodingKeys: String, CodingKey {
        case summary
        case maxWinStreak = "max_win_streak"
        case achievementCount = "achievement_count"
    }
}
