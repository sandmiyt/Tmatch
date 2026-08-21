import SwiftUI

struct NotificationsView: View {
    @Environment(SessionStore.self) private var session
    @State private var items: [AppNotification] = []
    @State private var error: String?
    @State private var confirmDeleteAll = false
    @State private var selectedChallenge: ChallengeRoute?
    @State private var selectedUserID: Int?
    @State private var loading = true

    var body: some View {
        Group {
            if loading && items.isEmpty {
                ProgressView("正在加载通知…")
            } else if items.isEmpty {
                ContentUnavailableView("暂无通知", systemImage: "bell.slash", description: Text(error ?? "新的好友、对战和系统消息会出现在这里"))
            } else {
                List {
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(item.title).font(.headline)
                                if !item.isRead { Circle().fill(.tint).frame(width: 7, height: 7) }
                                Spacer()
                                Text(TijingFormat.dateTime(item.createdAt)).font(.caption2).foregroundStyle(.secondary)
                            }
                            Text(item.content).font(.subheadline).foregroundStyle(.secondary)
                            if item.isFriendChallenge, let challengeID = item.relatedID?.stringValue, !challengeID.isEmpty {
                                Button {
                                    markRead(item)
                                    Haptics.selection()
                                    selectedChallenge = ChallengeRoute(id: challengeID)
                                } label: {
                                    Label("查看好友挑战", systemImage: "chevron.right.circle")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .buttonStyle(.borderless)
                            }
                            if let relatedUserID = item.relatedUserID {
                                Button {
                                    markRead(item)
                                    Haptics.selection()
                                    selectedUserID = relatedUserID
                                } label: {
                                    Label("查看用户", systemImage: "person.crop.circle")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        .padding(.vertical, 5)
                        .contentShape(Rectangle())
                        .onTapGesture { markRead(item) }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            if !item.isRead {
                                Button("标为已读") { markRead(item) }
                                    .tint(.blue)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("删除", role: .destructive) { delete(item) }
                        }
                    }
                }
            }
        }
        .navigationTitle("通知中心")
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
        .onChange(of: session.unreadNotifications) { _, _ in
            Task { await load() }
        }
        .navigationDestination(item: $selectedChallenge) { route in
            DailyChallengeView(challengeID: route.id)
        }
        .navigationDestination(item: $selectedUserID) { userID in
            PublicProfileView(userID: userID)
        }
        .confirmationDialog("清空全部通知？", isPresented: $confirmDeleteAll) {
            Button("清空", role: .destructive) { deleteAll() }
        }
    }

    @MainActor private func load() async {
        guard let token = session.token else { loading = false; return }
        loading = true
        defer { loading = false }
        do {
            let response: NotificationListResponse = try await session.api.request("/api/notifications", token: token)
            items = response.items
            session.unreadNotifications = response.unread ?? response.items.filter { !$0.isRead }.count
            error = nil
        } catch { self.error = error.localizedDescription }
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
                Haptics.selection(); await load()
            } catch { self.error = error.localizedDescription }
        }
    }
}
