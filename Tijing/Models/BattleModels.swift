import Foundation

struct BattlePlayer: Codable, Identifiable, Hashable {
    let id: Int
    let nickname: String
    let avatarURL: String?
    let rating: Int
    let rank: String?
    let ratingDelta: Int?
    let score: Int
    let correct: Int
    let connected: Bool
    let isAI: Bool?
    let progress: Int?
    let completedElapsedMS: Int?

    enum CodingKeys: String, CodingKey {
        case id, nickname, rating, rank, score, correct, connected, progress
        case avatarURL = "avatar_url"
        case ratingDelta = "rating_delta"
        case isAI = "is_ai"
        case completedElapsedMS = "completed_elapsed_ms"
    }
}

struct BattleFeedback: Codable, Hashable {
    let questionIndex: Int
    let picked: [Int]
    let correct: Bool
    let answer: [Int]
    let explanation: String?

    enum CodingKeys: String, CodingKey {
        case picked, correct, answer, answers, explanation
        case questionIndex = "question_index"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        questionIndex = try container.decode(Int.self, forKey: .questionIndex)
        correct = try container.decode(Bool.self, forKey: .correct)
        explanation = try container.decodeIfPresent(String.self, forKey: .explanation)
        picked = try Self.decodeSelection(container, keys: [.picked])
        answer = try Self.decodeSelection(container, keys: [.answers, .answer])
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(questionIndex, forKey: .questionIndex)
        try container.encode(correct, forKey: .correct)
        try container.encodeIfPresent(explanation, forKey: .explanation)
        try Self.encodeSelection(picked, container: &container, key: .picked)
        try Self.encodeSelection(answer, container: &container, key: .answer)
    }

    private static func decodeSelection(_ container: KeyedDecodingContainer<CodingKeys>, keys: [CodingKeys]) throws -> [Int] {
        for key in keys {
            if let values = try? container.decode([Int].self, forKey: key) { return values.sorted() }
            if let value = try? container.decode(Int.self, forKey: key) { return [value] }
        }
        return []
    }

    private static func encodeSelection(_ values: [Int], container: inout KeyedEncodingContainer<CodingKeys>, key: CodingKeys) throws {
        if values.count == 1, let value = values.first { try container.encode(value, forKey: key) }
        else { try container.encode(values, forKey: key) }
    }
}

struct BattleState: Codable, Hashable {
    let type: String?
    let roomID: String
    let mode: String
    let rule: String
    let subject: String?
    let topic: String?
    let joinCode: String?
    let players: [BattlePlayer]
    let questionIndex: Int
    let sharedQuestionIndex: Int
    let total: Int
    let question: Question?
    let waitingOpponent: Bool?
    let finished: Bool
    let outcome: String?
    let myFeedback: BattleFeedback?
    let secondsLeft: Int?
    let roundSecondsLeft: Int?
    let forfeitedBy: Int?

    enum CodingKeys: String, CodingKey {
        case type, mode, rule, subject, topic, players, total, question, finished, outcome
        case roomID = "room_id"
        case joinCode = "join_code"
        case questionIndex = "question_index"
        case sharedQuestionIndex = "shared_question_index"
        case waitingOpponent = "waiting_opponent"
        case myFeedback = "my_feedback"
        case secondsLeft = "seconds_left"
        case roundSecondsLeft = "round_seconds_left"
        case forfeitedBy = "forfeited_by"
    }
}

struct ActiveBattleResponse: Decodable {
    let active: Bool
    let roomID: String?
    let state: BattleState?
    enum CodingKeys: String, CodingKey { case active, state; case roomID = "room_id" }
}

struct BattleCreateResponse: Decodable {
    let status: String?
    let roomID: String?
    let code: String?
    let joinCode: String?
    let state: BattleState?
    let error: String?
    enum CodingKeys: String, CodingKey {
        case status, code, state, error
        case roomID = "room_id"
        case joinCode = "join_code"
    }

    var resolvedRoomID: String? { roomID ?? state?.roomID }
}

struct MatchmakingResponse: Decodable {
    let status: String
    let roomID: String?
    let state: BattleState?
    let matchStage: String?
    let waitSeconds: Int?
    let rankExpandIn: Int?
    let nextExpandIn: Int?
    let error: String?
    enum CodingKeys: String, CodingKey {
        case status, state, error
        case roomID = "room_id"
        case matchStage = "match_stage"
        case waitSeconds = "wait_seconds"
        case rankExpandIn = "rank_expand_in"
        case nextExpandIn = "next_expand_in"
    }
}

struct BattleModeBody: Encodable {
    let rule: String
    let subject: String?
    let topic: String?
}

struct JoinRoomBody: Encodable { let code: String }

struct BattleAnswerBody: Encodable {
    let questionIndex: Int
    let picked: PickValue
    enum CodingKeys: String, CodingKey { case picked; case questionIndex = "question_index" }
}


struct BattleReviewResponse: Decodable {
    let review: BattleReview?
}

struct BattleReview: Decodable, Hashable {
    let reason: String
    let myAccuracy: Int
    let opponentAccuracy: Int
    let myAvgElapsedMS: Int?
    let opponentAvgElapsedMS: Int?
    let myAvgCorrectElapsedMS: Int?
    let opponentAvgCorrectElapsedMS: Int?
    let weakSubjects: [BattleReviewWeakSubject]
    let keyRounds: [BattleReviewRound]

    enum CodingKeys: String, CodingKey {
        case reason
        case myAccuracy = "my_accuracy"
        case opponentAccuracy = "opponent_accuracy"
        case myAvgElapsedMS = "my_avg_elapsed_ms"
        case opponentAvgElapsedMS = "opponent_avg_elapsed_ms"
        case myAvgCorrectElapsedMS = "my_avg_correct_elapsed_ms"
        case opponentAvgCorrectElapsedMS = "opponent_avg_correct_elapsed_ms"
        case weakSubjects = "weak_subjects"
        case keyRounds = "key_rounds"
    }
}

struct BattleReviewWeakSubject: Decodable, Hashable, Identifiable {
    let subject: String
    let total: Int
    let wrong: Int
    let wrongRate: Int?
    var id: String { subject }
    enum CodingKeys: String, CodingKey {
        case subject, total, wrong
        case wrongRate = "wrong_rate"
    }
}

struct BattleReviewRound: Decodable, Hashable, Identifiable {
    let questionIndex: Int
    let questionID: Int?
    let subject: String?
    let topic: String?
    let stem: String?
    let kind: String?
    let label: String?
    let detail: String
    var id: String { "\(questionIndex)-\(questionID ?? -1)-\(kind ?? "")" }

    enum CodingKeys: String, CodingKey {
        case subject, topic, stem, kind, label, detail
        case questionIndex = "question_index"
        case questionID = "question_id"
    }
}
