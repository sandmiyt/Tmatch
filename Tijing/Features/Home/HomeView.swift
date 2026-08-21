import SwiftUI

struct HomeView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var showingAuth: Bool
    @State private var stats: StatsResponse?
    @State private var smartReview: SmartReviewSummary?
    @State private var challenge: DailyChallengeSummary?
    @State private var dailyPlan: LearningDiagnostics?
    @State private var calendarSummary: ExamCalendarSummary?
    @State private var loadError: String?

    var body: some View {
        List {
            Section {
                header
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 12, trailing: 20))
                    .listRowBackground(Color.clear)
            }

            if session.isAuthenticated {
                Section("继续") {
                    NavigationLink {
                        PracticeCatalogView(initialMode: .random)
                    } label: {
                        HomeFeatureRow(
                            title: "继续刷题",
                            subtitle: "按当前题量、难度与答题方式开始一组",
                            systemImage: "play.circle.fill"
                        )
                    }

                    NavigationLink {
                        DailyChallengeView()
                    } label: {
                        HomeFeatureRow(
                            title: "今日挑战 · 10题",
                            subtitle: challengeSubtitle,
                            systemImage: "flame.fill"
                        )
                    }

                    NavigationLink {
                        LearningView()
                    } label: {
                        HomeFeatureRow(
                            title: "今日上岸 · 智能训练",
                            subtitle: dailyPlanSubtitle,
                            systemImage: "target"
                        )
                    }
                }

                Section("学习概览") {
                    LabeledContent {
                        Text(TijingFormat.percent(stats?.accuracy7d))
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    } label: {
                        Label("近 7 天正确率", systemImage: "scope")
                    }

                    LabeledContent {
                        Text("\(stats?.questions ?? 0)")
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    } label: {
                        Label("已刷题量", systemImage: "checkmark.circle")
                    }

                    NavigationLink {
                        PracticeCatalogView(initialMode: .wrong)
                    } label: {
                        HomeValueRow(
                            title: "错题待复习",
                            value: "\(stats?.wrong ?? 0)",
                            systemImage: "arrow.counterclockwise.circle"
                        )
                    }

                    NavigationLink {
                        PracticeCatalogView(initialMode: .favorite)
                    } label: {
                        HomeValueRow(
                            title: "收藏题目",
                            value: "\(stats?.favorites ?? 0)",
                            systemImage: "star"
                        )
                    }
                }

                Section("快捷入口") {
                    NavigationLink {
                        FriendsView()
                    } label: {
                        HomeFeatureRow(
                            title: "好友",
                            subtitle: "查看在线状态、邀请对战与好友挑战",
                            systemImage: "person.2"
                        )
                    }

                    NavigationLink {
                        ExamCalendarView()
                    } label: {
                        HomeFeatureRow(
                            title: "四川事业编考试日历",
                            subtitle: calendarSubtitle,
                            systemImage: "calendar"
                        )
                    }
                }
            } else {
                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("登录后开始刷题", systemImage: "person.crop.circle.badge.checkmark")
                            .font(.headline)
                        Text("直接使用你现有的题竞账号，刷题、错题、收藏、好友和对战数据都会同步。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Button("登录 / 注册") {
                            Haptics.selection()
                            showingAuth = true
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .padding(.vertical, 8)
                }
            }

            if let loadError {
                Section {
                    Label(loadError, systemImage: "wifi.exclamationmark")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("首页")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if session.isAuthenticated {
                    NavigationLink {
                        NotificationsView()
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell")
                            if session.unreadNotifications > 0 {
                                Text(session.unreadNotifications > 99 ? "99+" : "\(session.unreadNotifications)")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 4)
                                    .frame(minWidth: 16, minHeight: 16)
                                    .background(.red, in: Capsule())
                                    .offset(x: 9, y: -8)
                            }
                        }
                    }
                    .accessibilityLabel(session.unreadNotifications > 0 ? "通知，\(session.unreadNotifications) 条未读" : "通知")
                } else {
                    Button("登录") {
                        Haptics.selection()
                        showingAuth = true
                    }
                }
            }
        }
        .refreshable { await load() }
        .task(id: session.user?.id) { await load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.user.map { greeting(for: $0.nickname) } ?? "你好")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("上岸之前，先上分。")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.72)
            Text(session.isAuthenticated ? homeSummary : "把练习、复习、对战和考试节点放进一个真正顺手的 iPhone 客户端。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
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
        guard let challenge else { return "每天同题竞技，看看今天能排到哪里" }
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

    private func greeting(for name: String) -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let prefix = hour < 11 ? "早上好" : (hour < 18 ? "下午好" : "晚上好")
        return "\(prefix)，\(name)"
    }

    @MainActor
    private func load() async {
        guard let token = session.token else {
            stats = nil
            smartReview = nil
            challenge = nil
            dailyPlan = nil
            calendarSummary = nil
            loadError = nil
            return
        }
        do {
            async let statsTask: StatsResponse = session.api.request("/api/stats/me", token: token)
            async let reviewTask: SmartReviewSummary = session.api.request("/api/learning/smart-review", token: token)
            async let challengeTask: DailyChallengeSummary = session.api.request("/api/challenges/daily/summary", token: token)
            async let planTask: LearningDiagnostics = session.api.request("/api/learning/diagnostics", token: token)
            async let calendarTask: ExamCalendarSummary = session.api.request("/api/exams/calendar/summary/me", token: token)
            stats = try await statsTask
            smartReview = try? await reviewTask
            challenge = try? await challengeTask
            dailyPlan = try? await planTask
            calendarSummary = try? await calendarTask
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }
}

private struct HomeFeatureRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.tint)
                .frame(width: 26)
        }
        .padding(.vertical, 3)
    }
}

private struct HomeValueRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Label(title, systemImage: systemImage)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}
