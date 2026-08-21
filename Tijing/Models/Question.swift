import Foundation

struct QuestionMediaData: Codable, Hashable {
    var stem: [String]?
    var material: [String]?
    var options: [[String]]?
    var explanation: [String]?
    var count: Int?
    var cachedCount: Int?
    var externalCount: Int?

    enum CodingKeys: String, CodingKey {
        case stem, material, options, explanation, count
        case cachedCount = "cached_count"
        case externalCount = "external_count"
    }
}

struct Question: Codable, Identifiable, Hashable {
    let id: Int
    var stem: String
    var material: String?
    var options: [String]
    var media: QuestionMediaData?
    var optionOrder: [Int]?
    var questionType: String?
    var subject: String
    var topic: String
    var difficulty: Int?
    var source: String?
    var answer: Int?
    var answers: [Int]?
    var explanation: String?
    var year: Int?
    var region: String?
    var exam: String?
    var status: String?
    var correctRatio: Double?
    var totalCount: Int?
    var mostWrong: Int?
    var sourceDetail: String?
    var keypoints: [String]?
    var favorite: Bool?

    enum CodingKeys: String, CodingKey {
        case id, stem, material, options, media, subject, topic, difficulty, source, answer, answers, explanation, year, region, exam, status, favorite
        case optionOrder = "option_order"
        case questionType = "question_type"
        case correctRatio = "correct_ratio"
        case totalCount = "total_count"
        case mostWrong = "most_wrong"
        case sourceDetail = "source_detail"
        case keypoints
    }

    var isMultiple: Bool { questionType == "multiple" }
    var isJudgment: Bool { questionType == "judgment" }

    func preparedForDisplay() -> Question {
        let cleaned = Self.cleanOptionLabels(options)
        var copy = self
        copy.options = cleaned
        guard !isJudgment, cleaned.count > 1 else {
            copy.optionOrder = Array(cleaned.indices)
            return copy
        }

        var order = Array(cleaned.indices)
        for i in stride(from: order.count - 1, through: 1, by: -1) {
            let j = Int.random(in: 0...i)
            if i != j { order.swapAt(i, j) }
        }
        if order.enumerated().allSatisfy({ $0.offset == $0.element }), let first = order.first {
            order.removeFirst()
            order.append(first)
        }

        copy.optionOrder = order
        copy.options = order.map { cleaned[$0] }
        if let mediaOptions = media?.options {
            var newMedia = media
            newMedia?.options = order.map { index in index < mediaOptions.count ? mediaOptions[index] : [] }
            copy.media = newMedia
        }
        return copy
    }

    static func cleanOptionLabels(_ values: [String]) -> [String] {
        guard values.count >= 2 else { return values }
        let pattern = #"^\s*(?:[（(]\s*([A-EＡ-Ｅ])\s*[)）]|([A-EＡ-Ｅ])\s*[.．、:：])\s*(.+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return values }

        var parsed: [(label: String, text: String)] = []
        for value in values {
            let range = NSRange(value.startIndex..<value.endIndex, in: value)
            guard let match = regex.firstMatch(in: value, range: range), match.numberOfRanges >= 4 else { return values }
            let labelRange = match.range(at: 1).location != NSNotFound ? match.range(at: 1) : match.range(at: 2)
            let textRange = match.range(at: 3)
            guard let labelSwift = Range(labelRange, in: value), let textSwift = Range(textRange, in: value) else { return values }
            var label = String(value[labelSwift]).uppercased()
            if let scalar = label.unicodeScalars.first, scalar.value >= 0xFF21, scalar.value <= 0xFF25, let ascii = UnicodeScalar(65 + Int(scalar.value - 0xFF21)) {
                label = String(ascii)
            }
            let text = String(value[textSwift]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return values }
            parsed.append((label, text))
        }
        guard Set(parsed.map(\.label)).count == parsed.count else { return values }
        return parsed.map(\.text)
    }

    var cleanedOptions: [String] { Self.cleanOptionLabels(options) }

    func originalPick(from displayIndices: [Int]) -> [Int] {
        let order = optionOrder ?? Array(options.indices)
        return displayIndices.compactMap { index in order.indices.contains(index) ? order[index] : nil }.sorted()
    }

    func displayIndices(fromOriginal original: [Int]) -> [Int] {
        let order = optionOrder ?? Array(options.indices)
        return original.compactMap { value in order.firstIndex(of: value) }.sorted()
    }
}

struct PracticeSetResponse: Decodable {
    let items: [Question]
    let total: Int?
    let unseenTotal: Int?
    let fallbackCount: Int?
    enum CodingKeys: String, CodingKey {
        case items, total
        case unseenTotal = "unseen_total"
        case fallbackCount = "fallback_count"
    }
}

struct AnswerFeedback: Codable, Hashable {
    let correct: Bool
    let answer: Int?
    let answers: [Int]?
    let explanation: String?
    let media: QuestionMediaData?
    let favorite: Bool?
    let elapsedMS: Int?
    let correctRatio: Double?
    let totalCount: Int?
    let mostWrong: Int?
    let sourceDetail: String?
    let keypoints: [String]?

    enum CodingKeys: String, CodingKey {
        case correct, answer, answers, explanation, media, favorite
        case elapsedMS = "elapsed_ms"
        case correctRatio = "correct_ratio"
        case totalCount = "total_count"
        case mostWrong = "most_wrong"
        case sourceDetail = "source_detail"
        case keypoints
    }
}

struct PracticeAnswerBody: Encodable {
    let questionID: Int
    let picked: PickValue
    let elapsedMS: Int
    let mode: String
    enum CodingKeys: String, CodingKey {
        case mode, picked
        case questionID = "question_id"
        case elapsedMS = "elapsed_ms"
    }
}

enum PickValue: Encodable {
    case one(Int)
    case many([Int])
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .one(let value): try container.encode(value)
        case .many(let values): try container.encode(values)
        }
    }
}

struct PracticeBatchAnswerBody: Encodable {
    let questionID: Int
    let picked: PickValue
    let elapsedMS: Int
    enum CodingKeys: String, CodingKey {
        case picked
        case questionID = "question_id"
        case elapsedMS = "elapsed_ms"
    }
}

struct PracticeBatchSubmitBody: Encodable {
    let mode: String
    let answers: [PracticeBatchAnswerBody]
}

struct PracticeBatchResult: Decodable {
    let ok: Bool?
    let correct: Int
    let total: Int
    let score: Int
    let details: [PracticeBatchDetail]
}

struct PracticeBatchDetail: Decodable, Identifiable {
    let questionID: Int
    let stem: String?
    let material: String?
    let options: [String]?
    let picked: [Int]?
    let answer: Int?
    let answers: [Int]?
    let correct: Bool
    let explanation: String?
    let media: QuestionMediaData?
    let favorite: Bool?

    var id: Int { questionID }
    enum CodingKeys: String, CodingKey {
        case stem, material, options, picked, answer, answers, correct, explanation, media, favorite
        case questionID = "question_id"
    }
}

struct FavoriteResponse: Decodable {
    let favorite: Bool?
    let ok: Bool?
}
