import SwiftUI

struct RankingView: View {
    @Environment(SessionStore.self) private var session
    @State private var items: [User] = []
    @State private var seasonInfo: SeasonPublicInfo?
    @State private var seasonMe: SeasonMeResponse?
    @State private var loading = true
    @State private var error: String?
    @State private var seasonPanel: SeasonPanel?

    var body: some View {
        Group {
            if loading && items.isEmpty {
                ProgressView("正在加载排行榜")
            } else if items.isEmpty {
                ContentUnavailableView("暂无排行数据", systemImage: "trophy", description: Text(error ?? "稍后再试"))
            } else {
                List {
                    if let season = seasonInfo ?? seasonMe?.season {
                        Section {
                            seasonBanner(season)
                                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                            if let current = seasonMe?.current {
                                mySeasonCard(current)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 10, trailing: 16))
                            } else if session.token != nil {
                                HStack { ProgressView(); Text("正在同步我的赛季…").foregroundStyle(.secondary) }
                            }
                        }
                    }

                    Section("本赛季排行") {
                        ForEach(items) { user in
                            if session.token != nil {
                                NavigationLink {
                                    PublicProfileView(userID: user.id)
                                } label: {
                                    rankingRow(user)
                                }
                            } else {
                                rankingRow(user)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable { await load() }
            }
        }
        .navigationTitle("排行榜")
        .task { await load() }
        .onChange(of: session.rankingRevision) { _, _ in
            Task { await load() }
        }
        .sheet(item: $seasonPanel) { panel in
            switch panel {
            case .achievements:
                SeasonAchievementsView(current: seasonMe?.current)
            case .previous:
                if let previous = seasonMe?.previous { PreviousSeasonReportView(result: previous) }
            }
        }
    }

    private func seasonBanner(_ season: SeasonPublicInfo) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "crown.fill")
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 42, height: 42)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(season.label).font(.headline)
                Text(season.daysLeft > 0 ? "距赛季结算还有 \(season.daysLeft) 天" : "新赛季即将开启")
                    .font(.subheadline.bold())
                Text("每月 1 日 00:00 结算，上赛季竞点不原样带入，新赛季按最终段位继承。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func mySeasonCard(_ current: CurrentSeasonProgress) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("我的赛季").font(.caption).foregroundStyle(.secondary)
                    Text("#\(current.position) · \(current.title)").font(.title3.bold()).monospacedDigit()
                    Text("\(current.rank) · \(current.rating) 竞点").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "sparkles").font(.title2).foregroundStyle(.tint)
            }
            HStack(spacing: 10) {
                seasonStat("\(current.peakRating)", "赛季最高", current.peakRank)
                seasonStat("\(current.wins)胜 \(current.losses)负", "本季战绩", "\(current.battleCount) 场排位")
                seasonStat("\(current.achievementCount)/\(current.achievementTotal)", "赛季成就", "已解锁")
            }
            HStack(spacing: 10) {
                Button { seasonPanel = .achievements } label: { Label("赛季成就", systemImage: "sparkles") }
                    .buttonStyle(.bordered)
                if seasonMe?.previous != nil {
                    Button { seasonPanel = .previous } label: { Label("上赛季报告", systemImage: "trophy") }
                        .buttonStyle(.bordered)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func seasonStat(_ value: String, _ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.subheadline.bold()).monospacedDigit().lineLimit(1).minimumScaleFactor(0.8)
            Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(uiColor: .tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func rankingRow(_ user: User) -> some View {
        HStack(spacing: 12) {
            rankPosition(user.position)
                .frame(width: 34)
            RemoteAvatar(urlString: user.avatarURL, name: user.nickname, size: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text(user.nickname).font(.headline).lineLimit(1)
                Text("\(user.rank) · \(seasonHonor(user.position ?? 0))")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(user.rating)").font(.headline.monospacedDigit())
                Text("竞点").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func rankPosition(_ position: Int?) -> some View {
        let value = position ?? 0
        if (1...3).contains(value) {
            Image(systemName: value == 1 ? "trophy.fill" : "medal.fill")
                .font(.title3)
                .foregroundStyle(value == 1 ? Color.yellow : Color.secondary)
                .accessibilityLabel("第\(value)名")
        } else {
            Text("\(value)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func seasonHonor(_ position: Int) -> String {
        if position == 1 { return "赛季之巅" }
        if position == 2 { return "一人之下" }
        if position == 3 { return "稳居前三" }
        if position <= 10 { return "十强之席" }
        if position <= 100 { return "百强列阵" }
        if position <= 300 { return "崭露锋芒" }
        if position <= 1000 { return "上分新秀" }
        return "排位挑战者"
    }

    @MainActor
    private func load() async {
        loading = true; defer { loading = false }
        do {
            let response: RankingResponse = try await session.api.request("/api/rankings")
            items = response.items
            seasonInfo = response.season
            error = nil
            if let token = session.token {
                seasonMe = try? await session.api.request("/api/seasons/me", token: token)
            } else {
                seasonMe = nil
            }
        } catch { self.error = error.localizedDescription }
    }
}

private enum SeasonPanel: String, Identifiable {
    case achievements, previous
    var id: String { rawValue }
}

private struct SeasonAchievementsView: View {
    @Environment(\.dismiss) private var dismiss
    let current: CurrentSeasonProgress?

    var body: some View {
        NavigationStack {
            Group {
                if let current {
                    List {
                        Section {
                            LabeledContent("已解锁", value: "\(current.achievementCount) / \(current.achievementTotal)")
                        }
                        if current.achievements.isEmpty {
                            Section { Text("完成第一场排位后，赛季成就会从这里开始亮起来。").foregroundStyle(.secondary) }
                        } else {
                            Section("已解锁成就") {
                                ForEach(current.achievements) { achievement in
                                    HStack(alignment: .top, spacing: 12) {
                                        Text(achievement.icon).font(.title2).frame(width: 38)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(achievement.title).font(.headline)
                                            Text(achievement.description).font(.subheadline).foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                } else {
                    ProgressView("正在同步赛季成就…")
                }
            }
            .navigationTitle("本赛季成就")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }
}

private struct PreviousSeasonReportView: View {
    @Environment(\.dismiss) private var dismiss
    let result: SeasonResult

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(result.seasonLabel).font(.caption).foregroundStyle(.secondary)
                        Text(result.title).font(.title2.bold())
                        if let summary = result.report?.summary, !summary.isEmpty {
                            Text(summary).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }
                Section("赛季数据") {
                    LabeledContent("最终排名", value: "#\(result.finalPosition)")
                    LabeledContent("最终竞点", value: "\(result.finalRating)")
                    LabeledContent("最高竞点", value: "\(result.peakRating)")
                    LabeledContent("赛季战绩", value: "\(result.wins)胜 \(result.losses)负")
                    LabeledContent("最长连胜", value: "\(result.report?.maxWinStreak ?? 0)")
                }
                Section("新赛季继承") {
                    LabeledContent(result.inheritedRank, value: "\(result.inheritedRating) 竞点")
                    Text("只继承段位起点，上赛季积分不会原样滚入新赛季。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if !result.achievements.isEmpty {
                    Section("本季成就") {
                        ForEach(result.achievements.prefix(8)) { achievement in
                            Label("\(achievement.icon) \(achievement.title)", systemImage: "checkmark.seal")
                        }
                    }
                }
            }
            .navigationTitle("上赛季报告")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }
}

struct PublicProfileView: View {
    @Environment(SessionStore.self) private var session
    let userID: Int

    @State private var profile: User?
    @State private var loading = true
    @State private var busy = false
    @State private var error: String?
    @State private var message: String?
    @State private var inviteTarget: User?
    @State private var selectedChallenge: ChallengeRoute?
    @State private var battleRoomID: String?
    @State private var confirmBlock = false
    @State private var showingReport = false

    private var isSelf: Bool { session.user?.id == userID }

    var body: some View {
        Group {
            if loading && profile == nil {
                ProgressView("正在加载用户资料…")
            } else if let profile {
                List {
                    Section {
                        hero(profile)
                            .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20))
                            .listRowBackground(Color.clear)
                    }

                    Section("数据") {
                        LabeledContent("获胜率", value: "\(Int(profile.winRate ?? 0))%")
                        LabeledContent("对战", value: "\(profile.battleCount ?? 0) 场")
                        LabeledContent("已刷题量", value: "\(profile.questions ?? 0)")
                        LabeledContent("好友", value: "\(profile.friendCount ?? 0)")
                    }

                    interactionSections(profile)

                    if let message {
                        Section { Label(message, systemImage: "checkmark.circle").foregroundStyle(.secondary) }
                    }
                    if let error {
                        Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red) }
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable { await load() }
            } else {
                ContentUnavailableView("资料加载失败", systemImage: "person.crop.circle.badge.exclamationmark", description: Text(error ?? "暂时无法读取该用户资料"))
            }
        }
        .navigationTitle("用户资料")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: userID) { await load() }
        .sheet(item: $inviteTarget) { user in
            FriendChallengeSetupSheet(user: user) { subject, topic in
                inviteTarget = nil
                inviteBattle(user, subject: subject, topic: topic)
            }
        }
        .sheet(isPresented: $showingReport) {
            UserReportSheet(userID: userID) { result in
                message = result
            }
        }
        .navigationDestination(item: $selectedChallenge) { route in
            DailyChallengeView(challengeID: route.id)
        }
        .navigationDestination(item: $battleRoomID) { roomID in
            if let token = session.token {
                BattleRoomView(store: BattleRoomStore(roomID: roomID, token: token))
            } else {
                ContentUnavailableView("登录状态已失效", systemImage: "person.crop.circle.badge.exclamationmark")
            }
        }
        .confirmationDialog("确定拉黑该用户？", isPresented: $confirmBlock, titleVisibility: .visible) {
            Button("拉黑并解除好友关系", role: .destructive) { block() }
            Button("取消", role: .cancel) { }
        } message: {
            Text("拉黑后双方不能再互加好友或邀请对战。")
        }
    }

    private func hero(_ user: User) -> some View {
        VStack(spacing: 12) {
            RemoteAvatar(urlString: user.avatarURL, name: user.nickname, size: 86)
            HStack(spacing: 8) {
                Text(user.nickname).font(.title2.bold()).lineLimit(1)
                if let gender = user.gender, gender != "保密" {
                    Text(gender).font(.caption.bold()).foregroundStyle(.secondary)
                }
            }
            Text(user.bio.flatMap { $0.isEmpty ? nil : $0 } ?? "这个人还没有填写个人简介。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 6) {
                if let position = user.position, (1...3).contains(position) {
                    Image(systemName: position == 1 ? "crown.fill" : "medal.fill")
                        .foregroundStyle(position == 1 ? Color.yellow : Color.secondary)
                }
                Text("全站第 \(user.position ?? 0) 名 · \(user.rating) 竞点")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func interactionSections(_ user: User) -> some View {
        if isSelf {
            Section("个人资料") {
                Label("资料编辑请从“我的”页面进入", systemImage: "person.crop.circle")
                    .foregroundStyle(.secondary)
            }
        } else if user.blockedMe == true {
            Section("互动") {
                Label("当前无法与该用户进行好友互动", systemImage: "hand.raised")
                    .foregroundStyle(.secondary)
            }
        } else if user.blockedByMe == true {
            Section("互动") {
                Label("你已拉黑该用户", systemImage: "person.crop.circle.badge.xmark")
                    .foregroundStyle(.secondary)
                Button { unblock() } label: {
                    Label("解除拉黑", systemImage: "arrow.uturn.backward")
                }
                .disabled(busy)
            }
        } else {
            Section("互动") {
                if user.friendStatus == "friend" {
                    Button {
                        Haptics.selection()
                        inviteTarget = user
                    } label: {
                        Label("好友挑战", systemImage: "bolt.horizontal.circle.fill")
                    }
                }

                Button { friendAction(user) } label: {
                    Label(friendActionTitle(user), systemImage: friendActionIcon(user))
                }
                .disabled(busy || user.friendStatus == "outgoing")
            }

            Section("安全") {
                Button { showingReport = true } label: {
                    Label("举报用户", systemImage: "flag")
                }
                Button("拉黑用户", systemImage: "hand.raised", role: .destructive) {
                    Haptics.warning()
                    confirmBlock = true
                }
            }
        }
    }

    private func friendActionTitle(_ user: User) -> String {
        switch user.friendStatus {
        case "friend": "删除好友"
        case "incoming": "接受好友申请"
        case "outgoing": "申请已发送"
        default: "添加好友"
        }
    }

    private func friendActionIcon(_ user: User) -> String {
        switch user.friendStatus {
        case "friend": "person.badge.minus"
        case "incoming": "person.badge.checkmark"
        case "outgoing": "clock"
        default: "person.badge.plus"
        }
    }

    @MainActor private func load() async {
        guard let token = session.token else { loading = false; return }
        loading = true
        defer { loading = false }
        do {
            profile = try await session.api.request("/api/users/\(userID)/profile", token: token)
            error = nil
        } catch { self.error = error.localizedDescription }
    }

    private func friendAction(_ user: User) {
        guard let token = session.token else { return }
        let status = user.friendStatus ?? "none"
        let path: String
        let method: HTTPMethod
        switch status {
        case "friend": path = "/api/friends/\(user.id)"; method = .delete
        case "incoming":
            guard let relationID = user.relationID else { return }
            path = "/api/friends/\(relationID)/accept"; method = .post
        case "outgoing": return
        default: path = "/api/friends/request/\(user.id)"; method = .post
        }
        busy = true; error = nil
        Task { @MainActor in
            defer { busy = false }
            do {
                let _: EmptyResponse = try await session.api.request(path, method: method, body: EmptyBody(), token: token)
                Haptics.success(); await load()
            } catch { self.error = error.localizedDescription; Haptics.error() }
        }
    }

    private func block() { blockMutation(method: .post) }
    private func unblock() { blockMutation(method: .delete) }

    private func blockMutation(method: HTTPMethod) {
        guard let token = session.token else { return }
        busy = true; error = nil
        Task { @MainActor in
            defer { busy = false }
            do {
                let _: EmptyResponse = try await session.api.request("/api/users/\(userID)/block", method: method, body: EmptyBody(), token: token)
                Haptics.success(); await load()
            } catch { self.error = error.localizedDescription; Haptics.error() }
        }
    }

    private func inviteBattle(_ user: User, subject: String?, topic: String?) {
        guard let token = session.token else { return }
        busy = true; error = nil
        Task { @MainActor in
            defer { busy = false }
            do {
                let response: FriendBattleInviteResponse = try await session.api.request(
                    "/api/battles/friend/invite/\(user.id)",
                    method: .post,
                    body: BattleModeBody(rule: "speed", subject: subject, topic: topic),
                    token: token
                )
                if response.mode == "friend_challenge", let challengeID = response.challengeID, !challengeID.isEmpty {
                    selectedChallenge = ChallengeRoute(id: challengeID)
                } else if let roomID = response.roomID, !roomID.isEmpty {
                    battleRoomID = roomID
                } else {
                    throw APIError(message: "服务器未返回好友对战房间", statusCode: 0, retryAfter: nil)
                }
                Haptics.success()
            } catch { self.error = error.localizedDescription; Haptics.error() }
        }
    }
}

private struct UserReportSheet: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    let userID: Int
    let onDone: (String) -> Void

    @State private var category = "nickname"
    @State private var content = ""
    @State private var busy = false
    @State private var error: String?

    private let categories = [
        ("nickname", "违规昵称"), ("bio", "违规简介"), ("avatar", "违规头像"),
        ("harassment", "骚扰辱骂"), ("cheating", "疑似作弊"), ("other", "其他")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("举报类型") {
                    Picker("类型", selection: $category) {
                        ForEach(categories, id: \.0) { item in Text(item.1).tag(item.0) }
                    }
                }
                Section("补充说明（选填）") {
                    TextField("可说明具体问题", text: $content, axis: .vertical)
                        .lineLimit(4...8)
                        .onChange(of: content) { _, value in if value.count > 500 { content = String(value.prefix(500)) } }
                    Text("\(content.count)/500").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .trailing)
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
            }
            .navigationTitle("举报用户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(busy ? "提交中…" : "提交") { submit() }.disabled(busy)
                }
            }
        }
    }

    private func submit() {
        guard let token = session.token else { return }
        busy = true; error = nil
        Task { @MainActor in
            defer { busy = false }
            do {
                let response: UserReportResponse = try await session.api.request(
                    "/api/users/\(userID)/report", method: .post,
                    body: UserReportBody(category: category, content: content.trimmingCharacters(in: .whitespacesAndNewlines)), token: token
                )
                Haptics.success()
                onDone(response.duplicate == true ? "你近期已经举报过该用户，后台正在处理。" : "举报已提交，管理员会在后台复核。")
                dismiss()
            } catch { self.error = error.localizedDescription; Haptics.error() }
        }
    }
}

private struct UserReportBody: Encodable { let category: String; let content: String }
private struct UserReportResponse: Decodable { let duplicate: Bool? }
