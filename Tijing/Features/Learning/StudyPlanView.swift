import SwiftUI

struct StudyPlanView: View {
    @Environment(SessionStore.self) private var session
    @State private var weeksAgo = 0
    @State private var report: LearningWeekReport?
    @State private var loading = false
    @State private var error: String?
    @State private var editing: PlanEditorItem?
    @State private var loadID = UUID()

    var body: some View {
        ZStack {
            TijingPageBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    periodPicker
                    if loading { ProgressView("正在同步学习数据") }
                    if let error {
                        Text(error).font(.footnote).foregroundStyle(.red)
                        Button("重新加载") { Task { await load() } }
                    }
                    if let report {
                        reportCard(report)
                        todayCard(report)
                        historyCard(report)
                        forecastCard(report)
                        weakTopicsCard(report)
                        Text("与网页版共用数据，按北京时间统计连续七天（不是自然周）。题量为作答次数，同题重练会再次计入；只统计已提交练习，不包含对战。有效时间不含单题超过五分钟的记录。补交按服务器接收日期计入。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    NavigationLink { PracticeDeliveryView() } label: {
                        Label("补交中心 · \(session.submissions.pending.count) 条待确认", systemImage: "arrow.triangle.2.circlepath")
                    }
                    TijingTabBarContentFooter()
                }
                .padding(.horizontal, TijingDesign.pageHorizontalPadding).padding(.vertical, 12)
            }
            .refreshable { await load() }
        }
        .navigationTitle("学习周报 · 目标计划")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: "\(session.user?.id ?? 0)-\(weeksAgo)") { await load() }
        .sheet(item: $editing) { item in
            NavigationStack { StudyPlanEditor(plan: item.plan, onSaved: { await load() }) }
        }
    }

    private var periodPicker: some View {
        HStack {
            Button { weeksAgo += 1 } label: { Image(systemName: "chevron.left").padding(8) }
                .disabled(weeksAgo >= 52 || loading).accessibilityLabel("更早七天")
            Spacer()
            Text(weeksAgo == 0 ? "最近七天" : "往前第 \(weeksAgo) 个七天").font(.headline)
            Spacer()
            Button { weeksAgo -= 1 } label: { Image(systemName: "chevron.right").padding(8) }
                .disabled(weeksAgo == 0 || loading).accessibilityLabel("较近七天")
        }
    }

    private func reportCard(_ data: LearningWeekReport) -> some View {
        TijingPaperCard(tint: TijingDesign.sky) {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(data.start_date) — \(data.end_date)").font(.subheadline).foregroundStyle(.secondary)
                Text("\(data.total) 次作答 · \(data.accuracy, specifier: "%.1f")% 正确率").font(.title3.bold())
                Text("活跃 \(data.active_days) 天 · 有效答题 \(data.study_minutes, specifier: "%.1f") 分钟")
                if let change = data.accuracy_change {
                    Text("较前七天变化 \(change > 0 ? "+" : "")\(change, specifier: "%.1f") 个百分点").font(.footnote)
                } else { Text("样本不足，暂不比较正确率变化").font(.footnote).foregroundStyle(.secondary) }
                if data.total == 0 { Text("这七天还没有已提交的练习记录。完成一组练习后再来看看。") }
            }
        }
    }

    private func todayCard(_ data: LearningWeekReport) -> some View {
        TijingPaperCard(tint: TijingDesign.sage) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("今天的计划").font(.headline)
                    Spacer()
                    Button("编辑") { editing = PlanEditorItem(plan: data.plan) }
                }
                Text(data.plan.target_name).font(.title3.bold())
                Text("每日 \(data.plan.daily_questions) 次 / \(data.plan.daily_minutes) 分钟 · 今天已完成 \(data.today_plan.completed) 次")
                ProgressView(value: Double(min(data.today_plan.completed, data.plan.daily_questions)), total: Double(data.plan.daily_questions))
                if let date = data.plan.target_date { Text("目标日期：\(date)").font(.subheadline) }
                Text(data.plan.review_algorithm == "fsrs" ? "FSRS 个性化调度 · 目标保持率 \(Int((data.plan.desired_retention * 100).rounded()))%" : "当前使用原有复习算法，可在编辑计划中启用 FSRS")
                    .font(.footnote).foregroundStyle(.secondary)
                Text("建议复习 \(data.today_plan.review) 道 + 新题 \(data.today_plan.new) 道，约 \(data.today_plan.estimated_minutes) 分钟")
                if data.today_plan.overdue_remaining > 0 {
                    Text("今日预算外还有 \(data.today_plan.overdue_remaining) 道到期题，可分天消化。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if data.today_plan.total == 0 { Text("今日题量或时间预算已完成，可以休息了。") }
                if data.today_plan.review > 0 { practiceLink("开始到期复习", mode: .smartReview, count: data.today_plan.review) }
                if data.today_plan.new > 0 { practiceLink("开始新题练习", mode: .random, count: data.today_plan.new) }
                Text("计划和预估始终是今天的，即使正在查看历史七天。FSRS 在实际复习后更新每题记忆状态；保持率不是正确率保证。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func historyCard(_ data: LearningWeekReport) -> some View {
        TijingPaperCard(tint: TijingDesign.butter) {
            VStack(alignment: .leading, spacing: 12) {
                Text("每日分布").font(.headline)
                ForEach(data.days) { day in
                    HStack {
                        Text(String(day.date.suffix(5)))
                        ProgressView(value: Double(day.total), total: Double(max(1, data.days.map(\.total).max() ?? 1)))
                        Text("\(day.total) 次 / 对 \(day.correct)").font(.caption).monospacedDigit()
                    }
                }
            }
        }
    }

    private func forecastCard(_ data: LearningWeekReport) -> some View {
        TijingPaperCard(tint: TijingDesign.sky) {
            VStack(alignment: .leading, spacing: 10) {
                Text("未来七天已排定复习").font(.headline)
                ForEach(data.review_forecast) { item in
                    HStack { Text(item.date); Spacer(); Text("\(item.due) 道").monospacedDigit() }
                }
                Text("今天包含积压到期题；新作答可能改变后续安排。").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func weakTopicsCard(_ data: LearningWeekReport) -> some View {
        TijingPaperCard(tint: TijingDesign.peach) {
            VStack(alignment: .leading, spacing: 12) {
                Text("本期薄弱章节").font(.headline)
                if data.weak_topics.isEmpty { Text("暂无数据").foregroundStyle(.secondary) }
                ForEach(data.weak_topics) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text([item.subject, item.topic].filter { !$0.isEmpty }.joined(separator: " · "))
                        Text("\(item.total) 次作答 · 正确率 \(item.accuracy, specifier: "%.1f")%").font(.caption).foregroundStyle(.secondary)
                        practiceLink("针对练习", mode: .random, count: 10, subject: item.subject, topic: item.topic)
                    }
                }
            }
        }
    }

    private func practiceLink(_ title: String, mode: PracticeMode, count: Int, subject: String? = nil, topic: String? = nil) -> some View {
        NavigationLink {
            if let token = session.token, let userID = session.user?.id {
                PracticeSessionView(store: PracticeSessionStore(mode: mode, subject: subject, topic: topic,
                    settings: PracticeSettings(questionCount: min(40, max(1, count))), token: token, userID: userID))
            }
        } label: { Label(title, systemImage: "play.circle.fill") }
    }

    @MainActor private func load() async {
        let id = UUID(); loadID = id
        guard let token = session.token, let owner = session.user?.id else { report = nil; return }
        let period = weeksAgo
        loading = true; error = nil; report = nil
        defer { if loadID == id { loading = false } }
        do {
            let value: LearningWeekReport = try await session.api.request("/api/learning/weekly-report", token: token,
                query: [URLQueryItem(name: "weeks_ago", value: String(period))])
            guard !Task.isCancelled, loadID == id, session.token == token, session.user?.id == owner else { return }
            report = value
        } catch {
            guard !Task.isCancelled, loadID == id, session.token == token else { return }
            self.error = (error as? APIError)?.statusCode == 404 ? "服务器尚未安装学习升级，请先更新网页版后端。" : error.localizedDescription
        }
    }
}

private struct PlanEditorItem: Identifiable { let id = UUID(); let plan: StudyPlan }

struct StudyPlanEditor: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State var plan: StudyPlan
    var onSaved: () async -> Void
    @State private var saving = false
    @State private var error: String?
    @State private var ownerID: Int?

    var body: some View {
        Form {
            Section("目标") {
                TextField("计划名称", text: $plan.target_name)
                Toggle("设置目标日期", isOn: Binding(get: { plan.target_date != nil }, set: { plan.target_date = $0 ? StudyDate.string(Date()) : nil }))
                if plan.target_date != nil {
                    DatePicker("目标日期", selection: Binding(get: { StudyDate.date(plan.target_date) ?? Date() }, set: { plan.target_date = StudyDate.string($0) }), displayedComponents: .date)
                        .environment(\.timeZone, TimeZone(secondsFromGMT: 8 * 3600)!)
                }
                Stepper("每日 \(plan.daily_minutes) 分钟", value: $plan.daily_minutes, in: 5...240, step: 5)
                Stepper("每日 \(plan.daily_questions) 次作答", value: $plan.daily_questions, in: 5...300, step: 5)
            }
            Section {
                Picker("复习算法", selection: $plan.review_algorithm) {
                    Text("原有自适应算法").tag("ebbinghaus_adaptive")
                    Text("FSRS 个性化记忆").tag("fsrs")
                }
                Text("目标保持率 \(Int((plan.desired_retention * 100).rounded()))%")
                Slider(value: $plan.desired_retention, in: 0.8...0.97, step: 0.01)
                    .accessibilityLabel("目标保持率")
                    .disabled(plan.review_algorithm != "fsrs")
            } footer: {
                Text("与网页版共用设置。提高保持率通常会增加复习量；这不是正确率承诺。保存后启用，已有 FSRS 题目的日期会按新保持率重新安排。")
            }
            if let error { Section { Text(error).foregroundStyle(.red) } }
        }
        .disabled(saving)
        .navigationTitle("编辑学习计划").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() }.disabled(saving) }
            ToolbarItem(placement: .confirmationAction) {
                Button(saving ? "保存中…" : "保存") { Task { await save() } }.disabled(!plan.isValid || saving)
            }
        }
        .interactiveDismissDisabled(saving)
        .onAppear { ownerID = session.user?.id }
        .onChange(of: session.user?.id) { _, _ in dismiss() }
    }

    @MainActor private func save() async {
        guard !saving, plan.isValid, ownerID == session.user?.id, let token = session.token else { return }
        saving = true; error = nil
        defer { saving = false }
        do {
            var body = plan; body.target_name = body.target_name.trimmingCharacters(in: .whitespacesAndNewlines)
            let _: StudyPlan = try await session.api.request("/api/learning/plan", method: .put, body: body, token: token)
            guard session.token == token, ownerID == session.user?.id else { return }
            await onSaved(); dismiss()
        } catch { if session.token == token { self.error = error.localizedDescription } }
    }
}
