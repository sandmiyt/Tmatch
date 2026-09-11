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
    var attemptID: String? = nil
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
    private var clockStart: TimeInterval? = ProcessInfo.processInfo.systemUptime
    private var attemptID = UUID().uuidString
    private var favoriteInFlight = Set<Int>()
    private let outbox = PracticeOutbox.shared
    private var batchID: String { attemptID + "-batch" }
    private var finishID: String { attemptID + "-finish" }
    private func answerID(_ questionID: Int) -> String { attemptID + "-q-" + String(questionID) }
    var currentAnswerLocked: Bool {
        isSubmitting || outbox.contains(batchID) || outbox.contains(finishID) || currentQuestion.map { outbox.contains(answerID($0.id)) } == true
    }

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
        // SwiftUI can retain a NavigationLink destination briefly after it is popped.
        // If that destination completed a batch, discard its terminal in-memory state
        // before loading again instead of reopening on the old last question.
        if batchResult != nil { resetCompletedBatch() }
        guard questions.isEmpty, !isLoading else { return }
        isLoading = true; error = nil
        defer { isLoading = false }
        let key = resumeKey
        let saved = PracticeResumeStore.load(key: key)
        // A queued attempt must be resumed, never replaced by a fresh due queue.
        let hasPendingAttempt = saved?.attemptID.map { id in outbox.pending.contains { $0.id.hasPrefix(id + "-") } } ?? false
        if let saved, !saved.questions.isEmpty, (mode == .random || hasPendingAttempt) {
            restore(saved)
            restoreConfirmedSubmissions()
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
        guard !currentAnswerLocked, let question = currentQuestion, feedback[String(question.id)] == nil else { return }
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
            checkpointTime()
            saveResume()
            if isImmediate {
                await submitCurrent()
            } else {
                await advanceAfterDeferredAnswer()
            }
        }
    }

    func toggleExcluded(_ displayIndex: Int) {
        guard !currentAnswerLocked, let question = currentQuestion, feedback[String(question.id)] == nil else { return }
        let key = String(question.id)
        var values = excluded[key] ?? []
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
        checkpointTime()
        clockStart = nil
        let elapsed = currentElapsedMS()
        do {
            let value: PickValue = question.isMultiple ? .many(original) : .one(original.first ?? -1)
            saveResume()
            let result: AnswerFeedback = try await outbox.submit(id: answerID(question.id), path: "/api/practice/answer", body: PracticeAnswerBody(questionID: question.id, picked: value, elapsedMS: elapsed, mode: mode.rawValue), userID: userID, token: token)
            feedback[String(question.id)] = result
            elapsedByQuestion[String(question.id)] = elapsed
            if let fav = result.favorite, let position = questions.firstIndex(where: { $0.id == question.id }) { questions[position].favorite = fav }
            result.correct ? Haptics.success() : Haptics.error()
            saveResume()
        } catch {
            self.error = (outbox.contains(answerID(question.id)) ? "答案已保存待确认。" : "答案未发送，请保留当前练习。") + error.localizedDescription
            Haptics.error()
        }
    }

    func next() {
        guard canGoNext, !isSubmitting else { return }
        checkpointTime()
        index += 1
        clockStart = ProcessInfo.processInfo.systemUptime
        startedAt = Date()
        Haptics.selection()
        saveResume()
    }

    func previous() {
        guard canGoBack, !isSubmitting else { return }
        checkpointTime()
        index -= 1
        clockStart = ProcessInfo.processInfo.systemUptime
        startedAt = Date()
        Haptics.selection()
        saveResume()
    }

    func submitBatch() async {
        guard isDeferred, !questions.isEmpty, !isSubmitting else { return }
        checkpointTime()
        clockStart = nil
        let answers = questions.map { question -> PracticeBatchAnswerBody in
            let display = picks[String(question.id)] ?? []
            let original = question.originalPick(from: display)
            let pick: PickValue = question.isMultiple ? .many(original) : (original.first.map(PickValue.one) ?? .many([]))
            return PracticeBatchAnswerBody(questionID: question.id, picked: pick, elapsedMS: elapsedByQuestion[String(question.id)] ?? 0)
        }
        isSubmitting = true; error = nil
        defer { isSubmitting = false }
        do {
            saveResume()
            batchResult = try await outbox.submit(id: batchID, path: "/api/practice/submit", body: PracticeBatchSubmitBody(mode: mode.rawValue, answers: answers), userID: userID, token: token)
            showBatchResult = true
            PracticeResumeStore.clear(key: resumeKey)
            Haptics.success()
        } catch { self.error = error.localizedDescription; Haptics.error() }
    }


    func finishImmediateReview() async {
        guard isImmediate, !questions.isEmpty, !isSubmitting else { return }
        restoreConfirmedSubmissions()
        guard !outbox.pending.contains(where: { $0.id.hasPrefix(attemptID + "-q-") }) else {
            error = "本组仍有待确认答案，请回到对应题目重试确认后再结束。"
            return
        }
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
                saveResume()
                let response: PracticeBatchResult = try await outbox.submit(
                    id: finishID, path: "/api/practice/submit",
                    body: PracticeBatchSubmitBody(mode: mode.rawValue, answers: answers),
                    userID: userID, token: token
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
        guard !isSubmitting, questions.indices.contains(newIndex), newIndex != index else { return }
        checkpointTime()
        index = newIndex
        clockStart = ProcessInfo.processInfo.systemUptime
        startedAt = Date()
        Haptics.selection()
        saveResume()
    }

    func isAnswered(_ question: Question) -> Bool {
        if isImmediate { return feedback[String(question.id)] != nil }
        return !(picks[String(question.id)] ?? []).isEmpty
    }

    func toggleFavorite() async {
        guard let question = currentQuestion, !favoriteInFlight.contains(question.id) else { return }
        favoriteInFlight.insert(question.id)
        defer { favoriteInFlight.remove(question.id) }
        do {
            let response: FavoriteResponse = try await api.request("/api/questions/\(question.id)/favorite", method: .post, body: EmptyBody(), token: token)
            let next = response.favorite ?? !(question.favorite ?? false)
            if let position = questions.firstIndex(where: { $0.id == question.id }) { questions[position].favorite = next }
            Haptics.selection()
            saveResume()
        } catch { self.error = error.localizedDescription }
    }

    func saveProgressForExit() {
        checkpointTime()
        clockStart = nil
        saveResume()
    }

    func clearResume() { PracticeResumeStore.clear(key: resumeKey) }

    func resetCompletedBatch() {
        PracticeResumeStore.clear(key: resumeKey)
        questions = []
        index = 0
        picks = [:]
        feedback = [:]
        excluded = [:]
        elapsedByQuestion = [:]
        error = nil
        batchResult = nil
        showBatchResult = false
        startedAt = Date()
        clockStart = ProcessInfo.processInfo.systemUptime
        attemptID = UUID().uuidString
    }

    private func advanceAfterDeferredAnswer() async {
        guard let question = currentQuestion else { return }
        _ = question
        checkpointTime()
        if canGoNext { next() }
        else { saveResume() }
    }

    private var resumeKey: String { PracticeResumeStore.key(userID: userID, mode: mode, subject: subject, topic: topic) }

    private func currentElapsedMS() -> Int {
        guard let q = currentQuestion else { return 0 }
        let stored = elapsedByQuestion[String(q.id)] ?? 0
        guard let clockStart, !outbox.contains(answerID(q.id)), !outbox.contains(batchID), feedback[String(q.id)] == nil else { return stored }
        return min(86_400_000, stored + max(0, Int((ProcessInfo.processInfo.systemUptime - clockStart) * 1000)))
    }

    private func checkpointTime() {
        if let q = currentQuestion { elapsedByQuestion[String(q.id)] = currentElapsedMS() }
        if clockStart != nil { clockStart = ProcessInfo.processInfo.systemUptime }
    }

    func setActive(_ active: Bool) {
        if active { clockStart = ProcessInfo.processInfo.systemUptime; restoreConfirmedSubmissions() }
        else { saveProgressForExit() }
    }

    func restoreConfirmedSubmissions() {
        for position in questions.indices {
            let qid = questions[position].id
            if let result = outbox.response(answerID(qid), as: AnswerFeedback.self) {
                feedback[String(qid)] = result
                if let fav = result.favorite { questions[position].favorite = fav }
            }
        }
        if batchResult == nil, let result = outbox.response(batchID, as: PracticeBatchResult.self) {
            batchResult = result; showBatchResult = true
            PracticeResumeStore.clear(key: resumeKey)
        } else { saveResume() }
    }

    private func saveResume() {
        guard !questions.isEmpty, batchResult == nil else { return }
        PracticeResumeStore.save(PracticeResumeSnapshot(savedAt: Date(), mode: mode, subject: subject, topic: topic, settings: settings, questions: questions, index: index, picks: picks, feedback: feedback, excluded: excluded, elapsed: elapsedByQuestion, attemptID: attemptID), key: resumeKey)
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
        attemptID = snapshot.attemptID ?? UUID().uuidString
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
