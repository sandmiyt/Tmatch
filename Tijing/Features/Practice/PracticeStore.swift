import Foundation
import Observation

struct PracticeResumeSnapshot: Codable {
    let savedAt: Date
    let mode: PracticeMode
    let subject: String?
    let topic: String?
    let settings: PracticeSettings
    let questions: [Question]
    let index: Int
    let picks: [String: [Int]]
    let feedback: [String: AnswerFeedback]
    let excluded: [String: [Int]]
    let elapsed: [String: Int]
}

extension PracticeMode: Codable {}

nonisolated enum PracticeResumeStore {
    private static let prefix = "tijing.practice.resume.v1."

    static func key(userID: Int, mode: PracticeMode, subject: String?, topic: String?) -> String {
        let scope = [String(userID), mode.rawValue, subject ?? "_", topic ?? "_"].joined(separator: "|")
        return prefix + Data(scope.utf8).base64EncodedString()
    }

    static func load(key: String) -> PracticeResumeSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(PracticeResumeSnapshot.self, from: data) else { return nil }
        if Date().timeIntervalSince(snapshot.savedAt) > 7 * 24 * 60 * 60 {
            UserDefaults.standard.removeObject(forKey: key)
            return nil
        }
        return snapshot
    }

    static func save(_ snapshot: PracticeResumeSnapshot, key: String) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func clear(key: String) { UserDefaults.standard.removeObject(forKey: key) }
}

@MainActor
@Observable
final class PracticeSessionStore {
    let mode: PracticeMode
    let subject: String?
    let topic: String?
    var settings: PracticeSettings

    var questions: [Question] = []
    var index = 0
    var picks: [String: [Int]] = [:]
    var feedback: [String: AnswerFeedback] = [:]
    var excluded: [String: [Int]] = [:]
    var elapsedByQuestion: [String: Int] = [:]
    var isLoading = false
    var isSubmitting = false
    var error: String?
    var batchResult: PracticeBatchResult?
    var showBatchResult = false
    private let api: APIClient
    private let token: String
    private let userID: Int
    private var startedAt = Date()

    init(mode: PracticeMode, subject: String?, topic: String?, settings: PracticeSettings, token: String, userID: Int, api: APIClient = .shared) {
        self.mode = mode
        self.subject = subject
        self.topic = topic
        self.settings = settings
        self.token = token
        self.userID = userID
        self.api = api
    }

    var currentQuestion: Question? { questions.indices.contains(index) ? questions[index] : nil }
    var progressText: String { questions.isEmpty ? "0 / 0" : "\(index + 1) / \(questions.count)" }
    var isImmediate: Bool { settings.answerMode == "immediate" }
    var isDeferred: Bool { settings.answerMode == "submit" }
    var unansweredCount: Int { questions.filter { (picks[String($0.id)] ?? []).isEmpty }.count }
    var canGoBack: Bool { index > 0 }
    var canGoNext: Bool { index + 1 < questions.count }
    var isLast: Bool { !questions.isEmpty && index == questions.count - 1 }

    func load() async {
        guard questions.isEmpty, !isLoading else { return }
        isLoading = true; error = nil
        defer { isLoading = false }
        let key = resumeKey
        let saved = mode == .smartReview ? nil : PracticeResumeStore.load(key: key)
        if let saved, !saved.questions.isEmpty, mode != .wrong {
            restore(saved)
            return
        }
        if mode == .wrong, let saved { settings = saved.settings }
        do {
            var query = [URLQueryItem(name: "mode", value: mode.rawValue), URLQueryItem(name: "count", value: String(settings.questionCount))]
            let collection = mode == .wrong || mode == .favorite || mode == .smartReview
            query.append(URLQueryItem(name: "prefer_unseen", value: String(settings.preferUnseen && !collection)))
            if let subject, !subject.isEmpty { query.append(URLQueryItem(name: "subject", value: subject)) }
            if let topic, !topic.isEmpty { query.append(URLQueryItem(name: "topic", value: topic)) }
            if !collection && !(settings.difficultyMinRatio == 0 && settings.difficultyMaxRatio == 100) {
                query.append(URLQueryItem(name: "difficulty_min_ratio", value: String(settings.difficultyMinRatio)))
                query.append(URLQueryItem(name: "difficulty_max_ratio", value: String(settings.difficultyMaxRatio)))
            }
            let response: PracticeSetResponse = try await api.request("/api/practice/set", token: token, query: query)
            let prepared = response.items.map { question in
                var value = question.preparedForDisplay()
                if mode == .favorite { value.favorite = true }
                return value
            }
            if mode == .wrong, let saved, !saved.questions.isEmpty {
                if prepared.isEmpty {
                    PracticeResumeStore.clear(key: key)
                    questions = []
                } else {
                    reconcileWrongResume(saved, current: prepared)
                    return
                }
            } else {
                questions = prepared
            }
            index = 0
            startedAt = Date()
            saveResume()
        } catch { self.error = error.localizedDescription }
    }

    func selectedDisplayIndices(for question: Question) -> [Int] { picks[String(question.id)] ?? [] }
    func excludedIndices(for question: Question) -> [Int] { excluded[String(question.id)] ?? [] }
    func feedbackForCurrent() -> AnswerFeedback? { currentQuestion.flatMap { feedback[String($0.id)] } }

    func tapOption(_ displayIndex: Int) async {
        guard let question = currentQuestion, feedback[String(question.id)] == nil else { return }
        let key = String(question.id)
        guard !(excluded[key] ?? []).contains(displayIndex) else { return }
        Haptics.selection()
        if question.isMultiple {
            var values = picks[key] ?? []
            if let position = values.firstIndex(of: displayIndex) { values.remove(at: position) } else { values.append(displayIndex) }
            if values.isEmpty { picks.removeValue(forKey: key) } else { picks[key] = values.sorted() }
            saveResume()
        } else {
            picks[key] = [displayIndex]
            elapsedByQuestion[key] = currentElapsedMS()
            saveResume()
            if isImmediate {
                await submitCurrent()
            } else {
                await advanceAfterDeferredAnswer()
            }
        }
    }

    func toggleExcluded(_ displayIndex: Int) {
        guard let question = currentQuestion, feedback[String(question.id)] == nil else { return }
        let key = String(question.id)
        var values = excluded[key] ?? []
        let wasExcluded = values.contains(displayIndex)
        if let position = values.firstIndex(of: displayIndex) {
            values.remove(at: position)
        } else {
            values.append(displayIndex)
            var selected = picks[key] ?? []
            selected.removeAll { $0 == displayIndex }
            if selected.isEmpty { picks.removeValue(forKey: key) } else { picks[key] = selected }
        }
        if values.isEmpty { excluded.removeValue(forKey: key) } else { excluded[key] = values.sorted() }
        Haptics.medium()
        saveResume()
    }

    func confirmMultiple() async {
        guard let question = currentQuestion, question.isMultiple, !(picks[String(question.id)] ?? []).isEmpty else { return }
        if isImmediate { await submitCurrent() } else { await advanceAfterDeferredAnswer() }
    }

    func submitCurrent() async {
        guard let question = currentQuestion, !isSubmitting else { return }
        let selected = picks[String(question.id)] ?? []
        guard !selected.isEmpty else { return }
        isSubmitting = true; error = nil
        defer { isSubmitting = false }
        let original = question.originalPick(from: selected)
        let elapsed = currentElapsedMS()
        do {
            let value: PickValue = question.isMultiple ? .many(original) : .one(original.first ?? -1)
            let result: AnswerFeedback = try await api.request("/api/practice/answer", method: .post, body: PracticeAnswerBody(questionID: question.id, picked: value, elapsedMS: elapsed, mode: mode.rawValue), token: token)
            feedback[String(question.id)] = result
            elapsedByQuestion[String(question.id)] = elapsed
            if let fav = result.favorite { questions[index].favorite = fav }
            result.correct ? Haptics.success() : Haptics.error()
            saveResume()
        } catch {
            self.error = error.localizedDescription
            Haptics.error()
        }
    }

    func next() {
        guard canGoNext else { return }
        index += 1
        startedAt = Date()
        Haptics.selection()
        saveResume()
    }

    func previous() {
        guard canGoBack else { return }
        index -= 1
        startedAt = Date()
        Haptics.selection()
        saveResume()
    }

    func submitBatch() async {
        guard isDeferred, !questions.isEmpty, !isSubmitting else { return }
        if let q = currentQuestion { elapsedByQuestion[String(q.id)] = max(elapsedByQuestion[String(q.id)] ?? 0, currentElapsedMS()) }
        let answers = questions.map { question -> PracticeBatchAnswerBody in
            let display = picks[String(question.id)] ?? []
            let original = question.originalPick(from: display)
            let pick: PickValue = question.isMultiple ? .many(original) : (original.first.map(PickValue.one) ?? .many([]))
            return PracticeBatchAnswerBody(questionID: question.id, picked: pick, elapsedMS: elapsedByQuestion[String(question.id)] ?? 0)
        }
        isSubmitting = true; error = nil
        defer { isSubmitting = false }
        do {
            batchResult = try await api.request("/api/practice/submit", method: .post, body: PracticeBatchSubmitBody(mode: mode.rawValue, answers: answers), token: token)
            showBatchResult = true
            PracticeResumeStore.clear(key: resumeKey)
            Haptics.success()
        } catch { self.error = error.localizedDescription; Haptics.error() }
    }


    func finishImmediateReview() async {
        guard isImmediate, !questions.isEmpty, !isSubmitting else { return }
        isSubmitting = true
        error = nil
        defer { isSubmitting = false }

        let unanswered = questions.filter { feedback[String($0.id)] == nil }
        var unansweredDetails: [Int: PracticeBatchDetail] = [:]
        do {
            if !unanswered.isEmpty {
                let answers = unanswered.map {
                    PracticeBatchAnswerBody(questionID: $0.id, picked: .many([]), elapsedMS: 0)
                }
                let response: PracticeBatchResult = try await api.request(
                    "/api/practice/submit",
                    method: .post,
                    body: PracticeBatchSubmitBody(mode: mode.rawValue, answers: answers),
                    token: token
                )
                unansweredDetails = Dictionary(uniqueKeysWithValues: response.details.map { ($0.questionID, $0) })
            }

            let answered = feedback.count
            let correct = feedback.values.filter(\.correct).count
            var details: [PracticeBatchDetail] = []
            for question in questions {
                let key = String(question.id)
                if let item = feedback[key] {
                    guard !item.correct else { continue }
                    let displayPick = picks[key] ?? []
                    details.append(
                        PracticeBatchDetail(
                            questionID: question.id,
                            stem: question.stem,
                            material: question.material,
                            options: question.options,
                            picked: question.originalPick(from: displayPick),
                            answer: item.answer,
                            answers: item.answers,
                            correct: false,
                            explanation: item.explanation,
                            media: item.media,
                            favorite: question.favorite ?? item.favorite
                        )
                    )
                } else if let item = unansweredDetails[question.id] {
                    details.append(
                        PracticeBatchDetail(
                            questionID: item.questionID,
                            stem: question.stem,
                            material: question.material,
                            options: question.options,
                            picked: item.picked,
                            answer: item.answer,
                            answers: item.answers,
                            correct: item.correct,
                            explanation: item.explanation,
                            media: item.media,
                            favorite: question.favorite ?? item.favorite
                        )
                    )
                }
            }

            let score = questions.isEmpty ? 0 : Int((Double(correct) / Double(questions.count) * 100).rounded())
            batchResult = PracticeBatchResult(ok: true, correct: correct, total: questions.count, score: score, details: details)
            showBatchResult = true
            PracticeResumeStore.clear(key: resumeKey)
            Haptics.success()
            _ = answered
        } catch {
            self.error = error.localizedDescription
            Haptics.error()
        }
    }

    func go(to newIndex: Int) {
        guard questions.indices.contains(newIndex), newIndex != index else { return }
        if let currentQuestion {
            let key = String(currentQuestion.id)
            if !(picks[key] ?? []).isEmpty {
                elapsedByQuestion[key] = max(elapsedByQuestion[key] ?? 0, currentElapsedMS())
            }
        }
        index = newIndex
        startedAt = Date()
        Haptics.selection()
        saveResume()
    }

    func isAnswered(_ question: Question) -> Bool {
        if isImmediate { return feedback[String(question.id)] != nil }
        return !(picks[String(question.id)] ?? []).isEmpty
    }

    func toggleFavorite() async {
        guard let question = currentQuestion else { return }
        do {
            let response: FavoriteResponse = try await api.request("/api/questions/\(question.id)/favorite", method: .post, body: EmptyBody(), token: token)
            let next = response.favorite ?? !(question.favorite ?? false)
            questions[index].favorite = next
            Haptics.selection()
            saveResume()
        } catch { self.error = error.localizedDescription }
    }

    func clearResume() { PracticeResumeStore.clear(key: resumeKey) }

    private func advanceAfterDeferredAnswer() async {
        guard let question = currentQuestion else { return }
        elapsedByQuestion[String(question.id)] = currentElapsedMS()
        if canGoNext { next() }
        else { saveResume() }
    }

    private var resumeKey: String { PracticeResumeStore.key(userID: userID, mode: mode, subject: subject, topic: topic) }

    private func currentElapsedMS() -> Int { max(0, Int(Date().timeIntervalSince(startedAt) * 1000)) }

    private func saveResume() {
        guard !questions.isEmpty, mode != .smartReview, batchResult == nil else { return }
        PracticeResumeStore.save(PracticeResumeSnapshot(savedAt: Date(), mode: mode, subject: subject, topic: topic, settings: settings, questions: questions, index: index, picks: picks, feedback: feedback, excluded: excluded, elapsed: elapsedByQuestion), key: resumeKey)
    }

    private func reconcileWrongResume(_ snapshot: PracticeResumeSnapshot, current: [Question]) {
        let currentIDs = Set(current.map(\.id))
        let savedQuestions = snapshot.questions.filter { currentIDs.contains($0.id) }
        let savedIDs = Set(savedQuestions.map(\.id))
        let merged = savedQuestions + current.filter { !savedIDs.contains($0.id) }
        let validKeys = Set(merged.map { String($0.id) })
        let oldCurrentID = snapshot.questions.indices.contains(snapshot.index) ? snapshot.questions[snapshot.index].id : nil
        let nextIndex: Int
        if let oldCurrentID, let located = merged.firstIndex(where: { $0.id == oldCurrentID }) {
            nextIndex = located
        } else {
            nextIndex = min(max(0, snapshot.index), max(0, merged.count - 1))
        }

        settings = snapshot.settings
        questions = merged
        index = nextIndex
        picks = snapshot.picks.filter { validKeys.contains($0.key) }
        feedback = snapshot.feedback.filter { validKeys.contains($0.key) }
        excluded = snapshot.excluded.filter { validKeys.contains($0.key) }
        elapsedByQuestion = snapshot.elapsed.filter { validKeys.contains($0.key) }
        startedAt = Date()
        saveResume()
    }

    private func restore(_ snapshot: PracticeResumeSnapshot) {
        settings = snapshot.settings
        questions = snapshot.questions
        index = min(max(0, snapshot.index), max(0, snapshot.questions.count - 1))
        picks = snapshot.picks
        feedback = snapshot.feedback
        excluded = snapshot.excluded
        elapsedByQuestion = snapshot.elapsed
        startedAt = Date()
    }
}
