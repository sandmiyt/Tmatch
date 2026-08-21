import SwiftUI

struct HomeView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var showingAuth: Bool
    @State private var loadError: String?
    @State private var calendarCarouselIndex = 0

    private var stats: StatsResponse? { session.homeStats }
    private var smartReview: SmartReviewSummary? { session.homeSmartReview }
    private var challenge: DailyChallengeSummary? { session.homeChallenge }
    private var dailyPlan: LearningDiagnostics? { session.homeDiagnostics }
    private var calendarSummary: ExamCalendarSummary? { session.homeCalendarSummary }

    private var gridColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize { return [GridItem(.flexible())] }
        return [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    }

    var body: some View {
        ZStack {
            TijingPageBackground()

            ScrollView {
                LazyVStack(spacing: TijingDesign.sectionSpacing) {
                    pageHeader
                        .tijingReveal(order: 0)

                    if session.isAuthenticated {
                        continueHero
                            .tijingReveal(order: 1)
                        todaySection
                            .tijingReveal(order: 2)
                        pulseSection
                            .tijingReveal(order: 3)
                        utilitySection
                            .tijingReveal(order: 4)
                    } else {
                        signInHero
                            .tijingReveal(order: 1)
                    }

                    if let loadError {
                        Label(loadError, systemImage: "wifi.exclamationmark")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .tijingCard()
                    }
                }
                .padding(.horizontal, TijingDesign.pageHorizontalPadding)
                .padding(.top, 10)
                .padding(.bottom, 28)
            }
            .refreshable { await load() }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if session.isAuthenticated {
                    NavigationLink {
                        NotificationsView()
                    } label: {
                        notificationButton
                    }
                    .tijingTactileLink()
                } else {
                    Button("登录") {
                        Haptics.selection()
                        showingAuth = true
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .task(id: session.user?.id) { await load() }
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("上岸之前，先上分。")
                .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.74)
            Text(session.isAuthenticated ? homeSummary : "把每一次练习都变成看得见的进步。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var continueHero: some View {
        NavigationLink {
            DirectPracticeLauncherView(
                mode: .random,
                subject: dailyPlan?.analysis.summary.focus?.subject,
                topic: dailyPlan?.analysis.summary.focus?.topic
            )
        } label: {
            TijingHeroCard(
                gradient: LinearGradient(
                    colors: [Color(red: 0.20, green: 0.22, blue: 0.55), TijingDesign.indigo, TijingDesign.violet.opacity(0.92)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            ) {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(.white.opacity(0.10))
                        .frame(width: 118, height: 118)
                        .offset(x: 42, y: -48)
                    Circle()
                        .stroke(.white.opacity(0.11), lineWidth: 1)
                        .frame(width: 74, height: 74)
                        .offset(x: 12, y: 12)

                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .center, spacing: 18) {
                            livelyHeroCopy
                            Spacer(minLength: 4)
                            practiceHeroVisual
                        }
                        VStack(alignment: .leading, spacing: 18) {
                            livelyHeroCopy
                            practiceHeroVisual
                        }
                    }
                }
                .foregroundStyle(.white)
            }
        }
        .buttonStyle(TijingPressableCardStyle())
        .tijingTactileLink()
    }

    private var livelyHeroCopy: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                TijingStickerIcon(
                    systemImage: "book.pages.fill",
                    tint: .white,
                    background: .white.opacity(0.16),
                    size: 38,
                    rotation: -5,
                    sparkle: false
                )
                Text("继续刷题")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.84))
            }

            Text(dailyPlan?.analysis.summary.focus?.topic ?? dailyPlan?.analysis.summary.focus?.subject ?? "今天继续稳住手感")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .lineLimit(2)

            Text(dailyPlanSubtitle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.76))
                .lineLimit(2)

            HStack(spacing: 8) {
                if let total = stats?.questions {
                    heroMetric("\(total)", "已刷", icon: "checkmark.circle.fill")
                }
                heroMetric(TijingFormat.percent(stats?.accuracy7d), "近7天", icon: "chart.line.uptrend.xyaxis")
            }
        }
    }

    private func heroMetric(_ value: String, _ title: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.caption2.weight(.bold))
            Text(value).font(.caption.weight(.bold)).monospacedDigit()
            Text(title).font(.caption2).opacity(0.72)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(.white.opacity(0.12), in: Capsule())
    }

    private var practiceHeroVisual: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white.opacity(0.11))
                .frame(width: 110, height: 132)
                .rotationEffect(.degrees(7))
                .offset(x: 7, y: 3)

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white.opacity(0.18))
                .frame(width: 110, height: 132)
                .rotationEffect(.degrees(-3))
                .overlay {
                    VStack(spacing: 10) {
                        TijingProgressRing(
                            progress: (stats?.accuracy7d ?? 0) / 100,
                            value: TijingFormat.percent(stats?.accuracy7d),
                            caption: "正确率"
                        )
                        HStack(spacing: 5) {
                            Text("开始下一组").font(.caption.weight(.semibold))
                            Image(systemName: "arrow.up.right").font(.caption2.bold())
                        }
                    }
                    .padding(10)
                }
        }
        .frame(width: 126, height: 144)
    }

    private var todaySection: some View {
        VStack(spacing: 12) {
            TijingSectionHeading("今天", subtitle: "任务不需要多，先把最值钱的三件事做完")

            LazyVGrid(columns: gridColumns, spacing: 12) {
                NavigationLink {
                    DailyChallengeView()
                } label: {
                    TijingActionTile(
                        title: "今日挑战",
                        subtitle: challengeSubtitle,
                        systemImage: "flame.fill",
                        tint: TijingDesign.coral,
                        emphasis: true
                    )
                }
                .buttonStyle(TijingPressableCardStyle())
                .tijingTactileLink()

                NavigationLink {
                    LearningView()
                } label: {
                    TijingActionTile(
                        title: "学习诊断",
                        subtitle: "查看近期正确率、速度与训练重点",
                        systemImage: "chart.xyaxis.line",
                        tint: TijingDesign.violet
                    )
                }
                .buttonStyle(TijingPressableCardStyle())
                .tijingTactileLink()
            }

            examCalendarCarousel
        }
    }

    private var pulseSection: some View {
        VStack(spacing: 12) {
            TijingSectionHeading("学习脉搏", subtitle: "一眼看清最近的状态，不用翻报表")

            LazyVGrid(columns: gridColumns, spacing: 12) {
                TijingMetricTile(
                    value: TijingFormat.percent(stats?.accuracy7d),
                    title: "7 天正确率",
                    systemImage: "scope",
                    tint: TijingDesign.mint
                )

                TijingMetricTile(
                    value: stats?.questions.map(String.init) ?? "—",
                    title: "累计刷题",
                    systemImage: "checkmark.circle.fill",
                    tint: .accentColor
                )

                NavigationLink {
                    DirectPracticeLauncherView(mode: .wrong)
                } label: {
                    TijingMetricTile(
                        value: stats?.wrong.map(String.init) ?? "—",
                        title: "错题待复习",
                        systemImage: "arrow.counterclockwise.circle.fill",
                        tint: TijingDesign.coral
                    )
                }
                .buttonStyle(TijingPressableCardStyle())
                .tijingTactileLink()

                NavigationLink {
                    DirectPracticeLauncherView(mode: .favorite)
                } label: {
                    TijingMetricTile(
                        value: stats?.favorites.map(String.init) ?? "—",
                        title: "已收藏",
                        systemImage: "star.fill",
                        tint: TijingDesign.amber
                    )
                }
                .buttonStyle(TijingPressableCardStyle())
                .tijingTactileLink()
            }
        }
    }

    private var utilitySection: some View {
        VStack(spacing: 12) {
            TijingSectionHeading("一起上分")
            NavigationLink {
                FriendsView()
            } label: {
                TijingSettingsGroup {
                    TijingSettingsRow(
                        "好友与挑战",
                        subtitle: "看看谁在线，直接约一局或发起 48 小时挑战",
                        systemImage: "person.2.fill",
                        tint: TijingDesign.cyan
                    )
                }
            }
            .buttonStyle(TijingPressableCardStyle())
            .tijingTactileLink()
        }
    }

    private var signInHero: some View {
        TijingHeroCard {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 36, weight: .semibold))
                Text("登录后，进度才真正属于你")
                    .font(.title2.bold())
                Text("刷题、错题、收藏、好友与对战记录都会和现有题竞账号同步。")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.78))

                Button {
                    Haptics.medium()
                    showingAuth = true
                } label: {
                    Label("登录 / 注册", systemImage: "arrow.right.circle.fill")
                        .font(.headline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.white, in: Capsule())
                        .foregroundStyle(.black)
                }
                .buttonStyle(TijingPressableCardStyle())
            }
            .foregroundStyle(.white)
        }
    }

    private var notificationButton: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "bell.fill")
                .font(.body.weight(.semibold))
                .frame(width: 34, height: 34)
                .background(.regularMaterial, in: Circle())
            if session.unreadNotifications > 0 {
                Text(session.unreadNotifications > 99 ? "99+" : "\(session.unreadNotifications)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .frame(minWidth: 16, minHeight: 16)
                    .background(.red, in: Capsule())
                    .offset(x: 5, y: -4)
            }
        }
        .accessibilityLabel(session.unreadNotifications > 0 ? "通知，\(session.unreadNotifications) 条未读" : "通知")
    }

    private var examCalendarCarousel: some View {
        let followed = calendarSummary?.followedHighlights ?? []
        return NavigationLink {
            ExamCalendarView()
        } label: {
            TijingPaperCard(tint: TijingDesign.butter, rotation: -0.15) {
                HStack(spacing: 13) {
                    TijingStickerIcon(
                        systemImage: followed.isEmpty ? "calendar.badge.clock" : "star.fill",
                        tint: TijingDesign.amber,
                        background: TijingDesign.butter,
                        size: 46,
                        rotation: -6,
                        sparkle: !followed.isEmpty
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 7) {
                            Text("考试日历").font(.headline)
                            if !followed.isEmpty {
                                Text("关注 \(followed.count)")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(TijingDesign.amber)
                            }
                        }

                        if let item = carouselExam(from: followed) {
                            Text(shortExamTitle(item.title))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .contentTransition(.opacity)
                            Text(carouselCountdown(item))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .contentTransition(.numericText())
                        } else {
                            Text(calendarSubtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(TijingPressableCardStyle())
        .tijingTactileLink()
        .task(id: followed.map(\.id)) {
            guard followed.count > 1 else { calendarCarouselIndex = 0; return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4.2))
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                        calendarCarouselIndex = (calendarCarouselIndex + 1) % followed.count
                    }
                }
            }
        }
    }

    private func carouselExam(from items: [RecruitmentExam]) -> RecruitmentExam? {
        guard !items.isEmpty else { return nil }
        return items[min(calendarCarouselIndex, items.count - 1)]
    }

    private func shortExamTitle(_ title: String) -> String {
        title
            .replacingOccurrences(of: "关于", with: "")
            .replacingOccurrences(of: "公告", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func carouselCountdown(_ exam: RecruitmentExam) -> String {
        let place = exam.city.flatMap { $0.isEmpty ? nil : $0 } ?? "四川"
        let node = exam.nextLabel ?? "查看节点"
        if let days = exam.daysToNext {
            return "\(place) · \(node) · \(days == 0 ? "今天" : "还有 \(days) 天")"
        }
        return "\(place) · \(node)"
    }

    private var homeSummary: String {
        if let due = smartReview?.due, due > 0 {
            return "今天还有 \(due) 道题适合复习，先把最容易忘的内容稳住。"
        }
        if let focus = dailyPlan?.analysis.summary.focus {
            let name = focus.topic ?? focus.subject
            if let name, !name.isEmpty { return "今天可以重点巩固 \(name)。" }
        }
        return "今天的学习状态已经同步，可以直接开始下一组。"
    }

    private var challengeSubtitle: String {
        guard let challenge else { return "每天同题挑战，看看今天能排到哪里" }
        if let best = challenge.myBest { return "我的最好：\(best.correctCount ?? 0)题" }
        return "今日已有 \(challenge.challengerCount ?? 0) 人挑战"
    }

    private var dailyPlanSubtitle: String {
        guard let dailyPlan else { return "正在生成今天的训练重点…" }
        let due = smartReview?.due ?? 0
        let focus = dailyPlan.analysis.summary.focus
        let focusName = focus?.topic ?? focus?.subject
        let averageSeconds = dailyPlan.overview.averageElapsedMS > 0
            ? max(28.0, min(70.0, Double(dailyPlan.overview.averageElapsedMS) / 1000.0))
            : 45.0
        let minutes = max(6, min(20, Int(((15.0 * averageSeconds) / 60.0).rounded())))
        let headline: String
        if due > 0, let focusName, !focusName.isEmpty {
            headline = "先复习 \(min(5, due)) 题，再强化 \(focusName)"
        } else if due > 0 {
            headline = "优先完成 \(min(15, due)) 道到期复习"
        } else if let focusName, !focusName.isEmpty {
            headline = "今天优先巩固 \(focusName)"
        } else if (stats?.wrong ?? 0) > 0 {
            headline = "先把近期错题稳一稳"
        } else {
            headline = "完成一组练习，继续建立学习画像"
        }
        return "\(headline) · 预计 \(minutes) 分钟"
    }

    private var calendarSubtitle: String {
        guard let exam = calendarSummary?.nextExam else {
            return "官方公告自动同步，支持关注考试与倒计时"
        }
        let place = exam.city.flatMap { $0.isEmpty ? nil : $0 } ?? "四川"
        let node = exam.nextLabel ?? "查看考试节点"
        if let days = exam.daysToNext {
            return "\(place) · \(node) · \(days == 0 ? "就是今天" : "还有 \(days) 天")"
        }
        return "\(place) · \(node)"
    }

    @MainActor
    private func load() async {
        guard session.token != nil else {
            loadError = nil
            return
        }
        do {
            try await session.refreshHomeSnapshot()
            loadError = nil
        } catch {
            // Keep the last successful snapshot visible when refresh fails.
            loadError = session.homeStats == nil ? error.localizedDescription : nil
        }
    }
}
