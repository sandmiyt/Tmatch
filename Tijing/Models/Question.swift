import Foundation

struct QuestionMediaData: Codable, Hashable {
    var stem: [String]?
    var material: [String]?
    var options: [[String]]?
    var explanation: [String]?
    var count: Int?
    var cachedCount: Int?
    var externalCount: Int?
    var types: QuestionMediaTypeData?
    var layout: QuestionContentLayoutData?

    enum CodingKeys: String, CodingKey {
        case stem, material, options, explanation, count, types, layout
        case cachedCount = "cached_count"
        case externalCount = "external_count"
    }

    func optionTypes(at index: Int) -> [String] {
        guard let values = types?.options, values.indices.contains(index) else { return [] }
        return values[index]
    }

    func optionLayout(at index: Int) -> [QuestionContentBlock] {
        guard let values = layout?.options, values.indices.contains(index) else { return [] }
        return values[index]
    }
}

struct QuestionMediaTypeData: Codable, Hashable {
    var stem: [String]?
    var material: [String]?
    var options: [[String]]?
    var explanation: [String]?
}

struct QuestionContentLayoutData: Codable, Hashable {
    var stem: [QuestionContentBlock]?
    var material: [QuestionContentBlock]?
    var options: [[QuestionContentBlock]]?
    var explanation: [QuestionContentBlock]?
}

struct QuestionContentBlock: Codable, Hashable {
    let type: String
    let text: String?
    let url: String?
    let mediaType: String?

    enum CodingKeys: String, CodingKey {
        case type, text, url
        case mediaType = "media_type"
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

    // Compatibility accessors for battle screens created before rich-media layout
    // became a nested QuestionMediaData field. Keep the old call sites source-safe
    // without duplicating or changing the underlying payload.
    var stemBlocks: [QuestionContentBlock]? { media?.layout?.stem }
    var materialBlocks: [QuestionContentBlock]? { media?.layout?.material }
    var optionBlocks: [[QuestionContentBlock]]? { media?.layout?.options }
    var explanationBlocks: [QuestionContentBlock]? { media?.layout?.explanation }

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

    private var normalizedQuestionType: String {
        (questionType ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }

    var isMultiple: Bool {
        ["multiple", "multi", "multiple_choice", "multiplechoice", "multiple_select", "multiselect", "多选", "多选题"].contains(normalizedQuestionType) || (answers?.count ?? 0) > 1
    }

    var isJudgment: Bool {
        ["judgment", "judgement", "judge", "true_false", "truefalse", "boolean", "bool", "判断", "判断题"].contains(normalizedQuestionType)
    }

    var questionTypeLabel: String {
        if isMultiple { return "多选题" }
        if isJudgment { return "判断题" }
        return "单选题"
    }

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
            if let typeOptions = media?.types?.options, var newTypes = newMedia?.types {
                newTypes.options = order.map { index in index < typeOptions.count ? typeOptions[index] : [] }
                newMedia?.types = newTypes
            }
            if let layoutOptions = media?.layout?.options, var newLayout = newMedia?.layout {
                newLayout.options = order.map { index in index < layoutOptions.count ? layoutOptions[index] : [] }
                newMedia?.layout = newLayout
            }
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

    static func shouldShowOptionText(_ value: String, hasMedia: Bool) -> Bool {
        guard hasMedia else { return true }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
        return !["图片选项", "图片", "图示选项", "选项图片"].contains(normalized)
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

    func explanationForDisplay(_ text: String) -> String {
        let order = optionOrder ?? Array(options.indices)
        guard order.count == options.count else { return text }
        return QuestionExplanationFormatter.remap(text, order: order)
    }
}

/// Uses the same display-to-original permutation as answer submission. Keep this
/// shared by inline feedback and batch results; never infer answers from prose.
enum QuestionExplanationFormatter {
    private static let referencePattern = #"(?<![A-Za-z0-9_Ａ-Ｚａ-ｚ０-９])([A-EＡ-Ｅ]{1,5})(?![A-Za-z0-9_Ａ-Ｚａ-ｚ０-９])"#
    private static let groupSuffixPattern = #"^\s*(?:[一二三四五两0-9]+)?(?:个)?(?:选项|项|正确|错误|均|都|符合|不符合|不正确|当选|入选|排除|适宜|适用)"#
    private static let groupPrefixPattern = #"(?:答案|应选|选择|选|排除)\s*(?:应为|应是|为|是|[:：])?\s*[（(【]?\s*$"#

    static func remap(_ text: String, order: [Int]) -> String {
        guard !text.isEmpty, !order.isEmpty, order.sorted() == Array(order.indices),
              let regex = try? NSRegularExpression(pattern: referencePattern) else { return text }
        var inverse: [Int: Int] = [:]
        for (display, original) in order.enumerated() { inverse[original] = display }
        let source = text as NSString
        let result = NSMutableString(string: text)
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: source.length))
        for match in matches.reversed() {
            let range = match.range(at: 1)
            let token = source.substring(with: range)
            if token.count > 1 {
                let beforeStart = max(0, range.location - 24)
                let before = source.substring(with: NSRange(location: beforeStart, length: range.location - beforeStart))
                let afterStart = NSMaxRange(range)
                let after = source.substring(with: NSRange(location: afterStart, length: min(24, source.length - afterStart)))
                guard before.range(of: groupPrefixPattern, options: .regularExpression) != nil
                        || after.range(of: groupSuffixPattern, options: .regularExpression) != nil else { continue }
            }
            let replacement = token.unicodeScalars.map { scalar -> String in
                let base = scalar.value >= 0xFF21 ? 0xFF21 : 65
                let original = Int(scalar.value) - base
                let display = inverse[original] ?? original
                guard let mapped = UnicodeScalar(base + display) else { return String(scalar) }
                return String(mapped)
            }.joined()
            result.replaceCharacters(in: range, with: replacement)
        }
        return result as String
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
