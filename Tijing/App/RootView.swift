import SwiftUI
import Combine

struct RootView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: AppTab = .home
    @State private var showingAuth = false
    @State private var presentedBattleRoom: PresentedBattleRoom?

    var body: some View {
        @Bindable var bindableSession = session

        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView(showingAuth: $showingAuth)
            }
            .tabItem { Label("首页", systemImage: selectedTab == .home ? "house.fill" : "house") }
            .tag(AppTab.home)

            NavigationStack {
                AuthenticatedTabGate(
                    title: "登录后开始刷题",
                    subtitle: "刷题记录、错题和收藏会同步到你的题竞账号。",
                    systemImage: "book.pages"
                ) {
                    PracticeHubView()
                } login: {
                    showingAuth = true
                }
            }
            .tabItem { Label("刷题", systemImage: selectedTab == .practice ? "book.pages.fill" : "book.pages") }
            .tag(AppTab.practice)

            NavigationStack {
                AuthenticatedTabGate(
                    title: "登录后开始对战",
                    subtitle: "排位、好友房和 AI 对战都使用你的现有题竞账号。",
                    systemImage: "bolt.horizontal.circle"
                ) {
                    BattleLobbyView()
                } login: {
                    showingAuth = true
                }
            }
            .tabItem { Label("对战", systemImage: selectedTab == .battle ? "bolt.horizontal.circle.fill" : "bolt.horizontal.circle") }
            .tag(AppTab.battle)

            NavigationStack {
                RankingView()
            }
            .tabItem { Label("排行", systemImage: selectedTab == .ranking ? "trophy.fill" : "trophy") }
            .tag(AppTab.ranking)

            NavigationStack {
                ProfileView(showingAuth: $showingAuth)
            }
            .tabItem { Label("我的", systemImage: selectedTab == .profile ? "person.crop.circle.fill" : "person.crop.circle") }
            .badge(session.unreadNotifications)
            .tag(AppTab.profile)
        }
        .tint(.accentColor)
        .sensoryFeedback(.selection, trigger: selectedTab)
        .onAppear { Haptics.prepare() }
        .sheet(isPresented: $showingAuth) {
            AuthView()
                .presentationDragIndicator(.visible)
        }
        .overlay(alignment: .top) {
            if session.isBootstrapping && session.user == nil {
                ProgressView()
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.top, 8)
                    .accessibilityLabel("正在恢复登录状态")
            }
        }
        .onChange(of: session.user?.id) { _, newValue in
            if newValue != nil { showingAuth = false }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { session.appBecameActive() }
            else if phase == .background { session.appBecameInactive() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .tijingAuthInvalid)) { _ in
            session.logout()
            session.lastError = "登录状态已失效，请重新登录"
            selectedTab = .home
            showingAuth = true
        }
        .sheet(item: $bindableSession.pendingFriendInvite) { invite in
            FriendInviteSheet(invite: invite) {
                Task { @MainActor in
                    do {
                        presentedBattleRoom = try await session.acceptPendingFriendInvite().map(PresentedBattleRoom.init(id:))
                    } catch {
                        session.lastError = error.localizedDescription
                        Haptics.error()
                    }
                }
            } onDecline: {
                Task { await session.declinePendingFriendInvite() }
            }
            .presentationDetents([.height(310)])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(item: $presentedBattleRoom) { room in
            if let token = session.token {
                NavigationStack {
                    BattleRoomView(store: BattleRoomStore(roomID: room.id, token: token))
                }
            }
        }
    }
}

enum AppTab: Hashable {
    case home, practice, battle, ranking, profile
}

private struct AuthenticatedTabGate<Content: View>: View {
    @Environment(SessionStore.self) private var session
    let title: String
    let subtitle: String
    let systemImage: String
    private let content: Content
    let login: () -> Void

    init(
        title: String,
        subtitle: String,
        systemImage: String,
        @ViewBuilder content: () -> Content,
        login: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.content = content()
        self.login = login
    }

    var body: some View {
        if session.isAuthenticated {
            content
        } else {
            ContentUnavailableView {
                Label(title, systemImage: systemImage)
            } description: {
                Text(subtitle)
            } actions: {
                Button("登录 / 注册") {
                    Haptics.selection()
                    login()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .navigationTitle(title.contains("对战") ? "对战" : "刷题")
        }
    }
}

private struct FriendInviteSheet: View {
    let invite: FriendBattleInvite
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            RemoteAvatar(urlString: invite.inviter.avatarURL, name: invite.inviter.nickname, size: 68)

            VStack(spacing: 6) {
                Text("好友对战邀请")
                    .font(.title2.bold())
                Text("\(invite.inviter.nickname) 邀请你进行 10 题好友对战")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Button("拒绝", role: .destructive) {
                    Haptics.warning()
                    onDecline()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button("接受") {
                    Haptics.success()
                    onAccept()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
}

private struct PresentedBattleRoom: Identifiable {
    let id: String
}
