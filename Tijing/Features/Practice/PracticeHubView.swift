import SwiftUI

struct PracticeHubView: View {
    @Environment(SessionStore.self) private var session
    @State private var catalog: [PracticeSubject] = []
    @State private var settings = PracticeSettings()
    @State private var loading = false
    @State private var error: String?
    @State private var settingsOpen = false

    var body: some View {
        ZStack {
            TijingPageBackground()

            if session.token == nil {
                ContentUnavailableView(
                    "需要登录",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: Text("刷题会同步你的进度、错题和收藏。")
                )
            } else if loading && catalog.isEmpty {
                ProgressView("正在读取题库")
            } else {
                ScrollView {
                    LazyVStack(spacing: 18) {
                        header
                            .tijingReveal(order: 0)

                        ForEach(Array(catalog.enumerated()), id: \.element.id) { offset, subject in
                            subjectCard(subject)
                                .tijingReveal(order: min(offset + 1, 8))
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
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                }
                .refreshable { await loadCatalog() }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $settingsOpen) {
            NavigationStack {
                PracticeSettingsView(settings: $settings, onSave: saveSettings)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .task { await loadAll() }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Text("刷题")
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                Text("按自己的节奏练习")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button {
                Haptics.selection()
                settingsOpen = true
            } label: {
                Label("练习设置", systemImage: "slider.horizontal.3")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(TijingPressableCardStyle())
            .accessibilityLabel("练习设置")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                TijingStickerIcon(
                    systemImage: subjectIcon(subject.name),
                    tint: subjectTint(subject.name),
                    background: subjectTint(subject.name).opacity(0.14),
                    size: 40,
                    rotation: -4,
                    sparkle: false
                )

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
                PracticeSessionView(
                    store: PracticeSessionStore(
                        mode: .random,
                        subject: subject,
                        topic: topic,
                        settings: settings,
                        token: token,
                        userID: userID
                    )
                )
            } else {
                ContentUnavailableView("需要登录", systemImage: "person.crop.circle")
            }
        } label: {
            label()
        }
    }

    @MainActor private func loadAll() async {
        await loadSettings()
        await loadCatalog()
    }

    @MainActor private func loadCatalog() async {
        guard let token = session.token else { return }
        let cacheKey = session.userCacheKey("practice.catalog")
        if catalog.isEmpty, let cached: PracticeCatalogResponse = session.api.cachedResponse(for: cacheKey) {
            catalog = cached.subjects
        }
        loading = catalog.isEmpty
        defer { loading = false }
        do {
            let response: PracticeCatalogResponse = try await session.api.requestCached(
                "/api/practice/catalog", token: token, cacheKey: cacheKey
            )
            catalog = response.subjects
            error = nil
        } catch {
            self.error = catalog.isEmpty ? error.localizedDescription : nil
        }
    }

    @MainActor private func loadSettings() async {
        guard let token = session.token else { return }
        let cacheKey = session.userCacheKey("practice.settings")
        if let cached: PracticeSettings = session.api.cachedResponse(for: cacheKey) {
            var value = cached
            value.normalize()
            settings = value
        }
        if let saved: PracticeSettings = try? await session.api.requestCached(
            "/api/practice/settings", token: token, cacheKey: cacheKey
        ) {
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
            let response: PracticeSettings = try await session.api.request(
                "/api/practice/settings",
                method: .post,
                body: normalized,
                token: token
            )
            var value = response
            value.normalize()
            settings = value
            session.api.storeCachedResponse(value, for: session.userCacheKey("practice.settings"))
            Haptics.success()
        } catch {
            self.error = error.localizedDescription
            Haptics.error()
        }
    }
}
