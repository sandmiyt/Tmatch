import Foundation
import Observation

@MainActor
@Observable
final class BattleRoomStore {
    let roomID: String
    var state: BattleState?
    var review: BattleReview?
    var error: String?
    var networkHint: String?
    var isConnecting = false
    var selected: Int?
    var excluded: Set<Int> = []

    private let api: APIClient
    private let token: String
    private var socket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?
    private var fallbackTask: Task<Void, Never>?
    private var reviewTask: Task<Void, Never>?

    init(roomID: String, token: String, api: APIClient = .shared) {
        self.roomID = roomID
        self.token = token
        self.api = api
    }

    func connect() async {
        guard socket == nil else { return }
        isConnecting = true
        error = nil
        networkHint = nil
        do {
            let snapshot: BattleState = try await api.request("/api/battles/\(roomID)", token: token)
            apply(snapshot)
        } catch {
            self.error = error.localizedDescription
        }
        do {
            let task = try api.webSocketTask(path: "/ws/battle/\(roomID)")
            socket = task
            task.resume()
            try await task.send(.string(authMessage))
            receiveTask = Task { [weak self] in await self?.receiveLoop(task) }
            pingTask = Task { [weak self] in await self?.pingLoop(task) }
        } catch {
            self.networkHint = "实时连接暂时不可用，已切换为稳定模式"
            socket = nil
            startFallbackPolling()
        }
        isConnecting = false
    }

    func disconnect() {
        receiveTask?.cancel(); receiveTask = nil
        pingTask?.cancel(); pingTask = nil
        fallbackTask?.cancel(); fallbackTask = nil
        reviewTask?.cancel(); reviewTask = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
    }

    func toggleExcluded(_ index: Int) {
        guard let state, state.mode == "quick", !state.finished, state.myFeedback == nil, selected == nil else { return }
        if excluded.contains(index) {
            excluded.remove(index)
        } else {
            excluded.insert(index)
        }
        Haptics.light()
    }

    func answer(_ index: Int) async {
        guard let state, !state.finished, state.myFeedback == nil, selected == nil, !excluded.contains(index) else { return }
        selected = index
        error = nil
        networkHint = nil
        Haptics.selection()
        let body = BattleAnswerBody(questionIndex: state.questionIndex, picked: index)
        var lastError: Error?
        for attempt in 0..<2 {
            do {
                let updated: BattleState = try await api.request("/api/battles/\(roomID)/answer", method: .post, body: body, token: token)
                apply(updated)
                return
            } catch {
                lastError = error
                if let apiError = error as? APIError, [400, 401, 403, 404, 409, 422].contains(apiError.statusCode) { break }
                if attempt == 0 {
                    networkHint = "答案已暂存，正在确认…"
                    try? await Task.sleep(for: .milliseconds(420))
                }
            }
        }
        selected = nil
        self.error = lastError?.localizedDescription ?? "提交失败"
        Haptics.error()
    }

    func forfeit() async {
        do {
            let updated: BattleState = try await api.request("/api/battles/\(roomID)/forfeit", method: .post, body: EmptyBody(), token: token)
            apply(updated)
        } catch {
            self.error = error.localizedDescription
            Haptics.error()
        }
    }

    func leaveWaitingRoom() async -> Bool {
        do {
            let _: EmptyResponse = try await api.request("/api/battles/\(roomID)/leave", method: .post, body: EmptyBody(), token: token)
            Haptics.selection()
            return true
        } catch {
            self.error = error.localizedDescription
            Haptics.error()
            return false
        }
    }

    private var authMessage: String {
        let escaped = token.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return "{\"type\":\"auth\",\"token\":\"\(escaped)\"}"
    }

    private func receiveLoop(_ task: URLSessionWebSocketTask) async {
        while !Task.isCancelled {
            do {
                let message = try await task.receive()
                let data: Data?
                switch message {
                case .string(let text): data = text.data(using: .utf8)
                case .data(let value): data = value
                @unknown default: data = nil
                }
                if let data, let state = try? JSONDecoder().decode(BattleState.self, from: data) {
                    networkHint = nil
                    apply(state)
                }
            } catch {
                if !Task.isCancelled {
                    if self.socket === task { self.socket = nil }
                    self.networkHint = "网络有些波动，已切换为接口同步"
                    self.pingTask?.cancel(); self.pingTask = nil
                    startFallbackPolling()
                }
                return
            }
        }
    }

    private func pingLoop(_ task: URLSessionWebSocketTask) async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(20))
            guard !Task.isCancelled else { return }
            do {
                try await task.send(.string("{\"type\":\"ping\"}"))
            } catch {
                return
            }
        }
    }

    private func startFallbackPolling() {
        guard fallbackTask == nil else { return }
        fallbackTask = Task { [weak self] in
            guard let self else { return }
            defer { self.fallbackTask = nil }
            var failures = 0
            while !Task.isCancelled {
                var delay = 2.0
                do {
                    let fresh: BattleState = try await self.api.request("/api/battles/\(self.roomID)", token: self.token)
                    self.apply(fresh)
                    failures = 0
                    self.error = nil
                    if fresh.finished { return }
                } catch let apiError as APIError where apiError.statusCode == 429 {
                    let seconds = max(60, apiError.retryAfter ?? 60)
                    self.networkHint = "连接请求较频繁，已自动降低同步频率…"
                    delay = Double(seconds)
                } catch {
                    failures += 1
                    delay = min(5.0, 1.5 + Double(failures) * 0.45)
                    self.networkHint = "网络有些波动，正在自动恢复…"
                    if failures >= 6 { self.error = error.localizedDescription }
                }
                try? await Task.sleep(for: .seconds(delay))
            }
        }
    }

    private func loadReview() {
        guard reviewTask == nil else { return }
        reviewTask = Task { [weak self] in
            guard let self else { return }
            defer { self.reviewTask = nil }
            for attempt in 0..<3 {
                do {
                    let response: BattleReviewResponse = try await self.api.request("/api/battles/\(self.roomID)/review", token: self.token)
                    self.review = response.review
                    return
                } catch {
                    if attempt < 2 { try? await Task.sleep(for: .milliseconds(350 + attempt * 300)) }
                }
            }
        }
    }

    private func apply(_ newState: BattleState) {
        let oldQuestion = state?.questionIndex
        let oldFeedback = state?.myFeedback
        let wasFinished = state?.finished == true
        state = newState
        error = nil
        if oldQuestion != newState.questionIndex {
            selected = nil
            excluded.removeAll()
        }
        if oldFeedback == nil, let feedback = newState.myFeedback {
            feedback.correct ? Haptics.success() : Haptics.error()
        }
        if newState.finished {
            if !wasFinished { Haptics.medium() }
            loadReview()
        }
    }
}
