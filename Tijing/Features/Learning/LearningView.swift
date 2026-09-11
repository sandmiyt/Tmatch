import SwiftUI

struct LearningView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var diagnostics: LearningDiagnostics?
    @State private var review: SmartReviewSummary?
    @State private var loading = false
    @State private var error: String?

    private var twoColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.flexible()), GridItem(.flexible())]
    }

    var body: some View {
        ZStack {
            TijingPageBackground()
            if loading && diagnostics == nil {
                ProgressView("正在分析学习数据…")
            } else if let diagnostics {
                ScrollView {
                    LazyVStack(spacing: 26) {
                        header
                            .tijingReveal(order: 0)
                        snapshotCard(diagnostics)
                            .tijingReveal(order: 1)
                        focusNote(diagnostics)
                            .tijingReveal(order: 2)
                        actionDeck(diagnostics)
                            .tijingReveal(order: 3)
                        insightStrip(diagnostics)
                            .tijingReveal(order: 4)
                        subjectSection(diagnostics)
                            .tijingReveal(order: 5)
                        if let error {
                            Label(error, systemImage: "wifi.exclamationmark")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        TijingTabBarContentFooter()
                    }
                    .padding(.horizontal, TijingDesign.pageHorizontalPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 34)
                }
                .refreshable { await load() }
            } else {
                ContentUnavailableView {
                    Label("暂时无法生成学习诊断", systemImage: "brain.head.profile")
                } description: {
                    Text(error ?? "完成更多练习后，系统会根据真实作答记录生成诊断。")
                } actions: {
                    Button("重新加载") { Task { await load() } }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("学习诊断")
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                Text("把最近的表现，整理成今天真正值得做的事。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            TijingStickerIcon(systemImage: "brain.head.profile", tint: TijingDesign.violet, background: TijingDesign.lilac, size: 54, rotation: 6)
        }
    }

    private func snapshotCard(_ data: LearningDiagnostics) -> some View {
        TijingPaperCard(tint: TijingDesign.butter, rotation: -0.35) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 7) {
                            TijingMicroBadge(title: "近 7 天", systemImage: "calendar", tint: TijingDesign.amber)
                            TijingMicroBadge(title: "可信度 \(data.analysis.confidence)%", systemImage: "checkmark.seal.fill", tint: TijingDesign.mint)
                        }
                        Text("\(data.overview.sevenDayAccuracy)%")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .animation(.snappy(duration: 0.38), value: data.overview.sevenDayAccuracy)
                        Text("正确率 · \(data.overview.sevenDayTotal) 题")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    TijingStickerIcon(systemImage: trendIcon(data.overview.recent100Trend), tint: trendTint(data.overview.recent100Trend), background: TijingDesign.sky, size: 54, rotation: 7)
                }

                Divider().opacity(0.30)

                VStack(spacing: 12) {
                    TijingMiniStatRow(systemImage: "chart.line.uptrend.xyaxis", title: "最近 100 题", value: "\(data.overview.recent100Accuracy)%", tint: TijingDesign.indigo)
                    TijingMiniStatRow(systemImage: "timer", title: "平均答题时间", value: seconds(data.overview.averageElapsedMS), tint: TijingDesign.cyan)
                    TijingMiniStatRow(systemImage: "checkmark.circle.fill", title: "累计做题", value: "\(data.analysis.historyTotal)", tint: TijingDesign.mint)
                }
            }
        }
    }

    private func focusNote(_ data: LearningDiagnostics) -> some View {
        VStack(spacing: 11) {
            TijingSectionHeading("今天先看这里", subtitle: data.analysis.summary.title)

            TijingPaperCard(tint: TijingDesign.peach, rotation: 0.25) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center, spacing: 12) {
                        TijingStickerIcon(systemImage: "scope", tint: TijingDesign.coral, background: TijingDesign.peach, size: 48, rotation: -8)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("优先巩固")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(data.analysis.summary.focus?.title ?? "暂时没有明显薄弱项")
                                .font(.title3.weight(.bold))
                        }
                        Spacer()
                    }

                    Text(data.analysis.summary.focus?.detail ?? data.analysis.summary.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let signals = data.analysis.summary.focus?.signals, !signals.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 7) {
                                ForEach(signals.prefix(5), id: \.self) { signal in
                                    TijingMicroBadge(title: signal, systemImage: "sparkle", tint: TijingDesign.coral)
                                }
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "arrow.turn.down.right")
                            .foregroundStyle(TijingDesign.coral)
                        Text(nextAction(data))
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(TijingDesign.ink.opacity(0.78))
                    }
                }
            }
        }
    }

    private func actionDeck(_ data: LearningDiagnostics) -> some View {
        VStack(spacing: 12) {
            TijingSectionHeading("下一步", subtitle: "点一下就进入，不需要重新找入口")
            LazyVGrid(columns: twoColumns, spacing: 11) {
                actionCard(title: "今日复习", subtitle: "\(review?.due ?? 0) 题到期", icon: "clock.arrow.circlepath", tint: TijingDesign.sky) {
                    DirectPracticeLauncherView(mode: .smartReview)
                }
                if let focus = data.analysis.summary.focus {
                    actionCard(title: "专项练习", subtitle: focus.topic ?? focus.subject ?? "针对薄弱项", icon: "scope", tint: TijingDesign.sage) {
                        DirectPracticeLauncherView(mode: .random, subject: focus.subject, topic: focus.topic)
                    }
                }
                actionCard(title: "错题重练", subtitle: "把不稳的题再过一遍", icon: "arrow.counterclockwise.circle.fill", tint: TijingDesign.rose) {
                    DirectPracticeLauncherView(mode: .wrong)
                }
                actionCard(title: "收藏练习", subtitle: "回到自己留下的重点", icon: "star.fill", tint: TijingDesign.lilac) {
                    DirectPracticeLauncherView(mode: .favorite)
                }
            }
        }
    }

    private func actionCard<Destination: View>(title: String, subtitle: String, icon: String, tint: Color, @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink(destination: destination()) {
            TijingPaperCard(tint: tint) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        TijingStickerIcon(systemImage: icon, tint: TijingDesign.ink.opacity(0.75), background: tint, size: 42, rotation: -5, sparkle: false)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 2)
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .frame(minHeight: 116, alignment: .leading)
            }
        }
        .buttonStyle(TijingPressableCardStyle())
        .tijingTactileLink()
    }

    @ViewBuilder
    private func insightStrip(_ data: LearningDiagnostics) -> some View {
        let insights = Array(data.analysis.insights.prefix(3))
        if !insights.isEmpty {
            VStack(spacing: 11) {
                TijingSectionHeading("系统发现", subtitle: "只保留最值得注意的信号")
                VStack(spacing: 10) {
                    ForEach(Array(insights.enumerated()), id: \.element.id) { index, insight in
                        HStack(alignment: .top, spacing: 12) {
                            TijingStickerIcon(systemImage: insightIcon(index), tint: insightTint(index), background: insightBackground(index), size: 40, rotation: index.isMultiple(of: 2) ? -5 : 5, sparkle: false)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(insight.title).font(.subheadline.weight(.semibold))
                                Text(insight.detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(14)
                        .tijingCard()
                    }
                }
            }
        }
    }

    private func subjectSection(_ data: LearningDiagnostics) -> some View {
        let items = data.subjects.filter { $0.total > 0 }
        return VStack(spacing: 12) {
            TijingSectionHeading("模块画像", subtitle: "点进模块可直接开始专项练习")
            if items.isEmpty {
                TijingPaperCard(tint: TijingDesign.sky) {
                    HStack(spacing: 12) {
                        TijingStickerIcon(systemImage: "chart.bar.doc.horizontal", tint: TijingDesign.cyan, background: TijingDesign.sky, size: 44)
                        Text("完成更多练习后，这里会根据真实答题数据生成模块画像。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    NavigationLink {
                        DirectPracticeLauncherView(mode: .random, subject: item.subject ?? item.name, topic: nil)
                    } label: {
                        subjectCard(item, baseline: data.analysis.baselineAccuracy, tint: subjectTint(index))
                    }
                    .buttonStyle(TijingPressableCardStyle())
                    .tijingTactileLink()
                }
            }
        }
    }

    private func subjectCard(_ item: LearningProfileItem, baseline: Int, tint: Color) -> some View {
        TijingPaperCard(tint: tint) {
            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 12) {
                    TijingStickerIcon(systemImage: subjectIcon(item.subject ?? item.name), tint: TijingDesign.ink.opacity(0.72), background: tint, size: 42, rotation: -4, sparkle: false)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.subject ?? item.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("\(item.total) 题 · 最近正确率 \(item.recentAccuracy)%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Text("\(item.mastery)%")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                }

                ProgressView(value: Double(item.mastery), total: 100)
                    .tint(TijingDesign.ink.opacity(0.64))

                HStack(spacing: 7) {
                    if let status = item.status, !status.isEmpty {
                        TijingMicroBadge(title: status, systemImage: "circle.fill", tint: TijingDesign.indigo)
                    }
                    TijingMicroBadge(title: performanceText(item, baseline: baseline), systemImage: performanceIcon(item, baseline: baseline), tint: TijingDesign.mint)
                    TijingMicroBadge(title: paceText(item.paceDeltaPct), systemImage: "timer", tint: TijingDesign.amber)
                }
            }
        }
    }

    private func subjectTint(_ index: Int) -> Color {
        [TijingDesign.sky, TijingDesign.sage, TijingDesign.butter, TijingDesign.lilac, TijingDesign.peach, TijingDesign.rose][index % 6]
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

    private func trendIcon(_ value: Int) -> String { value >= 0 ? "arrow.up.right" : "arrow.down.right" }
    private func trendTint(_ value: Int) -> Color { value >= 0 ? TijingDesign.mint : TijingDesign.coral }
    private func insightIcon(_ index: Int) -> String { ["lightbulb.fill", "bolt.fill", "sparkles"][index % 3] }
    private func insightTint(_ index: Int) -> Color { [TijingDesign.amber, TijingDesign.cyan, TijingDesign.violet][index % 3] }
    private func insightBackground(_ index: Int) -> Color { [TijingDesign.butter, TijingDesign.sky, TijingDesign.lilac][index % 3] }

    private func seconds(_ ms: Int) -> String {
        guard ms > 0 else { return "--" }
        return "\(max(1, Int((Double(ms) / 1000).rounded())))秒"
    }

    private func nextAction(_ data: LearningDiagnostics) -> String {
        let due = review?.due ?? 0
        if due > 0 { return "先完成 \(due) 道到期复习，再针对当前优先项做一组专项。" }
        if data.analysis.summary.focus != nil { return "针对当前优先项完成一组专项，再观察近期表现是否回升。" }
        return "保持当前练习节奏，系统会继续根据后续数据调整建议。"
    }

    private func performanceText(_ item: LearningProfileItem, baseline: Int) -> String {
        let gap = item.analyzedAccuracy - baseline
        if gap <= -4 { return "低于平均" }
        if gap >= 4 { return "高于平均" }
        return "接近平均"
    }

    private func performanceIcon(_ item: LearningProfileItem, baseline: Int) -> String {
        let gap = item.analyzedAccuracy - baseline
        if gap <= -4 { return "arrow.down.right" }
        if gap >= 4 { return "arrow.up.right" }
        return "minus"
    }

    private func paceText(_ value: Int) -> String {
        if value >= 12 { return "偏慢" }
        if value <= -12 { return "较快" }
        return "节奏正常"
    }

    @MainActor
    private func load() async {
        guard let token = session.token else { return }
        if diagnostics == nil { diagnostics = session.homeDiagnostics }
        if review == nil { review = session.homeSmartReview }
        let diagnosticsKey = session.userCacheKey("home.diagnostics")
        let reviewKey = session.userCacheKey("home.review")
        if diagnostics == nil { diagnostics = session.api.cachedResponse(for: diagnosticsKey) }
        if review == nil { review = session.api.cachedResponse(for: reviewKey) }

        loading = diagnostics == nil
        defer { loading = false }
        do {
            async let diagnosticsTask: LearningDiagnostics = session.api.requestCached(
                "/api/learning/diagnostics", token: token, cacheKey: diagnosticsKey
            )
            async let reviewTask: SmartReviewSummary = session.api.requestCached(
                "/api/learning/smart-review", token: token, cacheKey: reviewKey
            )
            let freshDiagnostics = try await diagnosticsTask
            diagnostics = freshDiagnostics
            session.homeDiagnostics = freshDiagnostics
            if let freshReview = try? await reviewTask {
                review = freshReview
                session.homeSmartReview = freshReview
            }
            error = nil
        } catch {
            self.error = diagnostics == nil ? error.localizedDescription : nil
        }
    }
}
