import SwiftUI

struct BattleLobbyView: View {
    @Environment(SessionStore.self) private var session
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

    private var selectedSubject: PracticeSubject? { catalog.first { $0.name == subject } }
    private var scopeLabel: String { topic.isEmpty ? (subject.isEmpty ? "全部题库" : subject) : "\(subject) · \(topic)" }

    var body: some View {
        List {
            Section("匹配范围") {
                Picker("题库", selection: $subject) {
                    Text("全部题库").tag("")
                    ForEach(catalog) { item in
                        Text("\(item.name)（\(item.count)题）").tag(item.name)
                    }
                }
                .onChange(of: subject) { _, _ in topic = "" }
                .disabled(matching || catalogLoading)

                Picker("章节", selection: $topic) {
                    Text(subject.isEmpty ? "先选择题库" : "全部章节").tag("")
                    ForEach(selectedSubject?.topics.filter { $0.count > 0 } ?? []) { item in
                        Text("\(item.topic)（\(item.count)题）").tag(item.topic)
                    }
                }
                .disabled(subject.isEmpty || matching || catalogLoading)

                LabeledContent("当前范围") {
                    Text(scopeLabel)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if catalogLoading {
                    HStack {
                        ProgressView()
                        Text("正在读取题库…")
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text("每局随机抽取 10 道不重复题目；同一局双方看到相同的随机选项顺序。")
            }

            Section("排位赛") {
                if matching {
                    HStack(alignment: .top, spacing: 12) {
                        ProgressView()
                            .padding(.top, 2)
                        Text(matchStatus.isEmpty ? "正在匹配对手…" : matchStatus)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Button("取消匹配", role: .destructive) {
                        cancelMatch()
                    }
                } else {
                    Button {
                        startMatch()
                    } label: {
                        Label("开始排位匹配", systemImage: "bolt.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .listRowBackground(Color.clear)
                }
            } footer: {
                Text("10 题抢答，每题 60 秒；先比答对题数，同分再比答对题累计用时。指定章节时，60 秒未匹配会扩大到本题库全部章节，120 秒后再扩大到全部题库。")
            }

            Section("好友与 AI") {
                Button {
                    createAI()
                } label: {
                    Label("与 AI 对战", systemImage: "cpu")
                }
                .disabled(matching)

                Button {
                    createFriendRoom()
                } label: {
                    Label("创建好友房间", systemImage: "person.2.badge.plus")
                }
                .disabled(matching)
            } footer: {
                Text("好友房和 AI 对战不影响竞点。创建好友房时会使用上方当前选择的题库范围。")
            }

            Section("加入好友房") {
                TextField("6 位房间码", text: $joinCode)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .onChange(of: joinCode) { _, value in
                        let digits = value.filter(\.isNumber)
                        joinCode = String(digits.prefix(6))
                    }

                Button("加入房间") {
                    joinFriendRoom()
                }
                .disabled(joinCode.count != 6 || matching)
            }

            if let error {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("对战")
        .navigationBarTitleDisplayMode(.large)
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

    private func battleBody() -> BattleModeBody {
        BattleModeBody(rule: "speed", subject: subject.isEmpty ? nil : subject, topic: topic.isEmpty ? nil : topic)
    }

    private func startMatch() {
        guard session.token != nil else { error = "请先登录"; return }
        Haptics.medium()
        matching = true
        error = nil
        matchStatus = "正在寻找 \(scopeLabel) · 排位赛对手…" + (topic.isEmpty ? "" : "\n（60秒未匹配将自动扩大到本题库全部章节）")
        matchTask = Task { await matchLoop() }
    }

    private func cancelMatch() {
        matching = false
        matchTask?.cancel(); matchTask = nil
        matchStatus = ""
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
                switch response.matchStage {
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
