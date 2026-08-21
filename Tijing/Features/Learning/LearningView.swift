import SwiftUI

struct LearningView: View {
    @Environment(SessionStore.self) private var session
    @State private var diagnostics: LearningDiagnostics?
    @State private var review: SmartReviewSummary?
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        Group {
            if loading && diagnostics == nil {
                ProgressView("正在分析学习数据…")
            } else if let diagnostics {
                nativeDiagnosticList(diagnostics)
            } else {
                ContentUnavailableView {
                    Label("暂时无法生成学习诊断", systemImage: "brain.head.profile")
                } description: {
                    Text(error ?? "完成更多练习后，系统会根据真实作答记录生成诊断。")
                } actions: {
                    Button("重新加载") {
                        Task { await load() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("学习诊断")
        .navigationBarTitleDisplayMode(.large)
        .refreshable { await load() }
        .task { await load() }
    }

    private func nativeDiagnosticList(_ data: LearningDiagnostics) -> some View {
        List {
            Section("学习概览") {
                LabeledContent {
                    Text("\(data.overview.sevenDayAccuracy)%")
                        .fontWeight(.semibold)
                        .monospacedDigit()
                } label: {
                    Label("7 天正确率", systemImage: "calendar")
                }

                LabeledContent {
                    Text("\(data.overview.recent100Accuracy)%")
                        .fontWeight(.semibold)
                        .monospacedDigit()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("近期正确率", systemImage: "chart.line.uptrend.xyaxis")
                        Text(trendText(data.overview))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                LabeledContent {
                    Text(seconds(data.overview.averageElapsedMS))
                        .fontWeight(.semibold)
                        .monospacedDigit()
                } label: {
                    Label("平均答题时间", systemImage: "timer")
                }

                LabeledContent {
                    Text("\(data.analysis.historyTotal)")
                        .fontWeight(.semibold)
                        .monospacedDigit()
                } label: {
                    Label("累计做题", systemImage: "checklist")
                }
            }

            Section("智能分析") {
                VStack(alignment: .leading, spacing: 5) {
                    Label("当前状态", systemImage: "waveform.path.ecg")
                        .font(.subheadline.weight(.semibold))
                    Text(data.analysis.summary.title)
                        .font(.headline)
                    Text(data.analysis.summary.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 3)

                let focus = data.analysis.summary.focus
                VStack(alignment: .leading, spacing: 6) {
                    Label("优先巩固", systemImage: "target")
                        .font(.subheadline.weight(.semibold))
                    Text(focus?.title ?? "暂未发现明显需要优先处理的薄弱项")
                        .font(.headline)
                    Text(focus?.detail ?? "继续练习后，系统会根据新的答题数据动态更新判断。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let signals = focus?.signals, !signals.isEmpty {
                        Text(signals.prefix(3).joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 3)

                VStack(alignment: .leading, spacing: 5) {
                    Label("下一步", systemImage: "arrow.forward.circle")
                        .font(.subheadline.weight(.semibold))
                    Text(nextAction(data))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 3)
            }

            Section("开始训练") {
                NavigationLink {
                    PracticeCatalogView(initialMode: .smartReview)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("今日待复习", systemImage: "clock.arrow.circlepath")
                        Text("\(review?.due ?? 0) 题到期 · \(review?.mastered ?? 0) 题已掌握")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let focus = data.analysis.summary.focus {
                    NavigationLink {
                        FocusedPracticeLauncher(subject: focus.subject, topic: focus.topic)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Label("针对薄弱项练一组", systemImage: "scope")
                            Text(focus.topic ?? focus.subject ?? "专项练习")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                NavigationLink {
                    PracticeCatalogView(initialMode: .wrong)
                } label: {
                    Label("错题重练", systemImage: "arrow.counterclockwise.circle")
                }

                NavigationLink {
                    PracticeCatalogView(initialMode: .favorite)
                } label: {
                    Label("收藏练习", systemImage: "star")
                }
            }

            Section("模块画像") {
                let items = data.subjects.filter { $0.total > 0 }
                if items.isEmpty {
                    Text("完成更多练习后，这里会根据你的真实答题数据生成模块画像。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(items) { item in
                        NavigationLink {
                            FocusedPracticeLauncher(subject: item.subject ?? item.name, topic: nil)
                        } label: {
                            VStack(alignment: .leading, spacing: 7) {
                                HStack {
                                    Text(item.subject ?? item.name)
                                        .font(.headline)
                                    Spacer()
                                    Text("\(item.mastery)%")
                                        .font(.subheadline.weight(.semibold).monospacedDigit())
                                }
                                ProgressView(value: Double(item.mastery), total: 100)
                                HStack(spacing: 8) {
                                    if let status = item.status, !status.isEmpty {
                                        Text(status)
                                    }
                                    Text(performanceText(item, baseline: data.analysis.baselineAccuracy))
                                    Text(paceText(item.paceDeltaPct))
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }
            }

            if let error {
                Section {
                    Label(error, systemImage: "wifi.exclamationmark")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func trendText(_ overview: LearningOverview) -> String {
        let prefix = overview.recent100Trend > 0 ? "+" : ""
        return "\(prefix)\(overview.recent100Trend)% · 最近\(overview.recent100Total)题"
    }

    private func seconds(_ ms: Int) -> String {
        guard ms > 0 else { return "--" }
        return "\(max(1, Int((Double(ms) / 1000).rounded())))秒"
    }

    private func nextAction(_ data: LearningDiagnostics) -> String {
        let due = review?.due ?? 0
        if due > 0 {
            return "先完成 \(due) 道到期复习，再针对当前优先项做一组专项。"
        }
        if data.analysis.summary.focus != nil {
            return "针对当前优先项完成一组专项练习，之后再观察近期表现是否回升。"
        }
        return "保持当前练习节奏，系统会继续根据后续数据调整建议。"
    }

    private func performanceText(_ item: LearningProfileItem, baseline: Int) -> String {
        let gap = item.analyzedAccuracy - baseline
        if gap <= -4 { return "低于平均水平" }
        if gap >= 4 { return "高于平均水平" }
        return "接近平均水平"
    }

    private func paceText(_ value: Int) -> String {
        if value >= 12 { return "偏慢" }
        if value <= -12 { return "较快" }
        return "正常"
    }

    @MainActor
    private func load() async {
        guard let token = session.token else { return }
        loading = true
        defer { loading = false }
        do {
            async let diagnosticsTask: LearningDiagnostics = session.api.request("/api/learning/diagnostics", token: token)
            async let reviewTask: SmartReviewSummary = session.api.request("/api/learning/smart-review", token: token)
            diagnostics = try await diagnosticsTask
            review = try? await reviewTask
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct FocusedPracticeLauncher: View {
    @Environment(SessionStore.self) private var session
    let subject: String?
    let topic: String?
    @State private var store: PracticeSessionStore?
    @State private var error: String?

    var body: some View {
        Group {
            if let store {
                PracticeSessionView(store: store)
            } else if let error {
                ContentUnavailableView("无法开始专项练习", systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                ProgressView("正在读取练习设置…")
            }
        }
        .navigationTitle(topic ?? subject ?? "专项练习")
        .task { await prepare() }
    }

    @MainActor private func prepare() async {
        guard store == nil, let token = session.token, let userID = session.user?.id else {
            if session.token == nil { error = "请先登录" }
            return
        }
        do {
            var settings: PracticeSettings = try await session.api.request("/api/practice/settings", token: token)
            settings.normalize()
            store = PracticeSessionStore(mode: .random, subject: subject, topic: topic, settings: settings, token: token, userID: userID)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
