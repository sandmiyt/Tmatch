import SwiftUI

struct ExamCalendarView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.openURL) private var openURL
    @State private var response: ExamCalendarResponse?
    @State private var city = "全部"
    @State private var followedOnly = false
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        List {
            Section {
                Picker("地区", selection: $city) {
                    Text("全部").tag("全部")
                    ForEach(response?.cities ?? []) { Text("\($0.name)（\($0.count)）").tag($0.name) }
                }
                Toggle("只看我的关注", isOn: $followedOnly)
            }

            if let items = response?.items, !items.isEmpty {
                ForEach(items) { exam in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(exam.title).font(.headline)
                                Text([exam.city, exam.examKind].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                toggleFollow(exam)
                            } label: {
                                Image(systemName: exam.followed == true ? "star.fill" : "star")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(exam.followed == true ? "取消关注\(exam.title)" : "关注\(exam.title)")
                        }
                        if let next = exam.nextLabel {
                            HStack {
                                Label(next, systemImage: "calendar.badge.clock")
                                Spacer()
                                if let days = exam.daysToNext { Text(days == 0 ? "今天" : "还有 \(days) 天").bold() }
                            }
                            .font(.subheadline)
                        }
                        if let excerpt = exam.sourceExcerpt, !excerpt.isEmpty {
                            Text(excerpt).font(.footnote).foregroundStyle(.secondary).lineLimit(3)
                        }
                        if let source = exam.sourceURL, let url = URL(string: source) {
                            Button("查看官方来源") { openURL(url) }.font(.footnote)
                        }
                    }
                    .padding(.vertical, 5)
                }
            } else if !loading {
                Section { Text(error ?? "当前筛选范围暂无考试信息").foregroundStyle(.secondary) }
            }
        }
        .navigationTitle("考试日历")
        .overlay { if loading && response == nil { ProgressView("正在同步日历") } }
        .task(id: city + String(followedOnly)) { await load() }
        .refreshable { await load() }
        .sensoryFeedback(.selection, trigger: city)
        .sensoryFeedback(.selection, trigger: followedOnly)
    }

    @MainActor private func load() async {
        loading = true; defer { loading = false }
        do {
            let path = session.token == nil ? "/api/exams/calendar" : "/api/exams/calendar/me"
            var query: [URLQueryItem] = []
            if city != "全部" { query.append(URLQueryItem(name: "city", value: city)) }
            if session.token != nil { query.append(URLQueryItem(name: "followed_only", value: String(followedOnly))) }
            response = try await session.api.request(path, token: session.token, query: query)
            error = nil
        } catch { self.error = error.localizedDescription }
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
