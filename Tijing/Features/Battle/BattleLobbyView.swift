import SwiftUI

struct BattleLobbyView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var matching = false
    @State private var matchStatus = ""
    @State private var roomID: String?
    @State private var joinCode = ""
    @State private var error: String?
    @State private var matchTask: Task<Void, Never>?
    @State private var catalog: [PracticeSubject] = []
    @State private var subject = ""
    @State private var topic = ""
    @State private var catalogLoading = true
    @State private var lastMatchStage = "exact"

    private var selectedSubject: PracticeSubject? { catalog.first { $0.name == subject } }
    private var scopeLabel: String { topic.isEmpty ? (subject.isEmpty ? "全部题库" : subject) : "\(subject) · \(topic)" }

    var body: some View {
        ZStack {
            TijingPageBackground()

            ScrollView {
                LazyVStack(spacing: TijingDesign.sectionSpacing) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("对战")
                            .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                        Text("十道题，拼正确率，也拼节奏。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .tijingReveal(order: 0)

                    rankedHero
                        .tijingReveal(order: 1)
                    scopeCard
                        .tijingReveal(order: 2)
                    secondaryModes
                        .tijingReveal(order: 3)
                    joinRoomCard
                        .tijingReveal(order: 4)

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
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: subject)
        .sensoryFeedback(.selection, trigger: topic)
        .navigationDestination(item: $roomID) { id in
            if let token = session.token {
                BattleRoomView(store: BattleRoomStore(roomID: id, token: token))
            } else {
                ContentUnavailableView("登录状态已失效", systemImage: "person.crop.circle.badge.exclamationmark")
            }
        }
        .task {
            await loadCatalog()
            await recoverActiveBattle()
        }
        .onDisappear {
            if matching { cancelMatch() }
        }
    }

    private var rankedHero: some View {
        TijingHeroCard(gradient: TijingDesign.battleGradient) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Label("排位赛", systemImage: "bolt.fill")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.86))
                        Text(session.user?.rank ?? "排位挑战者")
                            .font(.system(.title, design: .rounded, weight: .bold))
                        Text("\(session.user?.rating ?? 0) 竞点 · \(scopeLabel)")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.76))
                            .monospacedDigit()
                    }
                    Spacer(minLength: 12)
                    if matching {
                        TijingMatchmakingPulse()
                            .transition(.scale(scale: 0.84).combined(with: .opacity))
                    } else {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.92))
                            .transition(.scale(scale: 0.86).combined(with: .opacity))
                    }
                }

                if matching {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "sparkles")
                                .font(.subheadline.bold())
                                .foregroundStyle(.white.opacity(0.82))
                                .padding(.top, 2)
                            Text(matchStatus.isEmpty ? "正在匹配对手…" : matchStatus)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white.opacity(0.88))
                                .fixedSize(horizontal: false, vertical: true)
                                .id(matchStatus)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        Button(role: .destructive) {
                            cancelMatch()
                        } label: {
                            Label("取消匹配", systemImage: "xmark")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                        }
                        .foregroundStyle(.white)
                        .buttonStyle(TijingPressableCardStyle())
                    }
                } else {
                    Button {
                        startMatch()
                    } label: {
                        HStack {
                            Label("开始排位匹配", systemImage: "bolt.fill")
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                        .font(.headline)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(TijingPressableCardStyle())
                }
            }
            .foregroundStyle(.white)
            .animation(.spring(response: 0.52, dampingFraction: 0.84), value: matching)
            .animation(.easeInOut(duration: 0.28), value: matchStatus)
        }
    }

    private var scopeCard: some View {
        VStack(spacing: 12) {
            TijingSectionHeading("匹配范围", subtitle: "指定章节时，等待过久会按原规则自动扩大范围")

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "books.vertical.fill")
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 34, height: 34)
                        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    Text("题库")
                        .font(.body.weight(.medium))
                    Spacer()
                    Menu {
                        Button {
                            subject = ""
                            topic = ""
                        } label: {
                            Label("全部题库", systemImage: subject.isEmpty ? "checkmark" : "books.vertical")
                        }
                        ForEach(catalog) { item in
                            Button {
                                subject = item.name
                                topic = ""
                            } label: {
                                HStack {
                                    Text("\(item.name) · \(item.count)题")
                                    if subject == item.name { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(subject.isEmpty ? "全部题库" : subject)
                                .lineLimit(1)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2.weight(.bold))
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    }
                    .disabled(matching || catalogLoading)
                }
                .padding(16)

                Divider().padding(.leading, 62)

                HStack(spacing: 12) {
                    Image(systemName: "square.grid.2x2.fill")
                        .foregroundStyle(TijingDesign.violet)
                        .frame(width: 34, height: 34)
                        .background(TijingDesign.violet.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    Text("章节")
                        .font(.body.weight(.medium))
                    Spacer()
                    Menu {
                        Button {
                            topic = ""
                        } label: {
                            Label("全部章节", systemImage: topic.isEmpty ? "checkmark" : "square.grid.2x2")
                        }
                        ForEach(selectedSubject?.topics.filter { $0.count > 0 } ?? []) { item in
                            Button {
                                topic = item.topic
                            } label: {
                                HStack {
                                    Text("\(item.topic) · \(item.count)题")
                                    if topic == item.topic { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(subject.isEmpty ? "先选择题库" : (topic.isEmpty ? "全部章节" : topic))
                                .lineLimit(1)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2.weight(.bold))
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(subject.isEmpty ? Color.secondary : Color.primary)
                    }
                    .disabled(subject.isEmpty || matching || catalogLoading)
                }
                .padding(16)
            }
            .tijingCard()

            if catalogLoading {
                HStack(spacing: 9) {
                    ProgressView()
                    Text("正在读取题库…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Label("每局 10 道不重复题目，双方题目与随机选项顺序一致", systemImage: "checkmark.shield")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var secondaryModes: some View {
        VStack(spacing: 12) {
            TijingSectionHeading("换种玩法", subtitle: "好友房与 AI 对战不影响竞点")
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 12) { secondaryModeButtons }
                } else {
                    HStack(spacing: 12) { secondaryModeButtons }
                }
            }
        }
    }


    @ViewBuilder
    private var secondaryModeButtons: some View {
        Button {
            Haptics.medium()
            createAI()
        } label: {
            TijingActionTile(
                title: "AI 对战",
                subtitle: "随时热身",
                systemImage: "cpu.fill",
                tint: TijingDesign.mint
            )
        }
        .buttonStyle(TijingPressableCardStyle())
        .disabled(matching)

        Button {
            Haptics.medium()
            createFriendRoom()
        } label: {
            TijingActionTile(
                title: "好友房",
                subtitle: "创建 6 位房间码",
                systemImage: "person.2.fill",
                tint: TijingDesign.cyan
            )
        }
        .buttonStyle(TijingPressableCardStyle())
        .disabled(matching)
    }

    private var joinRoomCard: some View {
        VStack(spacing: 12) {
            TijingSectionHeading("加入好友房")
            HStack(spacing: 10) {
                TextField("6 位房间码", text: $joinCode)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .onChange(of: joinCode) { _, value in
                        let digits = value.filter(\.isNumber)
                        joinCode = String(digits.prefix(6))
                    }

                Button {
                    Haptics.medium()
                    joinFriendRoom()
                } label: {
                    Image(systemName: "arrow.right")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(TijingDesign.primaryGradient, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(TijingPressableCardStyle())
                .disabled(joinCode.count != 6 || matching)
            }
            .padding(14)
            .tijingCard()
        }
    }

    private func battleBody() -> BattleModeBody {
        BattleModeBody(rule: "speed", subject: subject.isEmpty ? nil : subject, topic: topic.isEmpty ? nil : topic)
    }

    private func startMatch() {
        guard session.token != nil else { error = "请先登录"; return }
        Haptics.medium()
        matching = true
        error = nil
        lastMatchStage = "exact"
        matchStatus = "正在寻找 \(scopeLabel) · 排位赛对手…" + (topic.isEmpty ? "" : "\n（60秒未匹配将自动扩大到本题库全部章节）")
        matchTask = Task { await matchLoop() }
    }

    private func cancelMatch() {
        matching = false
        matchTask?.cancel(); matchTask = nil
        matchStatus = ""
        lastMatchStage = "exact"
        guard let token = session.token else { return }
        Task { let _: EmptyResponse? = try? await session.api.request("/api/matchmaking/cancel", method: .post, body: EmptyBody(), token: token) }
        Haptics.selection()
    }

    @MainActor private func matchLoop() async {
        guard let token = session.token else { return }
        let body = battleBody()
        while !Task.isCancelled && matching {
            do {
                let response: MatchmakingResponse = try await session.api.request("/api/matchmaking/join", method: .post, body: body, token: token)
                if response.status == "error" {
                    matching = false
                    error = response.error ?? "当前题库无法匹配"
                    Haptics.error()
                    return
                }
                if response.status == "matched", let id = response.roomID ?? response.state?.roomID {
                    matching = false
                    matchTask = nil
                    roomID = id
                    matchStatus = ""
                    Haptics.success()
                    return
                }
                let waited = response.waitSeconds ?? 0
                let nextStage = response.matchStage ?? "exact"
                if nextStage != lastMatchStage {
                    lastMatchStage = nextStage
                    Haptics.rigid()
                }
                switch nextStage {
                case "all":
                    matchStatus = "已等待 \(waited) 秒，已扩大到全部题库继续寻找对手…"
                case "subject":
                    matchStatus = "已等待 \(waited) 秒，已扩大到 \(subject.isEmpty ? "当前题库" : subject) 的全部章节继续匹配…"
                default:
                    matchStatus = "正在寻找 \(scopeLabel) · 排位赛对手…" + (topic.isEmpty ? "" : "\n（60秒未匹配将自动扩大到本题库全部章节）")
                }
            } catch let apiError as APIError where apiError.statusCode == 429 {
                let seconds = max(1, apiError.retryAfter ?? 60)
                matchStatus = "连接请求较频繁，已自动降低频率，\(seconds) 秒后继续匹配…"
                try? await Task.sleep(for: .seconds(seconds))
                continue
            } catch {
                matchStatus = "网络有些波动，正在继续匹配…"
            }
            try? await Task.sleep(for: .milliseconds(1500))
        }
    }

    private func createAI() {
        guard let token = session.token else { error = "请先登录"; return }
        Task { @MainActor in
            do {
                let response: BattleCreateResponse = try await session.api.request("/api/battles/ai", method: .post, body: battleBody(), token: token)
                if let id = response.resolvedRoomID { roomID = id; error = nil; Haptics.success() }
                else { error = response.error ?? "创建 AI 对战失败"; Haptics.error() }
            } catch { self.error = error.localizedDescription; Haptics.error() }
        }
    }

    private func createFriendRoom() {
        guard let token = session.token else { error = "请先登录"; return }
        Task { @MainActor in
            do {
                let response: BattleCreateResponse = try await session.api.request("/api/battles/friend/create", method: .post, body: battleBody(), token: token)
                if let id = response.resolvedRoomID {
                    roomID = id
                    error = nil
                    Haptics.success()
                } else {
                    error = response.error ?? "创建好友房失败"
                    Haptics.error()
                }
            } catch { self.error = error.localizedDescription; Haptics.error() }
        }
    }

    private func joinFriendRoom() {
        guard let token = session.token else { error = "请先登录"; return }
        guard joinCode.count == 6 else { error = "请输入 6 位房间号"; return }
        let code = joinCode
        Task { @MainActor in
            do {
                let response: BattleCreateResponse = try await session.api.request("/api/battles/friend/join", method: .post, body: JoinRoomBody(code: code), token: token)
                if let id = response.resolvedRoomID { roomID = id; error = nil; Haptics.success() }
                else { error = response.error ?? "房间不存在"; Haptics.error() }
            } catch { self.error = error.localizedDescription; Haptics.error() }
        }
    }

    @MainActor private func loadCatalog() async {
        guard let token = session.token else { catalogLoading = false; return }
        catalogLoading = true
        defer { catalogLoading = false }
        do {
            let response: PracticeCatalogResponse = try await session.api.request("/api/practice/catalog", token: token)
            catalog = response.subjects
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor private func recoverActiveBattle() async {
        guard let token = session.token else { return }
        if let response: ActiveBattleResponse = try? await session.api.request("/api/battles/active", token: token),
           response.active,
           let id = response.roomID,
           response.state?.waitingOpponent != true,
           response.state?.finished != true {
            roomID = id
        }
    }
}
