import SwiftUI
import SafariServices

struct ExamCalendarView: View {
    @Environment(SessionStore.self) private var session
    @State private var response: ExamCalendarResponse?
    @State private var city = "全部"
    @State private var followedOnly = false
    @State private var loading = false
    @State private var error: String?
    @State private var browserTarget: ExamBrowserTarget?

    var body: some View {
        ZStack {
            TijingPageBackground()
            ScrollView {
                LazyVStack(spacing: 16) {
                    TijingFieldSurface("筛选") {
                        Picker("地区", selection: $city) {
                            Text("全部").tag("全部")
                            ForEach(response?.cities ?? []) { Text("\($0.name)（\($0.count)）").tag($0.name) }
                        }
                        Divider()
                        Toggle("只看我的关注", isOn: $followedOnly)
                    }

                    if let items = response?.items, !items.isEmpty {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, exam in
                            examCard(exam, index: index)
                        }
                    } else if !loading {
                        TijingPaperCard(tint: TijingDesign.sky) {
                            HStack(spacing: 12) {
                                TijingStickerIcon(systemImage: "calendar", tint: TijingDesign.cyan, background: TijingDesign.sky, size: 42, sparkle: false)
                                Text(error ?? "当前筛选范围暂无考试信息")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
                .padding(.horizontal, TijingDesign.pageHorizontalPadding)
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
            if loading && response == nil { ProgressView("正在同步日历") }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: city + String(followedOnly)) { await load() }
        .refreshable { await load() }
        .sensoryFeedback(.selection, trigger: city)
        .sensoryFeedback(.selection, trigger: followedOnly)
        .sheet(item: $browserTarget) { target in
            ExamInAppBrowser(url: target.url)
                .ignoresSafeArea()
        }
    }

    private func examCard(_ exam: RecruitmentExam, index: Int) -> some View {
        let tint = [TijingDesign.sky, TijingDesign.sage, TijingDesign.lilac, TijingDesign.peach][index % 4]
        return TijingPaperCard(tint: tint) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    TijingStickerIcon(systemImage: "calendar", tint: TijingDesign.ink.opacity(0.70), background: tint, size: 40, rotation: index.isMultiple(of: 2) ? -5 : 5, sparkle: false)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exam.title).font(.headline)
                        Text([exam.city, exam.examKind].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Button {
                        Haptics.selection()
                        toggleFollow(exam)
                    } label: {
                        Image(systemName: exam.followed == true ? "star.fill" : "star")
                            .font(.title3)
                            .foregroundStyle(exam.followed == true ? TijingDesign.amber : .secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(exam.followed == true ? "取消关注\(exam.title)" : "关注\(exam.title)")
                }

                if let next = exam.nextLabel {
                    HStack(spacing: 8) {
                        TijingMicroBadge(title: next, systemImage: "calendar.badge.clock", tint: TijingDesign.indigo)
                        Spacer()
                        if let days = exam.daysToNext {
                            Text(days == 0 ? "今天" : "还有 \(days) 天")
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                        }
                    }
                }

                if let excerpt = exam.sourceExcerpt, !excerpt.isEmpty {
                    Text(excerpt)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                if let source = exam.sourceURL, let url = URL(string: source) {
                    Button {
                        Haptics.light()
                        browserTarget = ExamBrowserTarget(url: url)
                    } label: {
                        Label("查看官方来源", systemImage: "safari")
                            .font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @MainActor private func load() async {
        let path = session.token == nil ? "/api/exams/calendar" : "/api/exams/calendar/me"
        var query: [URLQueryItem] = []
        if city != "全部" { query.append(URLQueryItem(name: "city", value: city)) }
        if session.token != nil { query.append(URLQueryItem(name: "followed_only", value: String(followedOnly))) }
        let owner = session.user?.id.map(String.init) ?? "public"
        let cacheKey = "calendar.\(owner).\(city).\(followedOnly)"

        if response == nil { response = session.api.cachedResponse(for: cacheKey) }
        loading = response == nil
        defer { loading = false }
        do {
            response = try await session.api.requestCached(
                path, token: session.token, query: query, cacheKey: cacheKey
            )
            error = nil
        } catch {
            self.error = response == nil ? error.localizedDescription : nil
        }
    }

    private func toggleFollow(_ exam: RecruitmentExam) {
        guard let token = session.token else { error = "登录后才能关注考试"; return }
        Task { @MainActor in
            do {
                let method: HTTPMethod = exam.followed == true ? .delete : .post
                let _: FollowResponse = try await session.api.request("/api/exams/calendar/\(exam.id)/follow", method: method, body: EmptyBody(), token: token)
                Haptics.success(); await load()
            } catch { self.error = error.localizedDescription; Haptics.error() }
        }
    }
}

private struct FollowResponse: Decodable { let followed: Bool?; let examID: Int?; enum CodingKeys: String, CodingKey { case followed; case examID = "exam_id" } }
private struct ExamBrowserTarget: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

private struct ExamInAppBrowser: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredControlTintColor = .systemIndigo
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

