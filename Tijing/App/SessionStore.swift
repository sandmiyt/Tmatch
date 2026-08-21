import Foundation
import Observation

@MainActor
@Observable
final class SessionStore {
    var user: User?
    var isBootstrapping = false
    var lastError: String?
    var unreadNotifications = 0
    var pendingFriendInvite: FriendBattleInvite?
    var realtimeConnected = false
    var rankingRevision = 0

    private(set) var token: String?
    let api = APIClient.shared
    private var realtimeSocket: URLSessionWebSocketTask?
    private var realtimeReceiveTask: Task<Void, Never>?
    private var realtimePingTask: Task<Void, Never>?
    private var realtimeFallbackTask: Task<Void, Never>?

    var isAuthenticated: Bool { token != nil && user != nil }

    init() {
        token = KeychainStore.read(key: KeychainStore.authTokenKey)
    }

    func bootstrap() async {
        guard !isBootstrapping else { return }
        guard let token, !token.isEmpty else { return }
        isBootstrapping = true
        defer { isBootstrapping = false }
        do {
            user = try await api.request("/api/auth/me", token: token)
            await refreshUnreadCount()
            startRealtime()
        } catch let error as APIError where error.statusCode == 401 || error.statusCode == 403 {
            let message = error.localizedDescription
            logout()
            lastError = message
        } catch {
            lastError = error.localizedDescription
        }
    }

    func login(account: String, password: String) async throws {
        let payload = LoginBody(nickname: account, username: nil, password: password)
        let response: AuthResponse = try await api.request("/api/auth/login", method: .post, body: payload)
        setAuthenticated(response)
    }

    func register(nickname: String, password: String, email: String, code: String) async throws -> AuthResponse {
        let payload = RegisterBody(nickname: nickname, password: password, email: email, emailCode: code)
        let headers = ["X-Tijing-Device": DeviceIdentity.current]
        return try await api.request("/api/auth/register", method: .post, body: payload, headers: headers)
    }

    func refreshUser() async throws {
        guard let token else { return }
        user = try await api.request("/api/auth/me", token: token)
        await refreshUnreadCount()
    }

    func replaceToken(_ newToken: String, user newUser: User) {
        token = newToken
        user = newUser
        KeychainStore.save(newToken, key: KeychainStore.authTokenKey)
        startRealtime()
    }

    func logout() {
        stopRealtime()
        token = nil
        user = nil
        lastError = nil
        unreadNotifications = 0
        pendingFriendInvite = nil
        KeychainStore.delete(key: KeychainStore.authTokenKey)
    }

    func appBecameActive() {
        guard isAuthenticated else { return }
        startRealtime()
    }

    func appBecameInactive() {
        guard let token else { return }
        stopRealtime()
        Task {
            let _: EmptyResponse? = try? await api.request("/api/presence/offline", method: .post, body: EmptyBody(), token: token)
        }
    }

    func refreshUnreadCount() async {
        guard let token else { unreadNotifications = 0; return }
        if let response: UnreadCountResponse = try? await api.request("/api/notifications/unread-count", token: token) {
            unreadNotifications = response.unread
        }
    }

    func acceptPendingFriendInvite() async throws -> String? {
        guard let invite = pendingFriendInvite, let token else { return nil }
        let response: BattleCreateResponse = try await api.request("/api/battles/friend/invites/\(invite.id)/accept", method: .post, body: EmptyBody(), token: token)
        pendingFriendInvite = nil
        return response.resolvedRoomID ?? invite.roomID
    }

    func declinePendingFriendInvite() async {
        guard let invite = pendingFriendInvite, let token else { return }
        let _: EmptyResponse? = try? await api.request("/api/battles/friend/invites/\(invite.id)/decline", method: .post, body: EmptyBody(), token: token)
        pendingFriendInvite = nil
    }

    func startRealtime() {
        guard realtimeSocket == nil, let token, user != nil else { return }
        realtimeFallbackTask?.cancel()
        realtimeFallbackTask = nil
        do {
            let socket = try api.webSocketTask(path: "/ws/realtime")
            realtimeSocket = socket
            socket.resume()
            let auth = realtimeAuthMessage(token)
            realtimeReceiveTask = Task { [weak self] in
                guard let self else { return }
                do {
                    try await socket.send(.string(auth))
                    while !Task.isCancelled {
                        let message = try await socket.receive()
                        let data: Data?
                        switch message {
                        case .string(let text): data = text.data(using: .utf8)
                        case .data(let value): data = value
                        @unknown default: data = nil
                        }
                        if let data, let event = try? JSONDecoder().decode(RealtimeEnvelope.self, from: data) {
                            self.handleRealtime(event, socket: socket)
                        }
                    }
                } catch {
                    if !Task.isCancelled { self.handleRealtimeDisconnect(socket) }
                }
            }
            realtimePingTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(30))
                    guard !Task.isCancelled else { return }
                    try? await socket.send(.string("{\"type\":\"ping\"}"))
                }
            }
        } catch {
            startRealtimeFallback()
        }
    }

    func stopRealtime() {
        realtimeReceiveTask?.cancel(); realtimeReceiveTask = nil
        realtimePingTask?.cancel(); realtimePingTask = nil
        realtimeFallbackTask?.cancel(); realtimeFallbackTask = nil
        realtimeSocket?.cancel(with: .goingAway, reason: nil)
        realtimeSocket = nil
        realtimeConnected = false
    }

    private func handleRealtime(_ event: RealtimeEnvelope, socket: URLSessionWebSocketTask) {
        switch event.type {
        case "connected":
            realtimeConnected = true
        case "state":
            unreadNotifications = event.unread ?? unreadNotifications
            pendingFriendInvite = event.invite
        case "notification_changed", "friend_invite_changed":
            Task { try? await socket.send(.string("{\"type\":\"sync\"}")) }
        case "ranking_changed":
            rankingRevision &+= 1
        case "account_banned":
            let reason = "账号当前已被封禁，请稍后再试"
            logout()
            lastError = reason
        default:
            break
        }
    }

    private func handleRealtimeDisconnect(_ socket: URLSessionWebSocketTask) {
        guard realtimeSocket === socket else { return }
        realtimeSocket = nil
        realtimeConnected = false
        realtimePingTask?.cancel(); realtimePingTask = nil
        startRealtimeFallback()
    }

    private func startRealtimeFallback() {
        guard realtimeFallbackTask == nil, let token else { return }
        realtimeFallbackTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                do {
                    let state: RealtimeFallbackResponse = try await self.api.request("/api/realtime/fallback", token: token)
                    self.unreadNotifications = state.unread
                    self.pendingFriendInvite = state.invite
                } catch { }
                try? await Task.sleep(for: .seconds(20))
            }
        }
    }

    private func realtimeAuthMessage(_ token: String) -> String {
        let escaped = token.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return "{\"type\":\"auth\",\"token\":\"\(escaped)\"}"
    }

    private func setAuthenticated(_ response: AuthResponse) {
        replaceToken(response.token, user: response.user)
        Haptics.success()
    }
}

private struct UnreadCountResponse: Decodable { let unread: Int }
