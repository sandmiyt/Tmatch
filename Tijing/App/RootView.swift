import SwiftUI
import Combine
import UIKit

struct RootView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: AppTab = .home
    @State private var showingAuth = false
    @State private var presentedBattleRoom: PresentedBattleRoom?
    @State private var showingFirstLaunchIntro = true
    @State private var tabBarHidden = false

    var body: some View {
        @Bindable var bindableSession = session

        ZStack {
            TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView(showingAuth: $showingAuth)
            }
            .tijingRootTabChrome()
            .tabItem { Label("首页", systemImage: "house") }
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
            .tijingRootTabChrome()
            .tabItem { Label("刷题", systemImage: "book.pages") }
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
            .tijingRootTabChrome()
            .tabItem { Label("对战", systemImage: "bolt.horizontal.circle") }
            .tag(AppTab.battle)

            NavigationStack {
                RankingView()
            }
            .tijingRootTabChrome()
            .tabItem { Label("排行", systemImage: "trophy") }
            .tag(AppTab.ranking)

            NavigationStack {
                ProfileView(showingAuth: $showingAuth)
            }
            .tijingRootTabChrome()
            .tabItem { Label("我的", systemImage: "person.crop.circle") }
            .badge(session.unreadNotifications)
            .tag(AppTab.profile)
            }
            .toolbar(.hidden, for: .tabBar)
            .background(TijingSystemTabBarHider())
            .onPreferenceChange(TijingTabBarHiddenPreferenceKey.self) { hidden in
                withAnimation(.spring(response: 0.40, dampingFraction: 0.88)) {
                    tabBarHidden = hidden
                }
            }
            .scaleEffect(showingFirstLaunchIntro ? 1.012 : 1)
            .opacity(showingFirstLaunchIntro ? 0.94 : 1)
            .animation(.easeOut(duration: 0.34), value: showingFirstLaunchIntro)

            if showingFirstLaunchIntro {
                FirstLaunchIntroView {
                    finishFirstLaunchIntro()
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !tabBarHidden && !showingFirstLaunchIntro {
                TijingCinevaGlassTabBar(
                    selection: $selectedTab,
                    unreadCount: session.unreadNotifications
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(50)
            }
        }
        .tint(.accentColor)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: tabBarHidden)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: showingFirstLaunchIntro)
        .sensoryFeedback(.selection, trigger: selectedTab)
        .onAppear { Haptics.prepare() }
        .sheet(isPresented: $showingAuth) {
            AuthView()
                .presentationDragIndicator(.visible)
        }
        .overlay(alignment: .top) {
            if !showingFirstLaunchIntro && session.isBootstrapping && session.user == nil {
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

    private func finishFirstLaunchIntro() {
        guard showingFirstLaunchIntro else { return }
        withAnimation(.easeOut(duration: 0.30)) {
            showingFirstLaunchIntro = false
        }
    }
}

private struct FirstLaunchIntroView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    let onFinished: () -> Void

    @State private var entered = false
    @State private var gathered = false
    @State private var exiting = false
    @State private var didFinish = false

    var body: some View {
        ZStack {
            TijingPageBackground()

            RadialGradient(
                colors: [
                    TijingDesign.butter.opacity(colorScheme == .dark ? 0.08 : 0.28),
                    TijingDesign.sky.opacity(colorScheme == .dark ? 0.05 : 0.16),
                    .clear
                ],
                center: .center,
                startRadius: 24,
                endRadius: 260
            )
            .ignoresSafeArea()

            stickerCluster
                .scaleEffect(exiting ? 0.90 : 1)
                .offset(y: exiting ? -16 : 0)
                .opacity(exiting ? 0 : 1)

            VStack {
                Spacer()
                Text("轻触即可进入")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .opacity(entered && !exiting ? 1 : 0)
                    .padding(.bottom, 34)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { finishNow() }
        .task { await play() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("题竞欢迎动画，轻触进入")
    }

    private var stickerCluster: some View {
        ZStack {
            sticker(
                "checkmark.circle.fill",
                tint: TijingDesign.mint,
                background: TijingDesign.sage,
                size: 50,
                rotation: -9,
                final: CGSize(width: -112, height: -118),
                initial: CGSize(width: -180, height: -172)
            )

            sticker(
                "star.fill",
                tint: TijingDesign.amber,
                background: TijingDesign.butter,
                size: 45,
                rotation: 8,
                final: CGSize(width: 112, height: -104),
                initial: CGSize(width: 176, height: -160)
            )

            sticker(
                "book.pages.fill",
                tint: TijingDesign.indigo,
                background: TijingDesign.lilac,
                size: 54,
                rotation: -6,
                final: CGSize(width: -112, height: 112),
                initial: CGSize(width: -178, height: 166)
            )

            sticker(
                "chart.line.uptrend.xyaxis",
                tint: TijingDesign.cyan,
                background: TijingDesign.sky,
                size: 48,
                rotation: 7,
                final: CGSize(width: 116, height: 112),
                initial: CGSize(width: 178, height: 168)
            )

            ZStack {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(TijingDesign.peach.opacity(colorScheme == .dark ? 0.18 : 0.50))
                    .frame(width: 204, height: 230)
                    .rotationEffect(.degrees(entered ? -6 : -14))
                    .offset(x: -5, y: 7)

                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(TijingDesign.sky.opacity(colorScheme == .dark ? 0.16 : 0.42))
                    .frame(width: 204, height: 230)
                    .rotationEffect(.degrees(entered ? 5 : 12))
                    .offset(x: 7, y: 4)

                VStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(TijingDesign.primaryGradient)
                            .frame(width: 78, height: 78)

                        Image("LaunchAppIcon")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 70, height: 70)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(.white.opacity(0.28), lineWidth: 1)
                            }

                        Image(systemName: "sparkle")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.86))
                            .offset(x: 29, y: -28)
                    }

                    VStack(spacing: 6) {
                        Text("题竞")
                            .font(.system(.title, design: .rounded, weight: .heavy))
                        Text("把每一次练习都留下来")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 204, height: 230)
                .background(
                    Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 34, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.055))
                }
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.08),
                    radius: 26,
                    y: 15
                )
            }
            .scaleEffect(entered ? (gathered ? 0.97 : 1) : 0.68)
            .rotationEffect(.degrees(entered ? 0 : -5))
            .opacity(entered ? 1 : 0)
        }
        .animation(.spring(response: 0.58, dampingFraction: 0.78), value: entered)
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: gathered)
        .animation(.easeInOut(duration: 0.28), value: exiting)
    }

    private func sticker(
        _ systemImage: String,
        tint: Color,
        background: Color,
        size: CGFloat,
        rotation: Double,
        final: CGSize,
        initial: CGSize
    ) -> some View {
        TijingStickerIcon(
            systemImage: systemImage,
            tint: tint,
            background: background,
            size: size,
            rotation: rotation
        )
        .offset(
            x: entered ? final.width * (gathered ? 0.93 : 1) : initial.width,
            y: entered ? final.height * (gathered ? 0.93 : 1) : initial.height
        )
        .scaleEffect(entered ? 1 : 0.62)
        .opacity(entered ? 1 : 0)
    }

    @MainActor
    private func play() async {
        if reduceMotion {
            entered = true
            try? await Task.sleep(for: .milliseconds(360))
            finishNow()
            return
        }

        withAnimation(.spring(response: 0.58, dampingFraction: 0.76)) {
            entered = true
        }
        try? await Task.sleep(for: .milliseconds(460))
        guard !Task.isCancelled, !didFinish else { return }

        Haptics.light()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            gathered = true
        }
        try? await Task.sleep(for: .milliseconds(360))
        guard !Task.isCancelled, !didFinish else { return }

        withAnimation(.easeInOut(duration: 0.28)) {
            exiting = true
        }
        try? await Task.sleep(for: .milliseconds(220))
        guard !Task.isCancelled, !didFinish else { return }
        complete()
    }

    @MainActor
    private func finishNow() {
        guard !didFinish else { return }
        if reduceMotion {
            complete()
            return
        }
        withAnimation(.easeOut(duration: 0.20)) {
            exiting = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            complete()
        }
    }

    @MainActor
    private func complete() {
        guard !didFinish else { return }
        didFinish = true
        onFinished()
    }
}

enum AppTab: Hashable, CaseIterable {
    case home, practice, battle, ranking, profile

    var title: String {
        switch self { case .home: "首页"; case .practice: "刷题"; case .battle: "对战"; case .ranking: "排行"; case .profile: "我的" }
    }

    var icon: String {
        switch self { case .home: "house"; case .practice: "book.pages"; case .battle: "bolt.horizontal.circle"; case .ranking: "trophy"; case .profile: "person.crop.circle" }
    }

    var selectedIcon: String {
        switch self { case .home: "house.fill"; case .practice: "book.pages.fill"; case .battle: "bolt.horizontal.circle.fill"; case .ranking: "trophy.fill"; case .profile: "person.crop.circle.fill" }
    }
}

private struct TijingRootTabChromeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbar(.hidden, for: .tabBar)
    }
}

private extension View {
    func tijingRootTabChrome() -> some View {
        modifier(TijingRootTabChromeModifier())
    }
}

private enum TijingTabBarLayout {
    static let reservedHeight: CGFloat = 90
}

private struct TijingTabBarContentClearanceKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var tijingTabBarContentClearance: CGFloat {
        get { self[TijingTabBarContentClearanceKey.self] }
        set { self[TijingTabBarContentClearanceKey.self] = newValue }
    }
}

struct TijingTabBarContentFooter: View {
    @Environment(\.tijingTabBarContentClearance) private var clearance

    var body: some View {
        Color.clear
            .frame(height: clearance)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct TijingCinevaGlassTabBar: View {
    @Binding var selection: AppTab
    let unreadCount: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var dragLocationX: CGFloat?
    @State private var previewSelection: AppTab?
    @State private var isInteracting = false

    private let horizontalInset: CGFloat = 5
    private let barHeight: CGFloat = 64
    private let contentClearance: CGFloat = 18

    var body: some View {
        GeometryReader { proxy in
            let availableWidth = max(proxy.size.width - horizontalInset * 2, 1)
            let itemWidth = availableWidth / CGFloat(AppTab.allCases.count)
            let indicatorWidth = max(itemWidth - 6, 48)
            let selectedCenter = centerX(for: visualSelection, itemWidth: itemWidth)
            let indicatorCenter = dragLocationX.map {
                min(max($0, centerX(for: .home, itemWidth: itemWidth)), centerX(for: .profile, itemWidth: itemWidth))
            } ?? selectedCenter

            ZStack(alignment: .leading) {
                selectedGlass
                    .frame(width: indicatorWidth, height: 52)
                    .scaleEffect(x: isInteracting ? 1.035 : 1, y: isInteracting ? 0.985 : 1)
                    .offset(x: indicatorCenter - indicatorWidth / 2)
                    .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.90), value: selection)

                HStack(spacing: 0) {
                    ForEach(AppTab.allCases, id: \.self) { tab in
                        tabItem(tab)
                            .frame(width: itemWidth, height: 54)
                    }
                }
                .padding(.horizontal, horizontalInset)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(glassBackground)
            .contentShape(Capsule())
            .scaleEffect(isInteracting ? 1.003 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: isInteracting)
            .gesture(dragGesture(width: proxy.size.width, itemWidth: itemWidth))
            .simultaneousGesture(tapGesture(width: proxy.size.width, itemWidth: itemWidth))
        }
        .frame(height: barHeight)
        .padding(.horizontal, 12)
        .padding(.top, contentClearance)
        .padding(.bottom, 8)
    }

    private var glassBackground: some View {
        Capsule()
            .fill(.ultraThinMaterial)
            .overlay {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(colorScheme == .dark ? 0.13 : 0.33),
                                .white.opacity(0.035),
                                .black.opacity(colorScheme == .dark ? 0.10 : 0.025)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(colorScheme == .dark ? 0.36 : 0.78),
                                .white.opacity(0.16),
                                .black.opacity(colorScheme == .dark ? 0.26 : 0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.85
                    )
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.30 : 0.16), radius: 20, x: 0, y: 10)
    }

    private var selectedGlass: some View {
        Capsule()
            .fill(.regularMaterial)
            .overlay {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(colorScheme == .dark ? 0.20 : 0.50),
                                Color.accentColor.opacity(colorScheme == .dark ? 0.30 : 0.18),
                                .white.opacity(colorScheme == .dark ? 0.05 : 0.16)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(colorScheme == .dark ? 0.58 : 0.92),
                                .white.opacity(colorScheme == .dark ? 0.18 : 0.42),
                                Color.accentColor.opacity(0.24),
                                .black.opacity(colorScheme == .dark ? 0.25 : 0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .overlay {
                Capsule()
                    .trim(from: 0.06, to: 0.47)
                    .stroke(.white.opacity(colorScheme == .dark ? 0.48 : 0.86), style: StrokeStyle(lineWidth: 1.15, lineCap: .round))
                    .padding(1.5)
            }
            .shadow(color: Color.accentColor.opacity(colorScheme == .dark ? 0.18 : 0.12), radius: 7, y: 2)
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.16 : 0.07), radius: 4, y: 3)
    }

    private func tabItem(_ tab: AppTab) -> some View {
        let isSelected = visualSelection == tab

        return VStack(spacing: 2) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                    .font(.system(size: 19, weight: isSelected ? .semibold : .medium))
                    .symbolRenderingMode(.monochrome)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 27, height: 25)

                if tab == .profile && unreadCount > 0 {
                    Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
                        .font(.system(size: unreadCount > 9 ? 7 : 8, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, unreadCount > 9 ? 3 : 0)
                        .frame(minWidth: 15, minHeight: 15)
                        .background(.red, in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.88), lineWidth: 1))
                        .offset(x: 7, y: -5)
                }
            }

            Text(tab.title)
                .font(.system(size: 10, weight: isSelected ? .semibold : .medium, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(isSelected ? Color.accentColor : Color.primary.opacity(colorScheme == .dark ? 0.72 : 0.62))
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isSelected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tab.title)
        .accessibilityValue(isSelected ? "已选择" : "")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction {
            select(tab)
        }
    }

    private func dragGesture(width: CGFloat, itemWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .local)
            .onChanged { value in
                let lowerBound = centerX(for: .home, itemWidth: itemWidth)
                let upperBound = centerX(for: .profile, itemWidth: itemWidth)
                let location = min(max(value.location.x, lowerBound), upperBound)
                dragLocationX = location
                isInteracting = true
                let hoveredTab = tab(at: location, itemWidth: itemWidth, totalWidth: width)
                if previewSelection != hoveredTab {
                    previewSelection = hoveredTab
                }
            }
            .onEnded { value in
                let location = min(max(value.location.x, 0), width)
                let destination = tab(at: location, itemWidth: itemWidth, totalWidth: width)
                select(destination)
                withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.90)) {
                    dragLocationX = nil
                    previewSelection = nil
                    isInteracting = false
                }
            }
    }

    private func tapGesture(width: CGFloat, itemWidth: CGFloat) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                let location = min(max(value.location.x, 0), width)
                select(tab(at: location, itemWidth: itemWidth, totalWidth: width))
            }
    }

    private func centerX(for tab: AppTab, itemWidth: CGFloat) -> CGFloat {
        let index = AppTab.allCases.firstIndex(of: tab) ?? 0
        return horizontalInset + itemWidth * (CGFloat(index) + 0.5)
    }

    private func tab(at x: CGFloat, itemWidth: CGFloat, totalWidth: CGFloat) -> AppTab {
        let clampedX = min(max(x - horizontalInset, 0), max(totalWidth - horizontalInset * 2 - 0.001, 0))
        let index = min(max(Int(clampedX / itemWidth), 0), AppTab.allCases.count - 1)
        return AppTab.allCases[index]
    }

    private func select(_ tab: AppTab) {
        guard selection != tab else { return }
        selection = tab
    }

    private var visualSelection: AppTab {
        previewSelection ?? selection
    }
}

private struct TijingSystemTabBarHider: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ uiViewController: Controller, context: Context) {
        uiViewController.hideSystemTabBar()
        DispatchQueue.main.async {
            uiViewController.hideSystemTabBar()
        }
    }

    final class Controller: UIViewController {
        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .clear
            view.isUserInteractionEnabled = false
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            hideSystemTabBar()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            hideSystemTabBar()
        }

        func hideSystemTabBar() {
            if let tabBar = tabBarController?.tabBar, !tabBar.isHidden {
                tabBar.isHidden = true
            }
            if let tabBar = parent?.tabBarController?.tabBar, !tabBar.isHidden {
                tabBar.isHidden = true
            }
        }
    }
}

private struct TijingTabBarHiddenPreferenceKey: PreferenceKey {
    static var defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

extension View {
    func tijingTabBarHidden(_ hidden: Bool = true) -> some View {
        preference(key: TijingTabBarHiddenPreferenceKey.self, value: hidden)
    }
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
