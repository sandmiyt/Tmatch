import SwiftUI

struct RankingView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var items: [User] = []
    @State private var seasonInfo: SeasonPublicInfo?
    @State private var seasonMe: SeasonMeResponse?
    @State private var loading = true
    @State private var error: String?
    @State private var seasonPanel: SeasonPanel?

    var body: some View {
        ZStack {
            TijingPageBackground()

            if loading && items.isEmpty {
                ProgressView("正在加载排行榜")
            } else if items.isEmpty {
                ContentUnavailableView("暂无排行数据", systemImage: "trophy", description: Text(error ?? "稍后再试"))
            } else {
                ScrollView {
                    LazyVStack(spacing: TijingDesign.sectionSpacing) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("排行榜")
                                .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                            Text("这一季，看看谁真的把正确率打成了段位。")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if let season = seasonInfo ?? seasonMe?.season {
                            seasonHero(season)
                        }

                        if !items.isEmpty {
                            podiumSection
                        }

                        if let current = seasonMe?.current {
                            mySeasonSection(current)
                        }

                        rankingListSection

                        if let error {
                            Label(error, systemImage: "wifi.exclamationmark")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, TijingDesign.pageHorizontalPadding)
                    .padding(.top, 10)
                    .padding(.bottom, 30)
                }
                .refreshable { await load() }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
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

    private func seasonHero(_ season: SeasonPublicInfo) -> some View {
        TijingHeroCard(
            gradient: LinearGradient(
                colors: [Color(red: 0.13, green: 0.15, blue: 0.30), TijingDesign.indigo, TijingDesign.violet],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Label(season.label, systemImage: "crown.fill")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.82))
                    Text(season.daysLeft > 0 ? "\(season.daysLeft) 天后结算" : "新赛季即将开启")
                        .font(.system(.title, design: .rounded, weight: .bold))
                    Text("每月 1 日结算，新的赛季从上一季最终段位继续出发。")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "trophy.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(TijingDesign.amber)
                    .symbolRenderingMode(.hierarchical)
            }
            .foregroundStyle(.white)
        }
    }

    private var podiumSection: some View {
        VStack(spacing: 14) {
            TijingSectionHeading("赛季前三", subtitle: "前三名拥有更强的荣誉层级，其余名次回归干净的信息列表")

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 10) {
                    if let first = items.first { podiumLink(first, place: 1) }
                    if items.count > 1 { podiumLink(items[1], place: 2) }
                    if items.count > 2 { podiumLink(items[2], place: 3) }
                }
            } else {
                HStack(alignment: .bottom, spacing: 10) {
                    if items.count > 1 { podiumLink(items[1], place: 2) }
                    if let first = items.first { podiumLink(first, place: 1) }
                    if items.count > 2 { podiumLink(items[2], place: 3) }
                }
            }
        }
    }

    @ViewBuilder
    private func podiumLink(_ user: User, place: Int) -> some View {
        if session.token != nil {
            NavigationLink {
                PublicProfileView(userID: user.id)
            } label: {
                SeasonPodiumCard(user: user, place: place)
            }
            .buttonStyle(TijingPressableCardStyle())
            .tijingTactileLink()
        } else {
            SeasonPodiumCard(user: user, place: place)
        }
    }

    private func mySeasonSection(_ current: CurrentSeasonProgress) -> some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                TijingSectionHeading("我的赛季", subtitle: "#\(current.position) · \(current.title)")
                Spacer()
                Text("\(current.rating)")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .monospacedDigit()
                Text("竞点")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                TijingMetricTile(value: "\(current.peakRating)", title: "赛季最高", systemImage: "arrow.up.right", tint: TijingDesign.mint)
                TijingMetricTile(value: "\(current.wins)胜 \(current.losses)负", title: "本季战绩", systemImage: "bolt.fill", tint: TijingDesign.indigo)
                TijingMetricTile(value: "\(current.achievementCount)/\(current.achievementTotal)", title: "赛季成就", systemImage: "sparkles", tint: TijingDesign.amber)
            }

            HStack(spacing: 10) {
                Button {
                    Haptics.light()
                    seasonPanel = .achievements
                } label: {
                    Label("赛季成就", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                if seasonMe?.previous != nil {
                    Button {
                        Haptics.light()
                        seasonPanel = .previous
                    } label: {
                        Label("上季报告", systemImage: "clock.arrow.circlepath")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
        }
    }

    private var rankingListSection: some View {
        VStack(spacing: 12) {
            TijingSectionHeading(items.count > 3 ? "继续向上" : "本赛季排行")

            TijingSettingsGroup {
                ForEach(Array(items.dropFirst(min(3, items.count)))) { user in
                    if session.token != nil {
                        NavigationLink {
                            PublicProfileView(userID: user.id)
                        } label: {
                            rankingRow(user)
                        }
                        .buttonStyle(.plain)
                        .tijingTactileLink()
                    } else {
                        rankingRow(user)
                    }
                    if user.id != items.last?.id {
                        Divider().padding(.leading, 68)
                    }
                }

                if items.count <= 3 {
                    Text("当前排行人数较少，完成排位后会继续出现更多名次。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
            }
        }
    }

    private func rankingRow(_ user: User) -> some View {
        HStack(spacing: 12) {
            Text("\(user.position ?? 0)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 34)

            RemoteAvatar(urlString: user.avatarURL, name: user.nickname, size: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(user.nickname)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("\(user.rank) · \(seasonHonor(user.position ?? 0))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(user.rating)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.primary)
                Text("竞点")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
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
        loading = true
        defer { loading = false }
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
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct SeasonPodiumCard: View {
    let user: User
    let place: Int

    private var tint: Color {
        switch place {
        case 1: TijingDesign.amber
        case 2: Color(uiColor: .systemGray2)
        default: Color(red: 0.78, green: 0.48, blue: 0.28)
        }
    }

    var body: some View {
        VStack(spacing: 9) {
            ZStack(alignment: .topTrailing) {
                RemoteAvatar(urlString: user.avatarURL, name: user.nickname, size: place == 1 ? 68 : 56)
                    .overlay {
                        Circle().stroke(tint.opacity(0.80), lineWidth: place == 1 ? 3 : 2)
                    }
                Text("\(place)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(tint, in: Circle())
                    .offset(x: 5, y: -5)
            }

            Text(user.nickname)
                .font(place == 1 ? .headline : .subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text("\(user.rating)")
                .font(.system(place == 1 ? .title2 : .headline, design: .rounded, weight: .bold))
                .monospacedDigit()
            Text(place == 1 ? "赛季之巅" : (place == 2 ? "一人之下" : "稳居前三"))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .padding(.top, place == 1 ? 20 : 15)
        .padding(.bottom, place == 1 ? 18 : 15)
        .background {
            if place == 1 {
                LinearGradient(
                    colors: [tint.opacity(0.24), Color.accentColor.opacity(0.10)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                Rectangle().fill(.regularMaterial)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: TijingDesign.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: TijingDesign.cardRadius, style: .continuous)
                .strokeBorder(tint.opacity(place == 1 ? 0.35 : 0.16))
        }
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
