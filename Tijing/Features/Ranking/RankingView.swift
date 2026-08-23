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
    @State private var selectedUserCard: UserCardTarget?

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
                            Text("这一季的排行、记录和个人进展，都在这里。")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if let season = seasonInfo ?? seasonMe?.season {
                            seasonHero(season)
                                .tijingReveal(order: 1)
                        }

                        if !items.isEmpty {
                            podiumSection
                                .tijingReveal(order: 2)
                        }

                        if let current = seasonMe?.current {
                            mySeasonSection(current)
                                .tijingReveal(order: 3)
                        }

                        rankingListSection
                            .tijingReveal(order: 4)

                        if let error {
                            Label(error, systemImage: "wifi.exclamationmark")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        TijingTabBarContentFooter()
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
        .sheet(item: $selectedUserCard) { target in
            PublicProfileView(userID: target.id)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func seasonHero(_ season: SeasonPublicInfo) -> some View {
        let days = max(0, season.daysLeft)
        return TijingPaperCard(tint: TijingDesign.lilac, rotation: -0.18) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(TijingDesign.violet.opacity(0.12))
                        .frame(width: 72, height: 72)
                    Circle()
                        .trim(from: 0, to: min(1, max(0.06, CGFloat(31 - min(days, 31)) / 31)))
                        .stroke(TijingDesign.violet, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 62, height: 62)
                    VStack(spacing: -1) {
                        Text("\(days)")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("天")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 7) {
                        TijingMicroBadge(title: "赛季结算", systemImage: "calendar.badge.clock", tint: TijingDesign.violet)
                        Text(season.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(days > 0 ? "这一季还没写完" : "新赛季准备开始")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                    Text(days > 0 ? "把最后几场打漂亮，结算时会生成你的赛季名片。" : "结算完成后会从上一季最终段位继承新的起点。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Image(systemName: "sparkles")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(TijingDesign.amber)
                    .symbolEffect(.pulse, options: .repeat(2))
            }
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
            Button {
                Haptics.selection()
                selectedUserCard = UserCardTarget(id: user.id)
            } label: {
                SeasonPodiumCard(user: user, place: place)
            }
            .buttonStyle(TijingPressableCardStyle())
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
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.38), value: current.rating)
                Text("竞点")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                TijingMetricTile(value: "\(current.peakRating)", title: "赛季最高", systemImage: "arrow.up.right", tint: TijingDesign.mint)
                TijingMetricTile(value: "\(current.wins)胜 \(current.losses)负", title: "本季战绩", systemImage: "bolt.fill", tint: TijingDesign.indigo)
                TijingMetricTile(value: "\(current.achievementCount)/\(current.achievementTotal)", title: "赛季成就", systemImage: "medal.fill", tint: TijingDesign.amber)
            }

            HStack(spacing: 10) {
                Button {
                    Haptics.light()
                    seasonPanel = .achievements
                } label: {
                    Label("赛季成就", systemImage: "medal.fill")
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
                        Button {
                            Haptics.selection()
                            selectedUserCard = UserCardTarget(id: user.id)
                        } label: {
                            rankingRow(user)
                        }
                        .buttonStyle(.plain)
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
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.34), value: user.position)
                .foregroundStyle(.secondary)
                .frame(width: 34)

            TijingInteractiveAvatar(urlString: user.avatarURL, name: user.nickname, size: 42)

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
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.34), value: user.rating)
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
        if items.isEmpty, let cached: RankingResponse = session.api.cachedResponse(for: "public.ranking") {
            items = cached.items
            seasonInfo = cached.season
        }
        if seasonMe == nil, session.token != nil,
           let cached: SeasonMeResponse = session.api.cachedResponse(for: session.userCacheKey("season.me")) {
            seasonMe = cached
        }

        loading = items.isEmpty
        defer { loading = false }
        do {
            let response: RankingResponse = try await session.api.requestCached("/api/rankings", cacheKey: "public.ranking")
            items = response.items
            seasonInfo = response.season
            error = nil
            if let token = session.token {
                seasonMe = try? await session.api.requestCached(
                    "/api/seasons/me", token: token, cacheKey: session.userCacheKey("season.me")
                )
            } else {
                seasonMe = nil
            }
        } catch {
            self.error = items.isEmpty ? error.localizedDescription : nil
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
                TijingInteractiveAvatar(urlString: user.avatarURL, name: user.nickname, size: place == 1 ? 68 : 56)
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
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.34), value: user.rating)
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
            ZStack {
                TijingPageBackground()
                if let current {
                    ScrollView {
                        VStack(spacing: 16) {
                            achievementOverview(current)

                            if current.achievements.isEmpty {
                                TijingPaperCard(tint: TijingDesign.sky) {
                                    HStack(spacing: 12) {
                                        SeasonAchievementMedallion(key: "locked", title: "待解锁", size: 48)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text("第一枚成就正在等你")
                                                .font(.headline)
                                            Text("完成第一场排位后，这里会开始收集属于你的赛季印记。")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            } else {
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                    ForEach(current.achievements) { achievement in
                                        achievementCard(achievement)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, TijingDesign.pageHorizontalPadding)
                        .padding(.top, 10)
                        .padding(.bottom, 28)
                    }
                } else {
                    ProgressView("正在同步赛季成就…")
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }

    private func achievementOverview(_ current: CurrentSeasonProgress) -> some View {
        TijingPaperCard(tint: TijingDesign.butter, rotation: -0.20) {
            HStack(spacing: 14) {
                ZStack {
                    SeasonAchievementMedallion(key: "collection", title: "赛季成就", size: 58)
                    Text("\(current.achievementCount)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(TijingDesign.indigo, in: Circle())
                        .offset(x: 23, y: -23)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text("赛季收藏册")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                    Text("已点亮 \(current.achievementCount) / \(current.achievementTotal)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ProgressView(value: Double(current.achievementCount), total: Double(max(1, current.achievementTotal)))
                        .tint(TijingDesign.amber)
                }
            }
        }
    }

    private func achievementCard(_ achievement: SeasonAchievement) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SeasonAchievementMedallion(key: achievement.key, title: achievement.title, size: 50)
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(TijingDesign.mint)
                    .font(.subheadline)
            }
            Text(achievement.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text(achievement.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055))
        }
        .buttonStyle(TijingPressableCardStyle())
    }
}

private struct SeasonAchievementMedallion: View {
    let key: String
    let title: String
    var size: CGFloat = 52

    private var visual: (String, Color, Color) {
        let token = (key + " " + title).lowercased()
        if token.contains("streak") || title.contains("连") { return ("flame.fill", TijingDesign.coral, TijingDesign.peach) }
        if token.contains("speed") || title.contains("速度") { return ("bolt.fill", TijingDesign.amber, TijingDesign.butter) }
        if token.contains("perfect") || title.contains("十全") { return ("star.fill", TijingDesign.amber, TijingDesign.butter) }
        if token.contains("turnaround") || title.contains("翻盘") || title.contains("反杀") { return ("arrow.up.right.circle.fill", TijingDesign.mint, TijingDesign.sage) }
        if token.contains("clutch") || token.contains("match_point") || title.contains("关键") || title.contains("大心脏") { return ("heart.fill", TijingDesign.coral, TijingDesign.peach) }
        if token.contains("first") { return ("flag.fill", TijingDesign.indigo, TijingDesign.sky) }
        if token.contains("win") || title.contains("胜") { return ("trophy.fill", TijingDesign.amber, TijingDesign.butter) }
        if token.contains("correct") || title.contains("题斩") { return ("checkmark.circle.fill", TijingDesign.mint, TijingDesign.sage) }
        if token.contains("days") || title.contains("七日") { return ("calendar.badge.checkmark", TijingDesign.violet, TijingDesign.lilac) }
        if key == "locked" { return ("lock.fill", .secondary, TijingDesign.sky) }
        return ("medal.fill", TijingDesign.violet, TijingDesign.lilac)
    }

    var body: some View {
        let visual = visual
        ZStack {
            Circle().fill(visual.2)
            Circle().strokeBorder(visual.1.opacity(0.18), lineWidth: 1)
            Image(systemName: visual.0)
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(visual.1)
                .symbolRenderingMode(.hierarchical)
        }
        .frame(width: size, height: size)
        .shadow(color: visual.1.opacity(0.10), radius: 8, y: 4)
    }
}

private struct PreviousSeasonReportView: View {
    @Environment(\.dismiss) private var dismiss
    let result: SeasonResult

    var body: some View {
        NavigationStack {
            ZStack {
                TijingPageBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        TijingPaperCard(tint: TijingDesign.lilac, rotation: -0.25) {
                            HStack(spacing: 13) {
                                TijingStickerIcon(systemImage: "clock.arrow.circlepath", tint: TijingDesign.violet, background: TijingDesign.lilac, size: 50, rotation: -7)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(result.seasonLabel).font(.caption).foregroundStyle(.secondary)
                                    Text(result.title).font(.title2.bold())
                                    if let summary = result.report?.summary, !summary.isEmpty {
                                        Text(summary).font(.subheadline).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                        }

                        TijingPaperCard(tint: TijingDesign.sky) {
                            VStack(spacing: 12) {
                                TijingMiniStatRow(systemImage: "number", title: "最终排名", value: "#\(result.finalPosition)", tint: TijingDesign.indigo)
                                TijingMiniStatRow(systemImage: "sparkles", title: "最终竞点", value: "\(result.finalRating)", tint: TijingDesign.amber)
                                TijingMiniStatRow(systemImage: "arrow.up.right", title: "最高竞点", value: "\(result.peakRating)", tint: TijingDesign.mint)
                                TijingMiniStatRow(systemImage: "trophy.fill", title: "赛季战绩", value: "\(result.wins)胜 \(result.losses)负", tint: TijingDesign.violet)
                                TijingMiniStatRow(systemImage: "flame.fill", title: "最长连胜", value: "\(result.report?.maxWinStreak ?? 0)", tint: TijingDesign.coral)
                            }
                        }

                        TijingPaperCard(tint: TijingDesign.sage) {
                            HStack(spacing: 12) {
                                TijingStickerIcon(systemImage: "arrow.forward.circle.fill", tint: TijingDesign.mint, background: TijingDesign.sage, size: 42, sparkle: false)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("新赛季继承")
                                        .font(.headline)
                                    Text("\(result.inheritedRank) · \(result.inheritedRating) 竞点")
                                        .font(.subheadline.weight(.semibold))
                                    Text("只继承段位起点，上赛季积分不会原样滚入新赛季。")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                        }

                        if !result.achievements.isEmpty {
                            VStack(spacing: 10) {
                                TijingSectionHeading("本季成就")
                                ForEach(Array(result.achievements.prefix(8).enumerated()), id: \.element.id) { index, achievement in
                                    HStack(spacing: 12) {
                                        Text(achievement.icon).font(.title3).frame(width: 34)
                                        Text(achievement.title).font(.subheadline.weight(.semibold))
                                        Spacer()
                                        Image(systemName: "checkmark.seal.fill").foregroundStyle(TijingDesign.mint)
                                    }
                                    .padding(14)
                                    .tijingCard()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, TijingDesign.pageHorizontalPadding)
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }
}

struct PublicProfileView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
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
        NavigationStack {
            ZStack {
                TijingPageBackground()
                Group {
                    if loading && profile == nil {
                        ProgressView("正在加载用户卡片…")
                    } else if let profile {
                        ScrollView {
                            VStack(spacing: 14) {
                                compactIdentityCard(profile)
                                compactActions(profile)
                                if let message {
                                    Label(message, systemImage: "checkmark.circle.fill")
                                        .font(.footnote)
                                        .foregroundStyle(TijingDesign.mint)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 4)
                                }
                                if let error {
                                    Label(error, systemImage: "exclamationmark.triangle.fill")
                                        .font(.footnote)
                                        .foregroundStyle(.red)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 4)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                            .padding(.bottom, 22)
                        }
                        .refreshable { await load() }
                    } else {
                        ContentUnavailableView("资料加载失败", systemImage: "person.crop.circle.badge.exclamationmark", description: Text(error ?? "暂时无法读取该用户资料"))
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("关闭")
                }
            }
            .task(id: userID) { await load() }
            .sheet(item: $inviteTarget) { user in
                FriendChallengeSetupSheet(user: user) { subject, topic in
                    inviteTarget = nil
                    inviteBattle(user, subject: subject, topic: topic)
                }
            }
            .sheet(isPresented: $showingReport) {
                UserReportSheet(userID: userID) { result in message = result }
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
    }

    private func compactIdentityCard(_ user: User) -> some View {
        TijingPaperCard(tint: TijingDesign.sky, rotation: -0.2) {
            VStack(spacing: 17) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack(alignment: .bottomTrailing) {
                        RemoteAvatar(urlString: user.avatarURL, name: user.nickname, size: 76)
                            .overlay { Circle().stroke(.white.opacity(0.86), lineWidth: 3) }
                            .shadow(color: .black.opacity(0.06), radius: 9, y: 4)
                        if let position = user.position, (1...3).contains(position) {
                            Image(systemName: position == 1 ? "crown.fill" : "medal.fill")
                                .font(.caption.bold())
                                .foregroundStyle(position == 1 ? TijingDesign.amber : TijingDesign.indigo)
                                .frame(width: 27, height: 27)
                                .background(.white.opacity(0.90), in: Circle())
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text(user.nickname)
                                .font(.system(.title2, design: .rounded, weight: .bold))
                                .lineLimit(1)
                            if user.isAdmin == true {
                                Image(systemName: "checkmark.seal.fill").foregroundStyle(TijingDesign.indigo)
                            }
                        }
                        Text(user.bio.flatMap { $0.isEmpty ? nil : $0 } ?? "这个人还没有填写个人简介。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        HStack(spacing: 6) {
                            TijingMicroBadge(title: user.rank, systemImage: "seal.fill", tint: TijingDesign.indigo)
                            if let position = user.position {
                                TijingMicroBadge(title: "#\(position)", systemImage: "number", tint: TijingDesign.amber)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }

                Divider().opacity(0.28)

                HStack(spacing: 0) {
                    compactMetric("\(user.rating)", "竞点", "sparkles", TijingDesign.amber)
                    Divider().frame(height: 40)
                    compactMetric("\(Int(user.winRate ?? 0))%", "获胜率", "chart.bar.fill", TijingDesign.mint)
                    Divider().frame(height: 40)
                    compactMetric("\(user.questions ?? 0)", "已刷题", "book.closed.fill", TijingDesign.indigo)
                    Divider().frame(height: 40)
                    compactMetric("\(user.friendCount ?? 0)", "好友", "person.2.fill", TijingDesign.cyan)
                }
            }
        }
    }

    private func compactMetric(_ value: String, _ title: String, _ icon: String, _ tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2.weight(.bold))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func compactActions(_ user: User) -> some View {
        if isSelf {
            HStack(spacing: 11) {
                TijingStickerIcon(systemImage: "person.crop.circle.fill", tint: TijingDesign.indigo, background: TijingDesign.butter, size: 40, sparkle: false)
                Text("这是你的公开资料卡，编辑资料请从“我的”页面进入。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .padding(14)
            .tijingCard()
        } else if user.blockedMe == true {
            HStack(spacing: 11) {
                TijingStickerIcon(systemImage: "hand.raised.fill", tint: TijingDesign.coral, background: TijingDesign.rose, size: 40, sparkle: false)
                Text("当前无法与该用户进行好友互动。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .padding(14)
            .tijingCard()
        } else if user.blockedByMe == true {
            Button {
                unblock()
            } label: {
                Label("解除拉黑", systemImage: "arrow.uturn.backward")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(busy)
        } else {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    if user.friendStatus == "friend" {
                        Button {
                            Haptics.medium()
                            inviteTarget = user
                        } label: {
                            Label("好友挑战", systemImage: "bolt.horizontal.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if user.friendStatus == "friend" {
                        Button {
                            Haptics.selection()
                            friendAction(user)
                        } label: {
                            Label(friendActionTitle(user), systemImage: friendActionIcon(user))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(busy || user.friendStatus == "outgoing")
                    } else {
                        Button {
                            Haptics.selection()
                            friendAction(user)
                        } label: {
                            Label(friendActionTitle(user), systemImage: friendActionIcon(user))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(busy || user.friendStatus == "outgoing")
                    }
                }
                .controlSize(.large)

                HStack(spacing: 10) {
                    Button {
                        Haptics.light()
                        showingReport = true
                    } label: {
                        Label("举报", systemImage: "flag")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive) {
                        Haptics.warning(); confirmBlock = true
                    } label: {
                        Label("拉黑", systemImage: "hand.raised")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func friendActionTitle(_ user: User) -> String {
        switch user.friendStatus {
        case "friend": "删除好友"
        case "incoming": "接受申请"
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
        let cacheKey = session.userCacheKey("public-profile.\(userID)")
        if profile == nil { profile = session.api.cachedResponse(for: cacheKey) }
        loading = profile == nil
        defer { loading = false }
        do {
            profile = try await session.api.requestCached(
                "/api/users/\(userID)/profile", token: token, cacheKey: cacheKey
            )
            error = nil
        } catch {
            self.error = profile == nil ? error.localizedDescription : nil
        }
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
                    "/api/battles/friend/invite/\(user.id)", method: .post,
                    body: BattleModeBody(rule: "speed", subject: subject, topic: topic), token: token
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
            ZStack {
                TijingPageBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        TijingPaperCard(tint: TijingDesign.rose, rotation: -0.25) {
                            HStack(spacing: 13) {
                                TijingStickerIcon(systemImage: "flag.fill", tint: TijingDesign.coral, background: TijingDesign.rose, size: 48, rotation: -7)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("举报用户")
                                        .font(.headline)
                                    Text("请选择最接近的问题类型，补充说明可以留空。")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                        }

                        TijingFieldSurface("举报类型") {
                            Picker("类型", selection: $category) {
                                ForEach(categories, id: \.0) { item in Text(item.1).tag(item.0) }
                            }
                            .pickerStyle(.menu)
                        }

                        TijingFieldSurface("补充说明（选填）") {
                            TextField("可说明具体问题", text: $content, axis: .vertical)
                                .lineLimit(4...8)
                                .onChange(of: content) { _, value in if value.count > 500 { content = String(value.prefix(500)) } }
                            Text("\(content.count)/500")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }

                        if let error {
                            Label(error, systemImage: "exclamationmark.circle.fill")
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
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .sensoryFeedback(.selection, trigger: category)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(busy ? "提交中…" : "提交") { submit() }.bold().disabled(busy)
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
