import SwiftUI

struct PracticeCatalogView: View {
    @Environment(SessionStore.self) private var session
    let initialMode: PracticeMode
    @State private var mode: PracticeMode
    @State private var catalog: [PracticeSubject] = []
    @State private var settings = PracticeSettings()
    @State private var loading = false
    @State private var error: String?
    @State private var settingsOpen = false

    init(initialMode: PracticeMode) {
        self.initialMode = initialMode
        _mode = State(initialValue: initialMode)
    }

    var body: some View {
        ZStack {
            TijingPageBackground()

            if session.token == nil {
                ContentUnavailableView("需要登录", systemImage: "person.crop.circle.badge.exclamationmark", description: Text("专注刷题会同步你的学习记录。"))
            } else if loading && catalog.isEmpty {
                ProgressView("正在读取题库")
            } else {
                ScrollView {
                    LazyVStack(spacing: 20) {
                        pageHeader
                        modeSelector

                        if mode == .wrong || mode == .favorite || mode == .smartReview {
                            quickStart
                        }

                        TijingSectionHeading("选择题库", subtitle: "展开题库后可以直接选择全部章节或具体章节")

                        ForEach(catalog) { subject in
                            subjectCard(subject)
                        }

                        if let error {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .tijingCard()
                        }
                    }
                    .padding(.horizontal, TijingDesign.pageHorizontalPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
                .refreshable { await loadCatalog() }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if mode == .random {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        settingsOpen = true
                        Haptics.selection()
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.body.weight(.semibold))
                    }
                    .accessibilityLabel("练习设置")
                }
            }
        }
        .sheet(isPresented: $settingsOpen) {
            NavigationStack { PracticeSettingsView(settings: $settings, onSave: saveSettings) }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sensoryFeedback(.selection, trigger: mode.rawValue)
        .task { await loadAll() }
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(mode.title)
                .font(.system(.largeTitle, design: .rounded, weight: .heavy))
            Text(modeDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var modeSelector: some View {
        HStack(spacing: 12) {
            Image(systemName: modeIcon)
                .font(.headline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 38, height: 38)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("练习类型")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(mode.title)
                    .font(.body.weight(.semibold))
            }

            Spacer()

            Picker("练习类型", selection: $mode) {
                Text("专注刷题").tag(PracticeMode.random)
                Text("错题重练").tag(PracticeMode.wrong)
                Text("收藏练习").tag(PracticeMode.favorite)
                Text("智能复习").tag(PracticeMode.smartReview)
                Text("模拟考试").tag(PracticeMode.exam)
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
        .padding(15)
        .tijingCard()
    }

    private var quickStart: some View {
        sessionLink(subject: nil, topic: nil) {
            TijingHeroCard(
                gradient: LinearGradient(
                    colors: quickStartColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            ) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("快速开始", systemImage: "play.fill")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.80))
                        Text("开始\(mode.title)")
                            .font(.title2.bold())
                        Text(mode == .smartReview ? "系统会优先安排最值得复习的内容。" : "沿用当前每组题量与答题方式，直接进入。")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.74))
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 34, weight: .semibold))
                }
                .foregroundStyle(.white)
            }
        }
        .buttonStyle(TijingPressableCardStyle())
        .tijingTactileLink()
    }

    private func subjectCard(_ subject: PracticeSubject) -> some View {
        DisclosureGroup {
            VStack(spacing: 0) {
                sessionLink(subject: subject.name, topic: nil) {
                    catalogRow(
                        title: "全部 \(subject.name)",
                        count: subject.count,
                        progress: nil,
                        icon: "rectangle.stack.fill"
                    )
                }
                .buttonStyle(.plain)
                .tijingTactileLink()

                ForEach(subject.topics.filter { $0.count > 0 }) { topic in
                    Divider().padding(.leading, 54)
                    sessionLink(subject: subject.name, topic: topic.topic) {
                        catalogRow(
                            title: topic.topic,
                            count: topic.count,
                            progress: topic.progress,
                            icon: "circle.fill"
                        )
                    }
                    .buttonStyle(.plain)
                    .tijingTactileLink()
                }
            }
            .padding(.top, 8)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: subjectIcon(subject.name))
                    .font(.headline)
                    .foregroundStyle(subjectTint(subject.name))
                    .frame(width: 38, height: 38)
                    .background(subjectTint(subject.name).opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(subject.name)
                        .font(.headline)
                    Text("\(subject.count) 道题")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .tint(.primary)
        .padding(16)
        .tijingCard()
    }

    private func catalogRow(title: String, count: Int, progress: Int?, icon: String) -> some View {
        VStack(spacing: 7) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(icon == "circle.fill" ? .system(size: 6) : .caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Spacer(minLength: 8)
                Text("\(count)题")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Image(systemName: "chevron.right")
                    .font(.caption2.bold())
                    .foregroundStyle(.tertiary)
            }
            if let progress {
                ProgressView(value: Double(progress), total: 100)
                    .tint(subjectTint(title))
                    .padding(.leading, 30)
                    .accessibilityLabel("完成进度 \(progress)%")
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var modeDescription: String {
        switch mode {
        case .random: return "选一个范围，按当前设置开始下一组。"
        case .wrong: return "只处理错题；答对后继续按现有规则移出错题。"
        case .favorite: return "把收藏过的重点集中练一遍。"
        case .smartReview: return "优先复习最容易遗忘、最值得投入时间的内容。"
        case .exam: return "完整作答后统一交卷，更接近正式考试节奏。"
        }
    }

    private var modeIcon: String {
        switch mode {
        case .random: "book.pages.fill"
        case .wrong: "arrow.counterclockwise.circle.fill"
        case .favorite: "star.fill"
        case .smartReview: "brain.head.profile"
        case .exam: "doc.text.magnifyingglass"
        }
    }

    private var quickStartColors: [Color] {
        switch mode {
        case .wrong: [TijingDesign.coral, TijingDesign.violet]
        case .favorite: [TijingDesign.amber, TijingDesign.coral]
        case .smartReview: [TijingDesign.violet, Color.accentColor]
        default: [Color.accentColor, TijingDesign.indigo]
        }
    }

    private func subjectTint(_ name: String) -> Color {
        if name.contains("法律") { return TijingDesign.indigo }
        if name.contains("政治") { return TijingDesign.coral }
        if name.contains("经济") { return TijingDesign.mint }
        if name.contains("公文") { return TijingDesign.violet }
        if name.contains("数量") { return TijingDesign.cyan }
        if name.contains("判断") { return TijingDesign.amber }
        if name.contains("资料") { return Color.accentColor }
        if name.contains("科技") || name.contains("地理") { return TijingDesign.mint }
        return Color.accentColor
    }

    private func subjectIcon(_ name: String) -> String {
        if name.contains("法律") { return "building.columns.fill" }
        if name.contains("政治") { return "flag.fill" }
        if name.contains("经济") { return "chart.line.uptrend.xyaxis" }
        if name.contains("公文") { return "doc.text.fill" }
        if name.contains("数量") { return "function" }
        if name.contains("判断") { return "square.grid.2x2.fill" }
        if name.contains("资料") { return "chart.bar.fill" }
        if name.contains("科技") || name.contains("地理") { return "globe.asia.australia.fill" }
        return "books.vertical.fill"
    }

    private func sessionLink<Label: View>(subject: String?, topic: String?, @ViewBuilder label: () -> Label) -> some View {
        NavigationLink {
            if let token = session.token, let userID = session.user?.id {
                PracticeSessionView(store: PracticeSessionStore(mode: mode, subject: subject, topic: topic, settings: settings, token: token, userID: userID))
            } else {
                ContentUnavailableView("需要登录", systemImage: "person.crop.circle")
            }
        } label: { label() }
    }

    @MainActor private func loadAll() async {
        await loadSettings()
        await loadCatalog()
    }

    @MainActor private func loadCatalog() async {
        guard let token = session.token else { return }
        loading = true
        defer { loading = false }
        do {
            let response: PracticeCatalogResponse = try await session.api.request("/api/practice/catalog", token: token)
            catalog = response.subjects
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor private func loadSettings() async {
        guard let token = session.token else { return }
        if let saved: PracticeSettings = try? await session.api.request("/api/practice/settings", token: token) {
            var value = saved
            value.normalize()
            settings = value
        }
    }

    @MainActor private func saveSettings(_ newValue: PracticeSettings) async {
        guard let token = session.token else { return }
        var normalized = newValue
        normalized.normalize()
        settings = normalized
        do {
            let response: PracticeSettings = try await session.api.request("/api/practice/settings", method: .post, body: normalized, token: token)
            var value = response
            value.normalize()
            settings = value
            Haptics.success()
        } catch {
            self.error = error.localizedDescription
            Haptics.error()
        }
    }
}
