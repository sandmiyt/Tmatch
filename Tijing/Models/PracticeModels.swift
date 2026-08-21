import Foundation

struct PracticeCatalogResponse: Decodable {
    let subjects: [PracticeSubject]
}

struct PracticeSubject: Decodable, Identifiable, Hashable {
    let name: String
    let count: Int
    let answered: Int?
    let unseen: Int?
    let topics: [PracticeTopic]
    var id: String { name }
}

struct PracticeTopic: Decodable, Identifiable, Hashable {
    let topic: String
    let count: Int
    let answered: Int?
    let unseen: Int?
    let wrong: Int?
    let progress: Int?
    var id: String { topic }
}

struct PracticeSettings: Codable, Equatable {
    var questionCount = 15
    var difficulty = 0
    var difficultyMinRatio = 0
    var difficultyMaxRatio = 100
    var answerMode = "immediate"
    var preferUnseen = true

    enum CodingKeys: String, CodingKey {
        case difficulty
        case questionCount = "question_count"
        case difficultyMinRatio = "difficulty_min_ratio"
        case difficultyMaxRatio = "difficulty_max_ratio"
        case answerMode = "answer_mode"
        case preferUnseen = "prefer_unseen"
    }

    mutating func normalize() {
        questionCount = min(40, max(10, questionCount))
        difficultyMinRatio = min(100, max(0, difficultyMinRatio))
        difficultyMaxRatio = min(100, max(0, difficultyMaxRatio))
        if difficultyMinRatio > difficultyMaxRatio {
            let oldMin = difficultyMinRatio
            difficultyMinRatio = difficultyMaxRatio
            difficultyMaxRatio = oldMin
        }
        if difficultyMaxRatio - difficultyMinRatio < 30 {
            if difficultyMaxRatio >= 100 {
                difficultyMinRatio = 70
                difficultyMaxRatio = 100
            } else {
                difficultyMaxRatio = min(100, difficultyMinRatio + 30)
                if difficultyMaxRatio - difficultyMinRatio < 30 { difficultyMinRatio = max(0, difficultyMaxRatio - 30) }
            }
        }
        answerMode = answerMode == "submit" ? "submit" : "immediate"
        preferUnseen = true
    }
}

enum PracticeMode: String, Identifiable, CaseIterable {
    case random
    case wrong
    case favorite
    case smartReview = "smart_review"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .random: "专注刷题"
        case .wrong: "错题重练"
        case .favorite: "收藏练习"
        case .smartReview: "智能复习"
        }
    }
}
