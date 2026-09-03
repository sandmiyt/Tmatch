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
    @State private var selectedUserCard: UserCardTarget?

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
                        Button {
                            Haptics.selection()
                            selectedUserCard = UserCardTarget(id: relation.user.id)
                        } label: {
                            HStack(spacing: 12) {
                                RemoteAvatar(urlString: relation.user.avatarURL, name: relation.user.nickname, size: 42)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(relation.user.nickname).font(.headline).foregroundStyle(.primary)
                                    Text("向你发送了好友申请")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down").font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
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
                    Button {
                        Haptics.selection()
                        selectedUserCard = UserCardTarget(id: item.user.id)
                    } label: {
                        HStack(spacing: 12) {
                            RemoteAvatar(urlString: item.user.avatarURL, name: item.user.nickname, size: 38)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.user.nickname).foregroundStyle(.primary)
                                Text("已拉黑").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("移出黑名单") { unblock(item.user) }
                            .tint(.blue)
                    }
                }
            }

            if let message { Section { Text(message).font(.footnote).foregroundStyle(.secondary) } }
            if let error { Section { Text(error).font(.footnote).foregroundStyle(.red) } }
        }
        .scrollContentBackground(.hidden)
        .background(TijingPageBackground())
        .animation(.spring(response: 0.40, dampingFraction: 0.86), value: friends.map(\.id))
        .animation(.spring(response: 0.40, dampingFraction: 0.86), value: incoming.map(\.id))
        .navigationTitle("好友")
        .tijingTabBarPageClearance()
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
        .sheet(item: $selectedUserCard) { target in
            PublicProfileView(userID: target.id)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
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
            Button {
                Haptics.selection()
                selectedUserCard = UserCardTarget(id: relation.user.id)
            } label: {
                HStack(spacing: 12) {
                    ZStack(alignment: .bottomTrailing) {
                        RemoteAvatar(urlString: relation.user.avatarURL, name: relation.user.nickname, size: 44)
                        Circle().fill(isOnline ? Color.green : Color.gray).frame(width: 11, height: 11).overlay(Circle().stroke(Color(uiColor: .systemBackground), lineWidth: 2))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(relation.user.nickname).font(.headline).foregroundStyle(.primary)
                        Text(isOnline ? "在线" : "离线").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            Spacer()
            Button {
                Haptics.selection()
                var target = relation.user
                target.online = isOnline
                inviteTarget = target
            } label: {
                Image(systemName: "bolt.horizontal.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(TijingDesign.indigo)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("邀请\(relation.user.nickname)对战")
        }
        .padding(.vertical, 3)
    }

    private func userSearchRow(_ user: User) -> some View {
        HStack(spacing: 12) {
            Button {
                Haptics.selection()
                selectedUserCard = UserCardTarget(id: user.id)
            } label: {
                HStack(spacing: 12) {
                    RemoteAvatar(urlString: user.avatarURL, name: user.nickname, size: 40)
                    VStack(alignment: .leading) {
                        Text(user.nickname).font(.headline).foregroundStyle(.primary)
                        Text("\(user.rank) · \(user.rating) 竞点").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            Spacer()
            Button(user.friendStatus == "friend" ? "已是好友" : "添加") { requestFriend(user) }
                .disabled(user.friendStatus == "friend")
        }
    }

    @MainActor private func load() async {
        guard let token = session.token else { loading = false; return }
        let listKey = session.userCacheKey("friends.list")
        let blockedKey = session.userCacheKey("friends.blocks")

        if friends.isEmpty, incoming.isEmpty, outgoing.isEmpty,
           let cached: FriendListResponse = session.api.cachedResponse(for: listKey) {
            applyFriendList(cached, useCachedPresence: true)
        }
        if blocked.isEmpty, let cached: BlockedResponse = session.api.cachedResponse(for: blockedKey) {
            blocked = cached.items
        }

        loading = friends.isEmpty && incoming.isEmpty && outgoing.isEmpty
        defer { loading = false }
        do {
            async let listTask: FriendListResponse = session.api.requestCached("/api/friends", token: token, cacheKey: listKey)
            async let blockedTask: BlockedResponse = session.api.requestCached("/api/blocks", token: token, cacheKey: blockedKey)
            let list = try await listTask
            applyFriendList(list, useCachedPresence: false)
            let blockedResponse = try? await blockedTask
            if let blockedResponse { blocked = blockedResponse.items }
            error = nil
        } catch {
            self.error = (friends.isEmpty && incoming.isEmpty && outgoing.isEmpty) ? error.localizedDescription : nil
        }
    }

    private func applyFriendList(_ list: FriendListResponse, useCachedPresence: Bool) {
        friends = list.friends
        incoming = list.incoming
        outgoing = list.outgoing
        guard !useCachedPresence else { return }
        var initialPresence: [Int: Bool] = [:]
        for relation in list.friends { initialPresence[relation.user.id] = relation.user.online ?? false }
        presence = initialPresence
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
                session.api.removeCachedResponse(for: session.userCacheKey("friends.list"))
                session.api.removeCachedResponse(for: session.userCacheKey("friends.blocks"))
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
            ZStack {
                TijingPageBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        TijingPaperCard(tint: user.online == true ? TijingDesign.sage : TijingDesign.butter, rotation: -0.25) {
                            HStack(spacing: 13) {
                                RemoteAvatar(urlString: user.avatarURL, name: user.nickname, size: 54)
                                    .overlay { Circle().stroke(.white.opacity(0.82), lineWidth: 2.5) }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(user.nickname).font(.headline)
                                    Text(user.online == true ? "在线 · 发送后进入实时好友对战" : "离线 · 自动转为 48 小时好友挑战")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                TijingStickerIcon(systemImage: user.online == true ? "bolt.fill" : "clock.fill", tint: user.online == true ? TijingDesign.mint : TijingDesign.amber, background: user.online == true ? TijingDesign.sage : TijingDesign.butter, size: 40, rotation: 6, sparkle: false)
                            }
                        }

                        TijingFieldSurface("挑战范围") {
                            Picker("题库", selection: $subject) {
                                Text("全部题库").tag("")
                                ForEach(catalog) { item in Text("\(item.name)（\(item.count)题）").tag(item.name) }
                            }
                            .onChange(of: subject) { _, _ in topic = "" }
                            Divider()
                            Picker("章节", selection: $topic) {
                                Text(subject.isEmpty ? "先选择题库" : "全部章节").tag("")
                                ForEach(selectedSubject?.topics.filter { $0.count > 0 } ?? []) { item in
                                    Text("\(item.topic)（\(item.count)题）").tag(item.topic)
                                }
                            }
                            .disabled(subject.isEmpty)
                        }

                        if loading {
                            HStack { ProgressView(); Text("正在读取题库…").foregroundStyle(.secondary) }
                                .font(.footnote)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .tijingCard()
                        }
                        if let error {
                            Label(error, systemImage: "exclamationmark.circle.fill")
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .tijingCard()
                        }

                        Button {
                            Haptics.medium()
                            onSend(subject.isEmpty ? nil : subject, topic.isEmpty ? nil : topic)
                        } label: {
                            Label("发送挑战", systemImage: "paperplane.fill")
                        }
                        .buttonStyle(TijingPrimaryButtonStyle())
                        .disabled(loading)
                    }
                    .padding(.horizontal, TijingDesign.pageHorizontalPadding)
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("好友挑战")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
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
