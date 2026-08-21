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
        Group {
            if session.token == nil {
                ContentUnavailableView("需要登录", systemImage: "person.crop.circle.badge.exclamationmark", description: Text("专注刷题会同步你的学习记录。"))
            } else if loading && catalog.isEmpty {
                ProgressView("正在读取题库")
            } else {
                List {
                    Section {
                        Picker("练习类型", selection: $mode) {
                            Text("专注刷题").tag(PracticeMode.random)
                            Text("错题").tag(PracticeMode.wrong)
                            Text("收藏").tag(PracticeMode.favorite)
                            Text("智能复习").tag(PracticeMode.smartReview)
                            Text("模拟考试").tag(PracticeMode.exam)
                        }
                        .pickerStyle(.menu)
                    }

                    if mode == .wrong || mode == .favorite || mode == .smartReview {
                        Section {
                            sessionLink(subject: nil, topic: nil) {
                                Label("开始\(mode.title)", systemImage: "play.fill")
                                    .font(.headline)
                            }
                        } footer: {
                            Text("错题、收藏与智能复习不应用难度筛选；其中错题和收藏沿用当前每组题量与答题方式。")
                        }
                    }

                    Section("题库") {
                        ForEach(catalog) { subject in
                            DisclosureGroup {
                                sessionLink(subject: subject.name, topic: nil) {
                                    HStack {
                                        Text("全部 \(subject.name)")
                                        Spacer()
                                        Text("\(subject.count)题").foregroundStyle(.secondary)
                                    }
                                }
                                ForEach(subject.topics.filter { $0.count > 0 }) { topic in
                                    sessionLink(subject: subject.name, topic: topic.topic) {
                                        VStack(alignment: .leading, spacing: 5) {
                                            HStack {
                                                Text(topic.topic)
                                                Spacer()
                                                Text("\(topic.count)题").foregroundStyle(.secondary)
                                            }
                                            if let progress = topic.progress {
                                                ProgressView(value: Double(progress), total: 100)
                                                    .accessibilityLabel("完成进度 \(progress)%")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(subject.name).font(.headline)
                                    Spacer()
                                    Text("\(subject.count)题").font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    if let error { Section { Text(error).foregroundStyle(.red) } }
                }
                .refreshable { await loadCatalog() }
            }
        }
        .navigationTitle(mode.title)
        .toolbar {
            if mode == .random {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { settingsOpen = true; Haptics.selection() } label: { Image(systemName: "slider.horizontal.3") }
                        .accessibilityLabel("练习设置")
                }
            }
        }
        .sheet(isPresented: $settingsOpen) {
            NavigationStack { PracticeSettingsView(settings: $settings, onSave: saveSettings) }
                .presentationDetents([.medium, .large])
        }
        .task { await loadAll() }
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
        loading = true; defer { loading = false }
        do {
            let response: PracticeCatalogResponse = try await session.api.request("/api/practice/catalog", token: token)
            catalog = response.subjects
            error = nil
        } catch { self.error = error.localizedDescription }
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
        var normalized = newValue; normalized.normalize(); settings = normalized
        do {
            let response: PracticeSettings = try await session.api.request("/api/practice/settings", method: .post, body: normalized, token: token)
            var value = response; value.normalize(); settings = value
            Haptics.success()
        } catch { self.error = error.localizedDescription; Haptics.error() }
    }
}
