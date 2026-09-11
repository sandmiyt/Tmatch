import Foundation

// Wire names intentionally match the shared web API; scheduling stays on the server.
struct StudyPlan: Codable, Equatable {
    var target_name: String
    var target_date: String?
    var daily_minutes: Int
    var daily_questions: Int
    var desired_retention: Double
    var review_algorithm: String
    var configured: Bool?

    var isValid: Bool {
        !target_name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && target_name.count <= 120 &&
        (5...240).contains(daily_minutes) && (5...300).contains(daily_questions) &&
        (0.8...0.97).contains(desired_retention) && ["fsrs", "ebbinghaus_adaptive"].contains(review_algorithm)
    }
}

struct LearningWeekReport: Decodable {
    let start_date: String
    let end_date: String
    let timezone: String
    let total: Int
    let correct: Int
    let accuracy: Double
    let accuracy_change: Double?
    let active_days: Int
    let study_minutes: Double
    let days: [StudyDay]
    let weak_topics: [StudyWeakTopic]
    let plan: StudyPlan
    let days_remaining: Int?
    let review_forecast: [StudyForecast]
    let today_plan: TodayStudyPlan
}

struct StudyDay: Decodable, Identifiable {
    let date: String
    let total: Int
    let correct: Int
    let elapsed_ms: Int
    var id: String { date }
}
struct StudyWeakTopic: Decodable, Identifiable {
    let subject: String
    let topic: String
    let total: Int
    let correct: Int
    let accuracy: Double
    var id: String { subject + "|" + topic }
}
struct StudyForecast: Decodable, Identifiable {
    let date: String
    let due: Int
    var id: String { date }
}
struct TodayStudyPlan: Decodable {
    let review: Int
    let new: Int
    let completed: Int
    let total: Int
    let estimated_minutes: Int
    let overdue_remaining: Int
}

enum StudyDate {
    static func string(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 8 * 3600)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    static func date(_ string: String?) -> Date? {
        guard let string else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 8 * 3600)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }
}
