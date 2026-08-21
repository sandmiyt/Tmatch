import Foundation

struct ExamCalendarResponse: Decodable {
    let items: [RecruitmentExam]
    let cities: [ExamCity]?
    let followedCount: Int?
    let lastSyncAt: String?
    let sourceName: String?

    enum CodingKeys: String, CodingKey {
        case items, cities
        case followedCount = "followed_count"
        case lastSyncAt = "last_sync_at"
        case sourceName = "source_name"
    }
}

struct ExamCity: Decodable, Hashable, Identifiable {
    let name: String
    let count: Int
    var id: String { name }
}

struct RecruitmentExam: Decodable, Identifiable, Hashable {
    let id: Int
    let title: String
    let region: String?
    let city: String?
    let examKind: String?
    let sourceName: String?
    let sourceURL: String?
    let announcementDate: String?
    let registrationStart: String?
    let registrationEnd: String?
    let paymentDeadline: String?
    let admissionStart: String?
    let admissionEnd: String?
    let examDate: String?
    let phase: String?
    let nextLabel: String?
    let nextAt: String?
    let daysToNext: Int?
    var followed: Bool?
    let sourceExcerpt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, region, city, phase, followed
        case examKind = "exam_kind"
        case sourceName = "source_name"
        case sourceURL = "source_url"
        case announcementDate = "announcement_date"
        case registrationStart = "registration_start"
        case registrationEnd = "registration_end"
        case paymentDeadline = "payment_deadline"
        case admissionStart = "admission_start"
        case admissionEnd = "admission_end"
        case examDate = "exam_date"
        case nextLabel = "next_label"
        case nextAt = "next_at"
        case daysToNext = "days_to_next"
        case sourceExcerpt = "source_excerpt"
        case updatedAt = "updated_at"
    }
}

struct ExamCalendarSummary: Decodable {
    let followedCount: Int
    let activeCount: Int
    let nextExam: RecruitmentExam?
    let highlights: [RecruitmentExam]
    let followedHighlights: [RecruitmentExam]?

    enum CodingKeys: String, CodingKey {
        case highlights
        case followedHighlights = "followed_highlights"
        case followedCount = "followed_count"
        case activeCount = "active_count"
        case nextExam = "next_exam"
    }
}
