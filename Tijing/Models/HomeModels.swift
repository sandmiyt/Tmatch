import Foundation

struct DailyChallengeSummary: Decodable {
    let challengeID: String?
    let challengerCount: Int?
    let myBest: ChallengeAttemptSummary?

    enum CodingKeys: String, CodingKey {
        case challengeID = "challenge_id"
        case challengerCount = "challenger_count"
        case myBest = "my_best"
    }
}

struct ChallengeAttemptSummary: Decodable {
    let correctCount: Int?
    let elapsedMS: Int?
    enum CodingKeys: String, CodingKey {
        case correctCount = "correct_count"
        case elapsedMS = "elapsed_ms"
    }
}

struct SmartReviewSummary: Decodable {
    let due: Int?
    let pending: Int?
    let mastered: Int?
}

struct LearningDiagnostics: Decodable {
    let overview: LearningOverview
    let analysis: LearningAnalysis
    let subjects: [LearningProfileItem]
    let weakSubjects: [LearningProfileItem]?
    let weakTopics: [LearningProfileItem]?
    let recommendation: LearningRecommendation?

    enum CodingKeys: String, CodingKey {
        case overview, analysis, subjects, recommendation
        case weakSubjects = "weak_subjects"
        case weakTopics = "weak_topics"
    }
}

struct LearningOverview: Decodable {
    let totalQuestions: Int
    let sevenDayTotal: Int
    let sevenDayAccuracy: Int
    let recent100Total: Int
    let recent100Accuracy: Int
    let previous100Accuracy: Int
    let recent100Trend: Int
    let averageElapsedMS: Int
    let medianElapsedMS: Int

    enum CodingKeys: String, CodingKey {
        case totalQuestions = "total_questions"
        case sevenDayTotal = "seven_day_total"
        case sevenDayAccuracy = "seven_day_accuracy"
        case recent100Total = "recent100_total"
        case recent100Accuracy = "recent100_accuracy"
        case previous100Accuracy = "previous100_accuracy"
        case recent100Trend = "recent100_trend"
        case averageElapsedMS = "average_elapsed_ms"
        case medianElapsedMS = "median_elapsed_ms"
    }
}

struct LearningAnalysis: Decodable {
    let recordsUsed: Int
    let historyTotal: Int
    let confidence: Int
    let baselineAccuracy: Int
    let baselineElapsedMS: Int
    let insights: [LearningInsight]
    let summary: LearningSummary

    enum CodingKeys: String, CodingKey {
        case confidence, insights, summary
        case recordsUsed = "records_used"
        case historyTotal = "history_total"
        case baselineAccuracy = "baseline_accuracy"
        case baselineElapsedMS = "baseline_elapsed_ms"
    }
}

struct LearningInsight: Decodable, Hashable, Identifiable {
    let type: String
    let title: String
    let detail: String
    var id: String { type + "|" + title + "|" + detail }
}

struct LearningSummary: Decodable {
    let title: String
    let detail: String
    let focus: LearningFocus?
}

struct LearningFocus: Decodable, Hashable {
    let title: String
    let detail: String
    let subject: String?
    let topic: String?
    let signals: [String]
    let signalBasis: String?

    enum CodingKeys: String, CodingKey {
        case title, detail, subject, topic, signals
        case signalBasis = "signal_basis"
    }
}

struct LearningProfileItem: Decodable, Hashable, Identifiable {
    let name: String
    let subject: String?
    let topic: String?
    let total: Int
    let correct: Int
    let recentTotal: Int
    let recentCorrect: Int
    let accuracy: Int
    let recentAccuracy: Int
    let analyzedAccuracy: Int
    let mastery: Int
    let priorityScore: Int
    let confidence: Int
    let medianElapsedMS: Int
    let paceDeltaPct: Int
    let trendPoints: Int
    let recentWrongRatio: Int
    let leadingLapses: Int
    let priorityRank: Int?
    let status: String?

    var id: String { (subject ?? name) + "|" + (topic ?? "_") }

    enum CodingKeys: String, CodingKey {
        case name, subject, topic, total, correct, accuracy, mastery, confidence, status
        case recentTotal = "recent_total"
        case recentCorrect = "recent_correct"
        case recentAccuracy = "recent_accuracy"
        case analyzedAccuracy = "analyzed_accuracy"
        case priorityScore = "priority_score"
        case medianElapsedMS = "median_elapsed_ms"
        case paceDeltaPct = "pace_delta_pct"
        case trendPoints = "trend_points"
        case recentWrongRatio = "recent_wrong_ratio"
        case leadingLapses = "leading_lapses"
        case priorityRank = "priority_rank"
    }
}

struct LearningRecommendation: Decodable, Hashable {
    let name: String?
    let subject: String?
    let topic: String?
    let reasons: [String]?
    let analysisBasis: String?

    enum CodingKeys: String, CodingKey {
        case name, subject, topic, reasons
        case analysisBasis = "analysis_basis"
    }
}

struct ChallengeDetail: Decodable, Hashable {
    let challengeID: String
    let kind: String
    let dayKey: String?
    let subject: String?
    let topic: String?
    let expiresAt: String?
    let expired: Bool
    let questionCount: Int
    var questions: [ChallengeQuestion]
    let myAttempt: ChallengeAttempt?
    let submitted: ChallengeAttempt?
    var review: [ChallengeReviewItem]?
    let ranking: [ChallengeRankingItem]?
    let challengerCount: Int?
    let creator: ChallengeUser?
    let target: ChallengeUser?
    let creatorAttempt: ChallengeAttempt?
    let targetAttempt: ChallengeAttempt?

    enum CodingKeys: String, CodingKey {
        case kind, expired, questions, submitted, review, ranking, subject, topic, creator, target
        case challengeID = "challenge_id"
        case dayKey = "day_key"
        case expiresAt = "expires_at"
        case questionCount = "question_count"
        case myAttempt = "my_attempt"
        case challengerCount = "challenger_count"
        case creatorAttempt = "creator_attempt"
        case targetAttempt = "target_attempt"
    }

    var isDaily: Bool { kind == "daily" }
    var isFriend: Bool { kind == "friend" }
}

struct ChallengeQuestion: Decodable, Identifiable, Hashable {
    let questionID: Int
    let stem: String
    let material: String?
    let options: [String]
    let media: QuestionMediaData?
    let stemBlocks: [QuestionContentBlock]?
    let materialBlocks: [QuestionContentBlock]?
    let optionBlocks: [[QuestionContentBlock]]?
    let questionType: String?
    let subject: String?
    let topic: String?
    var favorite: Bool?

    var id: Int { questionID }

    private var normalizedQuestionType: String {
        (questionType ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }

    var isMultiple: Bool {
        ["multiple", "multi", "multiple_choice", "multiplechoice", "multiple_select", "multiselect", "多选", "多选题"].contains(normalizedQuestionType)
    }

    var isJudgment: Bool {
        ["judgment", "judgement", "judge", "true_false", "truefalse", "boolean", "bool", "判断", "判断题"].contains(normalizedQuestionType)
    }

    var questionTypeLabel: String {
        if isMultiple { return "多选题" }
        if isJudgment { return "判断题" }
        return "单选题"
    }

    enum CodingKeys: String, CodingKey {
        case stem, material, options, media, subject, topic, favorite
        case stemBlocks = "stem_blocks"
        case materialBlocks = "material_blocks"
        case optionBlocks = "option_blocks"
        case questionID = "question_id"
        case questionType = "question_type"
    }
}

struct ChallengeAttempt: Decodable, Hashable {
    let userID: Int?
    let nickname: String?
    let avatarURL: String?
    let correctCount: Int
    let elapsedMS: Int
    let attemptCount: Int?
    let completedAt: String?

    enum CodingKeys: String, CodingKey {
        case nickname
        case userID = "user_id"
        case avatarURL = "avatar_url"
        case correctCount = "correct_count"
        case elapsedMS = "elapsed_ms"
        case attemptCount = "attempt_count"
        case completedAt = "completed_at"
    }
}

struct ChallengeUser: Decodable, Hashable, Identifiable {
    let id: Int
    let nickname: String
    let avatarURL: String?
    enum CodingKeys: String, CodingKey { case id, nickname; case avatarURL = "avatar_url" }
}

struct ChallengeRankingItem: Decodable, Hashable, Identifiable {
    let userID: Int
    let nickname: String?
    let avatarURL: String?
    let correctCount: Int
    let elapsedMS: Int
    let position: Int

    var id: Int { userID }
    enum CodingKeys: String, CodingKey {
        case nickname, position
        case userID = "user_id"
        case avatarURL = "avatar_url"
        case correctCount = "correct_count"
        case elapsedMS = "elapsed_ms"
    }
}

struct ChallengeReviewItem: Decodable, Identifiable, Hashable {
    let questionID: Int
    let stem: String
    let material: String?
    let options: [String]
    let media: QuestionMediaData?
    let questionType: String?
    let answer: Int
    let answers: [Int]?
    let picked: Int
    let picks: [Int]?
    let correct: Bool
    let explanation: String?
    let subject: String?
    let topic: String?
    var favorite: Bool?

    var id: Int { questionID }
    var correctAnswers: [Int] { answers?.isEmpty == false ? answers!.sorted() : (answer >= 0 ? [answer] : []) }
    var selectedAnswers: [Int] { picks?.isEmpty == false ? picks!.sorted() : (picked >= 0 ? [picked] : []) }

    private var normalizedQuestionType: String {
        (questionType ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }

    var questionTypeLabel: String {
        if ["multiple", "multi", "multiple_choice", "multiplechoice", "multiple_select", "multiselect", "多选", "多选题"].contains(normalizedQuestionType) || correctAnswers.count > 1 { return "多选题" }
        if ["judgment", "judgement", "judge", "true_false", "truefalse", "boolean", "bool", "判断", "判断题"].contains(normalizedQuestionType) { return "判断题" }
        return "单选题"
    }

    enum CodingKeys: String, CodingKey {
        case stem, material, options, media, answer, answers, picked, picks, correct, explanation, subject, topic, favorite
        case questionID = "question_id"
        case questionType = "question_type"
    }
}

struct ChallengeSubmitBody: Encodable {
    let answers: [String: PickValue]
    let elapsedMS: Int
    enum CodingKeys: String, CodingKey { case answers; case elapsedMS = "elapsed_ms" }
}

extension FlexibleID {
    var stringValue: String {
        switch self {
        case .int(let value): String(value)
        case .string(let value): value
        }
    }
}
