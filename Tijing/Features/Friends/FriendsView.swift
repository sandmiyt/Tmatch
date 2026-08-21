import SwiftUI

struct FriendsView: View {
    @Environment(SessionStore.self) private var session
    @State private var friends: [FriendRelation] = []
    @State private var incoming: [FriendRelation] = []
    @State private var outgoing: [FriendRelation] = []
    @State private var searchText = ""
    @State private var searchResults: [User] = []
    @State private var blocked: [BlockedItem] = []
    @State private var error: String?
    @State private var message: String?
    @State private var inviteTarget: User?
    @State private var selectedChallenge: ChallengeRoute?
    @State private var battleRoomID: String?
    @State private var loading = true
    @State private var presence: [Int: Bool] = [:]

    var body: some View {
        List {
            if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Section("搜索结果") {
                    if searchResults.isEmpty { Text("没有找到匹配用户").foregroundStyle(.secondary) }
                    ForEach(searchResults) { user in userSearchRow(user) }
                }
            }

            if !incoming.isEmpty {
                Section("好友申请") {
                    ForEach(incoming) { relation in
                        NavigationLink {
                            PublicProfileView(userID: relation.user.id)
                        } label: {
                            HStack(spacing: 12) {
                                RemoteAvatar(urlString: relation.user.avatarURL, name: relation.user.nickname, size: 42)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(relation.user.nickname).font(.headline)
                                    Text("向你发送了好友申请")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button("接受") { accept(relation) }
                                .tint(.green)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("拒绝", role: .destructive) { decline(relation) }
                        }
                    }
                }
            }

            Section("我的好友") {
                if loading && friends.isEmpty { ProgressView("正在同步好友…") }
                else if friends.isEmpty { Text("暂无好友").foregroundStyle(.secondary) }
                ForEach(sortedFriends) { relation in
                    friendRow(relation)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("删除", role: .destructive) { removeFriend(relation.user) }
                            Button("拉黑") { block(relation.user) }.tint(.orange)
                        }
                }
            }

            if !outgoing.isEmpty {
                Section("已发送") {
                    ForEach(outgoing) { relation in
                        HStack {
                            RemoteAvatar(urlString: relation.user.avatarURL, name: relation.user.nickname, size: 38)
                            Text(relation.user.nickname)
                            Spacer()
                            Text("等待接受").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("黑名单") {
                if loading && blocked.isEmpty { ProgressView("正在同步黑名单…") }
                else if blocked.isEmpty { Text("黑名单为空").foregroundStyle(.secondary) }
                ForEach(blocked) { item in
                    NavigationLink {
                        PublicProfileView(userID: item.user.id)
                    } label: {
                        HStack(spacing: 12) {
                            RemoteAvatar(urlString: item.user.avatarURL, name: item.user.nickname, size: 38)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.user.nickname)
                                Text("已拉黑")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("移出黑名单") { unblock(item.user) }
                            .tint(.blue)
                    }
                }
            }

            if let message { Section { Text(message).font(.footnote).foregroundStyle(.secondary) } }
            if let error { Section { Text(error).font(.footnote).foregroundStyle(.red) } }
        }
        .navigationTitle("好友")
        .searchable(text: $searchText, prompt: "搜索昵称")
        .task {
            await load()
            await presenceLoop()
        }
        .task(id: searchText) { await search() }
        .refreshable { await load() }
        .sheet(item: $inviteTarget) { user in
            FriendChallengeSetupSheet(user: user) { subject, topic in
                inviteTarget = nil
                inviteBattle(user, subject: subject, topic: topic)
            }
        }
        .navigationDestination(item: $selectedChallenge) { route in
            DailyChallengeView(challengeID: route.id)
        }
        .navigationDestination(item: $battleRoomID) { roomID in
            if let token = session.token {
                BattleRoomView(store: BattleRoomStore(roomID: roomID, token: token))
            } else {
                ContentUnavailableView("登录状态已失效", systemImage: "person.crop.circle.badge.exclamationmark")
            }
        }
    }

    private var sortedFriends: [FriendRelation] {
        friends.sorted { lhs, rhs in
            let left = presence[lhs.user.id] ?? lhs.user.online ?? false
            let right = presence[rhs.user.id] ?? rhs.user.online ?? false
            if left != right { return left && !right }
            return lhs.relationID < rhs.relationID
        }
    }

    private func friendRow(_ relation: FriendRelation) -> some View {
        let isOnline = presence[relation.user.id] ?? relation.user.online ?? false
        return HStack(spacing: 12) {
            NavigationLink {
                PublicProfileView(userID: relation.user.id)
            } label: {
                HStack(spacing: 12) {
                    ZStack(alignment: .bottomTrailing) {
                        RemoteAvatar(urlString: relation.user.avatarURL, name: relation.user.nickname, size: 44)
                        Circle().fill(isOnline ? Color.green : Color.gray).frame(width: 11, height: 11).overlay(Circle().stroke(Color(uiColor: .systemBackground), lineWidth: 2))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(relation.user.nickname).font(.headline)
                        Text(isOnline ? "在线" : "离线").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Button {
                Haptics.selection()
                var target = relation.user
                target.online = isOnline
                inviteTarget = target
            } label: { Image(systemName: "bolt.horizontal.circle") }
            .buttonStyle(.borderless)
            .accessibilityLabel("邀请\(relation.user.nickname)对战")
        }
        .padding(.vertical, 3)
    }

    private func userSearchRow(_ user: User) -> some View {
        HStack(spacing: 12) {
            NavigationLink {
                PublicProfileView(userID: user.id)
            } label: {
                HStack(spacing: 12) {
                    RemoteAvatar(urlString: user.avatarURL, name: user.nickname, size: 40)
                    VStack(alignment: .leading) {
                        Text(user.nickname).font(.headline)
                        Text("\(user.rank) · \(user.rating) 竞点").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Button(user.friendStatus == "friend" ? "已是好友" : "添加") { requestFriend(user) }
                .disabled(user.friendStatus == "friend")
        }
    }

    @MainActor private func load() async {
        guard let token = session.token else { loading = false; return }
        loading = true
        defer { loading = false }
        do {
            async let listTask: FriendListResponse = session.api.request("/api/friends", token: token)
            async let blockedTask: BlockedResponse = session.api.request("/api/blocks", token: token)
            let list = try await listTask
            friends = list.friends; incoming = list.incoming; outgoing = list.outgoing
            var initialPresence: [Int: Bool] = [:]
            for relation in list.friends { initialPresence[relation.user.id] = relation.user.online ?? false }
            presence = initialPresence
            let blockedResponse = try? await blockedTask
            blocked = blockedResponse?.items ?? []
            error = nil
        } catch { self.error = error.localizedDescription }
    }

    @MainActor private func refreshPresence() async {
        guard let token = session.token else { return }
        do {
            let response: PresenceResponse = try await session.api.request("/api/friends/presence", token: token)
            var next: [Int: Bool] = [:]
            for (id, value) in response.items {
                if let intID = Int(id) { next[intID] = value }
            }
            presence = next
        } catch {
            // Presence is best-effort. Keep the last known state rather than flashing everyone offline.
        }
    }

    @MainActor private func presenceLoop() async {
        await refreshPresence()
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled else { return }
            await refreshPresence()
        }
    }

    @MainActor private func search() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 1, let token = session.token else { searchResults = []; return }
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        do {
            let response: UserSearchResponse = try await session.api.request("/api/users/search", token: token, query: [URLQueryItem(name: "q", value: query)])
            searchResults = response.items
        } catch { searchResults = [] }
    }

    private func accept(_ relation: FriendRelation) { mutate("/api/friends/\(relation.relationID)/accept", method: .post) }
    private func decline(_ relation: FriendRelation) { mutate("/api/friends/\(relation.relationID)/decline", method: .post) }
    private func removeFriend(_ user: User) { mutate("/api/friends/\(user.id)", method: .delete) }
    private func block(_ user: User) { mutate("/api/users/\(user.id)/block", method: .post) }
    private func unblock(_ user: User) { mutate("/api/users/\(user.id)/block", method: .delete) }
    private func requestFriend(_ user: User) { mutate("/api/friends/request/\(user.id)", method: .post) }

    private func mutate(_ path: String, method: HTTPMethod) {
        guard let token = session.token else { return }
        Task { @MainActor in
            do {
                let _: EmptyResponse = try await session.api.request(path, method: method, body: EmptyBody(), token: token)
                Haptics.success(); await load()
            } catch { self.error = error.localizedDescription; Haptics.error() }
        }
    }

    private func inviteBattle(_ user: User, subject: String?, topic: String?) {
        guard let token = session.token else { return }
        Task { @MainActor in
            do {
                let response: FriendBattleInviteResponse = try await session.api.request(
                    "/api/battles/friend/invite/\(user.id)",
                    method: .post,
                    body: BattleModeBody(rule: "speed", subject: subject, topic: topic),
                    token: token
                )
                if response.mode == "friend_challenge", let challengeID = response.challengeID, !challengeID.isEmpty {
                    message = "好友当前离线，已自动转为 48 小时好友挑战。"
                    selectedChallenge = ChallengeRoute(id: challengeID)
                } else if let roomID = response.roomID, !roomID.isEmpty {
                    message = "好友对战邀请已发送，正在等待对方接受。"
                    battleRoomID = roomID
                } else {
                    throw APIError(message: "服务器未返回好友对战房间", statusCode: 0, retryAfter: nil)
                }
                Haptics.success()
            } catch { self.error = error.localizedDescription; Haptics.error() }
        }
    }

}

struct FriendChallengeSetupSheet: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    let user: User
    let onSend: (String?, String?) -> Void

    @State private var catalog: [PracticeSubject] = []
    @State private var subject = ""
    @State private var topic = ""
    @State private var loading = true
    @State private var error: String?

    private var selectedSubject: PracticeSubject? { catalog.first { $0.name == subject } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        RemoteAvatar(urlString: user.avatarURL, name: user.nickname, size: 48)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(user.nickname).font(.headline)
                            Text(user.online == true ? "在线：发送后进入实时好友对战" : "离线：自动转为 48 小时好友挑战")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                Section("挑战范围") {
                    Picker("题库", selection: $subject) {
                        Text("全部题库").tag("")
                        ForEach(catalog) { item in Text("\(item.name)（\(item.count)题）").tag(item.name) }
                    }
                    .onChange(of: subject) { _, _ in topic = "" }

                    Picker("章节", selection: $topic) {
                        Text(subject.isEmpty ? "先选择题库" : "全部章节").tag("")
                        ForEach(selectedSubject?.topics.filter { $0.count > 0 } ?? []) { item in
                            Text("\(item.topic)（\(item.count)题）").tag(item.topic)
                        }
                    }
                    .disabled(subject.isEmpty)
                }

                if loading { Section { ProgressView("正在读取题库…") } }
                if let error { Section { Text(error).font(.footnote).foregroundStyle(.red) } }
            }
            .navigationTitle("好友挑战")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("发送") {
                        Haptics.medium()
                        onSend(subject.isEmpty ? nil : subject, topic.isEmpty ? nil : topic)
                    }
                    .disabled(loading)
                }
            }
            .task { await loadCatalog() }
            .sensoryFeedback(.selection, trigger: subject)
            .sensoryFeedback(.selection, trigger: topic)
        }
        .presentationDetents([.medium, .large])
    }

    @MainActor private func loadCatalog() async {
        guard let token = session.token else { loading = false; return }
        do {
            let response: PracticeCatalogResponse = try await session.api.request("/api/practice/catalog", token: token)
            catalog = response.subjects
            error = nil
        } catch { self.error = error.localizedDescription }
        loading = false
    }
}

private struct BlockedResponse: Decodable { let items: [BlockedItem] }
private struct BlockedItem: Decodable, Identifiable { let id: Int; let user: User; let createdAt: String?; enum CodingKeys: String, CodingKey { case id, user; case createdAt = "created_at" } }
