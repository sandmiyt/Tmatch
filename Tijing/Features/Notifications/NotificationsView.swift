import SwiftUI

struct NotificationsView: View {
    @Environment(SessionStore.self) private var session
    @State private var items: [AppNotification] = []
    @State private var error: String?
    @State private var confirmDeleteAll = false
    @State private var selectedChallenge: ChallengeRoute?
    @State private var selectedUserCard: UserCardTarget?
    @State private var loading = true

    var body: some View {
        ZStack {
            TijingPageBackground()
            Group {
                if loading && items.isEmpty {
                    ProgressView("正在加载通知…")
                } else if items.isEmpty {
                    ContentUnavailableView("暂无通知", systemImage: "bell.slash", description: Text(error ?? "新的好友、对战和系统消息会出现在这里"))
                } else {
                    List {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            notificationCard(item)
                                .tijingReveal(order: min(index, 8))
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    if !item.isRead {
                                        Button("标为已读") { markRead(item) }.tint(.blue)
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button("删除", role: .destructive) { delete(item) }
                                        .tint(.red)
                                }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .animation(.spring(response: 0.40, dampingFraction: 0.86), value: items.map(\.id))
                }
            }
        }
        .navigationTitle("通知中心")
        .tijingTabBarPageClearance()
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !items.isEmpty {
                    Button("全部已读") { markAllRead() }
                        .disabled(!items.contains(where: { !$0.isRead }))
                    Menu {
                        Button("清空通知", role: .destructive) { confirmDeleteAll = true }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
        }
        .refreshable { await load() }
        .task { await load() }
        .onChange(of: session.unreadNotifications) { _, _ in Task { await load() } }
        .navigationDestination(item: $selectedChallenge) { route in
            DailyChallengeView(challengeID: route.id)
        }
        .sheet(item: $selectedUserCard) { target in
            PublicProfileView(userID: target.id)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog("清空全部通知？", isPresented: $confirmDeleteAll) {
            Button("清空", role: .destructive) { deleteAll() }
        }
    }

    private func notificationCard(_ item: AppNotification) -> some View {
        TijingPaperCard(tint: notificationTint(item)) {
            HStack(alignment: .top, spacing: 12) {
                TijingStickerIcon(
                    systemImage: notificationIcon(item),
                    tint: notificationAccent(item),
                    background: notificationTint(item),
                    size: 42,
                    rotation: item.isRead ? -3 : 5,
                    sparkle: !item.isRead
                )

                VStack(alignment: .leading, spacing: 9) {
                    HStack(alignment: .firstTextBaseline) {
                        HStack(spacing: 7) {
                            if !item.isRead { Circle().fill(TijingDesign.indigo).frame(width: 7, height: 7) }
                            Text(item.title).font(.headline)
                        }
                        Spacer()
                        Text(TijingFormat.dateTime(item.createdAt))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(item.content)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        if item.isFriendChallenge, let challengeID = item.relatedID?.stringValue, !challengeID.isEmpty {
                            Button {
                                markRead(item); Haptics.selection(); selectedChallenge = ChallengeRoute(id: challengeID)
                            } label: { TijingMicroBadge(title: "查看挑战", systemImage: "bolt.circle.fill", tint: TijingDesign.indigo) }
                            .buttonStyle(.plain)
                        }
                        if let relatedUserID = item.relatedUserID {
                            Button {
                                markRead(item); Haptics.selection(); selectedUserCard = UserCardTarget(id: relatedUserID)
                            } label: { TijingMicroBadge(title: "用户卡片", systemImage: "person.crop.circle.fill", tint: TijingDesign.mint) }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { markRead(item) }
    }

    private func notificationIcon(_ item: AppNotification) -> String {
        if item.kind.contains("challenge") { return "bolt.fill" }
        if item.kind.contains("friend") { return "person.2.fill" }
        if item.kind.contains("rank") || item.kind.contains("season") { return "trophy.fill" }
        return "bell.fill"
    }

    private func notificationTint(_ item: AppNotification) -> Color {
        if item.isRead { return Color(uiColor: .secondarySystemGroupedBackground) }
        if item.kind.contains("challenge") { return TijingDesign.butter }
        if item.kind.contains("friend") { return TijingDesign.sky }
        if item.kind.contains("rank") || item.kind.contains("season") { return TijingDesign.peach }
        return TijingDesign.lilac
    }

    private func notificationAccent(_ item: AppNotification) -> Color {
        if item.kind.contains("challenge") { return TijingDesign.amber }
        if item.kind.contains("friend") { return TijingDesign.cyan }
        if item.kind.contains("rank") || item.kind.contains("season") { return TijingDesign.coral }
        return TijingDesign.violet
    }

    @MainActor private func load() async {
        guard let token = session.token else { loading = false; return }
        let cacheKey = session.userCacheKey("notifications.list")
        if items.isEmpty, let cached: NotificationListResponse = session.api.cachedResponse(for: cacheKey) {
            items = cached.items
            session.unreadNotifications = cached.unread ?? cached.items.filter { !$0.isRead }.count
        }
        loading = items.isEmpty
        defer { loading = false }
        do {
            let response: NotificationListResponse = try await session.api.requestCached(
                "/api/notifications", token: token, cacheKey: cacheKey
            )
            items = response.items
            session.unreadNotifications = response.unread ?? response.items.filter { !$0.isRead }.count
            error = nil
        } catch {
            self.error = items.isEmpty ? error.localizedDescription : nil
        }
    }

    private func markRead(_ item: AppNotification) {
        guard !item.isRead else { return }
        mutate("/api/notifications/\(item.id)/read", method: .post)
    }
    private func delete(_ item: AppNotification) { mutate("/api/notifications/\(item.id)", method: .delete) }
    private func markAllRead() { mutate("/api/notifications/read-all", method: .post) }
    private func deleteAll() { mutate("/api/notifications", method: .delete) }

    private func mutate(_ path: String, method: HTTPMethod) {
        guard let token = session.token else { return }
        Task { @MainActor in
            do {
                let _: EmptyResponse = try await session.api.request(path, method: method, body: EmptyBody(), token: token)
                session.api.removeCachedResponse(for: session.userCacheKey("notifications.list"))
                Haptics.selection(); await load()
            } catch { self.error = error.localizedDescription }
        }
    }
}
