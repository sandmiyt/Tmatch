import SwiftUI

struct BattleRoomView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State var store: BattleRoomStore
    @State private var confirmExit = false
    @State private var showRankedEntrance = false
    @State private var rankedEntrancePlayed = false

    var body: some View {
        ZStack {
            TijingPageBackground()
            Group {
            if let state = store.state {
                ScrollView {
                    LazyVStack(spacing: 18) {
                        if state.finished || state.waitingOpponent == true {
                            scoreHeader(state)
                        }
                        if state.finished {
                            finishedCard(state)
                        } else if state.waitingOpponent == true {
                            waitingCard(state)
                        } else if let question = state.question {
                            battleQuestion(question, state: state)
                        } else {
                            ProgressView("正在切换下一题…")
                                .padding(.vertical, 40)
                        }
                        if let networkHint = store.networkHint {
                            Label(networkHint, systemImage: "wifi.exclamationmark")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if let error = store.error {
                            Text(error).font(.footnote).foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding()
                }
            } else if let error = store.error {
                ContentUnavailableView("无法进入对战", systemImage: "wifi.exclamationmark", description: Text(error))
            } else {
                ProgressView("正在连接对战")
            }
            }
        }
        .overlay {
            if showRankedEntrance, let state = store.state, state.mode == "quick" {
                RankedBattleEntranceOverlay(
                    players: state.players,
                    scope: scopeText(state),
                    reduceMotion: reduceMotion
                ) {
                    withAnimation(.easeOut(duration: reduceMotion ? 0.12 : 0.24)) {
                        showRankedEntrance = false
                    }
                }
                .transition(.opacity)
                .zIndex(20)
            }
        }
        .navigationTitle("对战")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(store.state?.finished == false)
        .toolbar {
            if store.state?.finished == false {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("退出", role: .destructive) { confirmExit = true }
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if let state = store.state, !state.finished, state.waitingOpponent != true, state.question != nil {
                compactBattleHeader(state)
            }
        }
        .task {
            await store.connect()
            playRankedEntranceIfNeeded()
        }
        .onChange(of: store.state?.roomID) { _, _ in playRankedEntranceIfNeeded() }
        .onDisappear { store.disconnect() }
        .confirmationDialog(exitDialogTitle, isPresented: $confirmExit, titleVisibility: .visible) {
            if store.state?.waitingOpponent == true {
                Button("退出房间", role: .destructive) {
                    Task { if await store.leaveWaitingRoom() { dismiss() } }
                }
            } else {
                Button("退出并判负", role: .destructive) { Task { await store.forfeit() } }
            }
            Button("继续对战", role: .cancel) { }
        } message: {
            Text(store.state?.waitingOpponent == true ? "好友尚未加入，退出等待房不会产生对战结果。" : "正在进行的排位退出会按服务器现有规则判负。")
        }
    }

    private var exitDialogTitle: String {
        store.state?.waitingOpponent == true ? "退出好友房？" : "确定退出当前对战？"
    }

    private func compactBattleHeader(_ state: BattleState) -> some View {
        HStack(spacing: 10) {
            if let me = myPlayer(state) {
                compactPlayer(me, leading: true)
            }

            Spacer(minLength: 2)

            VStack(spacing: 2) {
                Text("\(state.questionIndex + 1)/\(state.total)")
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)

                if let seconds = state.roundSecondsLeft ?? state.secondsLeft {
                    Label("\(seconds)s", systemImage: "timer")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(seconds <= 10 ? Color.red : .primary)
                        .contentTransition(.numericText())
                }
            }
            .frame(minWidth: 52)

            Spacer(minLength: 2)

            if let me = myPlayer(state), let opponent = state.players.first(where: { $0.id != me.id }) {
                compactPlayer(opponent, leading: false)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) { Divider() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(compactScoreAccessibility(state))
    }

    private func compactPlayer(_ player: BattlePlayer, leading: Bool) -> some View {
        HStack(spacing: 7) {
            if !leading { compactPlayerText(player, alignment: .trailing) }
            RemoteAvatar(urlString: player.avatarURL, name: player.nickname, size: 31)
            if leading { compactPlayerText(player, alignment: .leading) }
        }
        .frame(maxWidth: .infinity, alignment: leading ? .leading : .trailing)
    }

    private func compactPlayerText(_ player: BattlePlayer, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(player.nickname)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            HStack(spacing: 4) {
                Text((player.rank?.isEmpty == false ? player.rank : nil) ?? "未定级")
                    .lineLimit(1)
                Text("·")
                Text("已做对 \(player.correct)")
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.68)
        }
    }

    private func compactScoreAccessibility(_ state: BattleState) -> String {
        let players = state.players.map { player in
            "\(player.nickname)，\(player.rank ?? "未定级")，已做对 \(player.correct) 题"
        }.joined(separator: "；")
        return "第 \(state.questionIndex + 1) 题，共 \(state.total) 题；\(players)"
    }

    private func scoreHeader(_ state: BattleState) -> some View {
        HStack(spacing: 10) {
            ForEach(state.players) { player in
                VStack(spacing: 6) {
                    RemoteAvatar(urlString: player.avatarURL, name: player.nickname, size: 46)
                    Text(player.nickname)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    if let rank = player.rank, !rank.isEmpty {
                        Text(rank)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Text("\(player.correct)").font(.title2.bold().monospacedDigit())
                    Text("已做对").font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(TijingDesign.sky.opacity(0.22), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.primary.opacity(0.05)) }
    }

    private func waitingCard(_ state: BattleState) -> some View {
        VStack(spacing: 14) {
            ProgressView()
            Text("好友房已创建").font(.headline)
            if let code = state.joinCode {
                Text(code)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .textSelection(.enabled)
            }
            Text("\(scopeText(state)) · 等好友输入房间号后自动开局。")
                .font(.footnote).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("退出房间", role: .destructive) { confirmExit = true }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private func battleQuestion(_ question: Question, state: BattleState) -> some View {
        let options = question.cleanedOptions
        return VStack(alignment: .leading, spacing: 16) {
            TijingPaperCard(tint: TijingDesign.sky) {
                HStack(spacing: 12) {
                    TijingStickerIcon(systemImage: "bolt.fill", tint: TijingDesign.indigo, background: TijingDesign.sky, size: 42, rotation: -6, sparkle: false)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("第 \(state.questionIndex + 1) / \(state.total) 题")
                            .font(.headline)
                        Text([question.subject, question.topic].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
            }

            if let material = question.material, !material.isEmpty {
                TijingPaperCard(tint: TijingDesign.butter) {
                    VStack(alignment: .leading, spacing: 9) {
                        Label("材料", systemImage: "doc.text.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(TijingDesign.amber)
                        Text(material).tijingQuestionMaterial()
                        QuestionMediaStrip(urls: question.media?.material ?? [])
                    }
                }
            }
            TijingQuestionStemBlock(text: question.stem, tint: TijingDesign.violet)
            QuestionMediaStrip(urls: question.media?.stem ?? [])

            ForEach(options.indices, id: \.self) { index in
                let isExcluded = store.excluded.contains(index)
                let isLocked = state.myFeedback != nil || store.selected != nil

                HStack(alignment: .top, spacing: 12) {
                    Text(TijingFormat.optionLetter(index))
                        .font(.subheadline.bold())
                        .foregroundStyle(isExcluded ? .secondary : .primary)
                        .frame(width: 28, height: 28)
                        .background(.secondary.opacity(isExcluded ? 0.07 : 0.12), in: Circle())
                    VStack(alignment: .leading, spacing: 7) {
                        Text(options[index])
                            .font(.body)
                            .fontWeight(.regular)
                            .lineSpacing(3)
                            .foregroundStyle(isExcluded ? .secondary : .primary)
                            .strikethrough(isExcluded)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                        if let mediaOptions = question.media?.options, index < mediaOptions.count {
                            QuestionMediaStrip(urls: mediaOptions[index])
                                .opacity(isExcluded ? 0.48 : 1)
                        }
                    }
                    if isExcluded, state.myFeedback == nil {
                        Image(systemName: "minus.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(14)
                .background(battleOptionBackground(index, state: state), in: RoundedRectangle(cornerRadius: 19, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 19, style: .continuous).stroke(battleOptionBorder(index, state: state), lineWidth: 1))
                .shadow(color: state.myFeedback == nil && store.selected == nil && !isExcluded ? Color.black.opacity(0.025) : Color.clear, radius: 7, y: 3)
                .contentShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                .scaleEffect(isExcluded ? 0.992 : 1)
                .animation(.spring(response: 0.28, dampingFraction: 0.84), value: isExcluded)
                .onTapGesture {
                    guard !isLocked, !isExcluded else { return }
                    Task { await store.answer(index) }
                }
                .onLongPressGesture(minimumDuration: 0.42) {
                    guard state.mode == "quick", !isLocked else { return }
                    store.toggleExcluded(index)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityHint(state.mode == "quick" ? (isExcluded ? "长按恢复该选项" : "轻点作答，长按排除该选项") : "轻点作答")
            }

            if let feedback = state.myFeedback {
                Label(
                    feedback.correct ? "本题答对 +1题" : "本题未得分 · 正确答案 \(TijingFormat.optionLetter(feedback.answer))",
                    systemImage: feedback.correct ? "checkmark.circle.fill" : "xmark.circle.fill"
                )
                .font(.headline)
                .foregroundStyle(feedback.correct ? Color.green : Color.red)
                if let explanation = feedback.explanation, !explanation.isEmpty {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("答案解析").font(.subheadline.bold())
                        Text(explanation).font(.subheadline).foregroundStyle(.secondary)
                        QuestionMediaStrip(urls: question.media?.explanation ?? [])
                    }
                    .padding(13)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
            }
        }
    }

    private func battleOptionBackground(_ index: Int, state: BattleState) -> Color {
        guard let feedback = state.myFeedback else {
            if store.excluded.contains(index) { return Color.secondary.opacity(0.055) }
            return store.selected == index ? Color.accentColor.opacity(0.10) : Color(uiColor: .secondarySystemGroupedBackground)
        }
        if index == feedback.answer { return Color.green.opacity(0.12) }
        if index == feedback.picked && !feedback.correct { return Color.red.opacity(0.10) }
        return Color(uiColor: .secondarySystemGroupedBackground)
    }

    private func battleOptionBorder(_ index: Int, state: BattleState) -> Color {
        guard let feedback = state.myFeedback else {
            if store.excluded.contains(index) { return .secondary.opacity(0.14) }
            return store.selected == index ? .accentColor : .secondary.opacity(0.25)
        }
        if index == feedback.answer { return .green }
        if index == feedback.picked && !feedback.correct { return .red }
        return .secondary.opacity(0.2)
    }

    private func finishedCard(_ state: BattleState) -> some View {
        let me = myPlayer(state)
        let opponent = state.players.first { $0.id != me?.id }
        return VStack(spacing: 16) {
            VStack(spacing: 12) {
                Image(systemName: outcomeIcon(state.outcome))
                    .font(.system(size: 48))
                    .foregroundStyle(outcomeColor(state.outcome))
                Text(outcomeTitle(state.outcome)).font(.largeTitle.bold())

                if let me, let opponent {
                    HStack(spacing: 16) {
                        finalPlayer(me)
                        VStack(spacing: 0) {
                            Text("\(me.correct) : \(opponent.correct)")
                                .font(.title2.bold()).monospacedDigit()
                            Text("答对题数").font(.caption2).foregroundStyle(.secondary)
                        }
                        finalPlayer(opponent)
                    }
                }

                resultRuleMessage(state, me: me)

                Button("完成") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(outcomeTint(state.outcome).opacity(0.20), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(outcomeColor(state.outcome).opacity(0.14)) }

            if let review = store.review {
                battleReviewPanel(review)
            } else {
                HStack { ProgressView(); Text("正在生成本局复盘…").foregroundStyle(.secondary) }
                    .font(.footnote)
            }
        }
    }

    private func outcomeTint(_ outcome: String?) -> Color {
        let value = (outcome ?? "").lowercased()
        if value.contains("win") || value.contains("victory") { return TijingDesign.sage }
        if value.contains("lose") || value.contains("loss") { return TijingDesign.rose }
        return TijingDesign.sky
    }

    private func finalPlayer(_ player: BattlePlayer) -> some View {
        VStack(spacing: 5) {
            RemoteAvatar(urlString: player.avatarURL, name: player.nickname, size: 48)
            Text(player.nickname).font(.caption.bold()).lineLimit(1).minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func resultRuleMessage(_ state: BattleState, me: BattlePlayer?) -> some View {
        if state.mode == "friend" {
            Text("房间对战不影响竞点").font(.subheadline).foregroundStyle(.secondary)
        } else if state.mode == "ai" {
            Text("AI练习不影响竞点").font(.subheadline).foregroundStyle(.secondary)
        } else if let forfeitedBy = state.forfeitedBy {
            if forfeitedBy == session.user?.id {
                Text("主动退出，本局判负并扣除竞点").font(.subheadline).foregroundStyle(.red)
            } else {
                Text("对手主动退出，本局判胜 · 不增加竞点").font(.subheadline).foregroundStyle(.secondary)
            }
        } else if let delta = me?.ratingDelta {
            HStack(spacing: 5) {
                Text(delta >= 0 ? "+\(delta)" : "\(delta)").font(.title3.bold()).monospacedDigit()
                Text("竞点 · \(me?.rank ?? "")").font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private func battleReviewPanel(_ review: BattleReview) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Label("本局复盘 · 为什么赢 / 为什么输", systemImage: "chart.line.uptrend.xyaxis")
                .font(.headline)
            Text(review.reason).font(.subheadline).foregroundStyle(.secondary)

            HStack(spacing: 10) {
                reviewMetric("\(review.myAccuracy)%", "我的正确率", "对手 \(review.opponentAccuracy)%", icon: "target")
                let mySpeed = review.myAvgElapsedMS ?? review.myAvgCorrectElapsedMS
                let opponentSpeed = review.opponentAvgElapsedMS ?? review.opponentAvgCorrectElapsedMS
                reviewMetric(reviewSeconds(mySpeed), "平均答题速度", "对手 \(reviewSeconds(opponentSpeed))", icon: "clock")
            }

            if !review.keyRounds.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("关键回合").font(.subheadline.bold())
                    ForEach(review.keyRounds) { round in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(highlightLabel(round)).font(.caption.bold()).foregroundStyle(.tint)
                                Spacer()
                                Text("第 \(round.questionIndex + 1) 题").font(.caption.bold()).monospacedDigit()
                            }
                            Text([round.subject, round.topic].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.caption2).foregroundStyle(.secondary)
                            Text(round.detail).font(.subheadline)
                            if let stem = round.stem, !stem.isEmpty {
                                Text(stem).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                        }
                        .padding(11)
                        .background(Color(uiColor: .tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }

            if !review.weakSubjects.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "scope")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(TijingDesign.coral)
                            .frame(width: 28, height: 28)
                            .background(TijingDesign.rose.opacity(0.28), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("本局薄弱模块")
                                .font(.subheadline.bold())
                            Text("按本局错题占比整理")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    ForEach(review.weakSubjects) { item in
                        battleWeakSubjectRow(item)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func battleWeakSubjectRow(_ item: BattleReviewWeakSubject) -> some View {
        let ratio = item.total > 0 ? min(max(Double(item.wrong) / Double(item.total), 0), 1) : 0
        let rate = item.wrongRate ?? Int((ratio * 100).rounded())
        let tint: Color = rate >= 67 ? TijingDesign.coral : (rate >= 34 ? TijingDesign.amber : TijingDesign.indigo)
        let status = rate >= 67 ? "优先回看" : (rate >= 34 ? "需要巩固" : "轻度失分")

        return VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                Image(systemName: battleWeakSubjectIcon(item.subject))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.subject)
                        .font(.subheadline.weight(.semibold))
                    Text("\(item.wrong) 错 · 共 \(item.total) 题 · \(status)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Text("\(rate)%")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(tint)
            }

            ProgressView(value: ratio)
                .tint(tint)
                .scaleEffect(x: 1, y: 0.78, anchor: .center)
        }
        .padding(11)
        .background(Color(uiColor: .tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(tint.opacity(0.08))
        }
    }

    private func battleWeakSubjectIcon(_ name: String) -> String {
        if name.contains("法律") { return "building.columns.fill" }
        if name.contains("政治") { return "flag.fill" }
        if name.contains("经济") { return "chart.line.uptrend.xyaxis" }
        if name.contains("公文") { return "doc.text.fill" }
        if name.contains("数量") { return "function" }
        if name.contains("判断") { return "square.grid.2x2.fill" }
        if name.contains("资料") { return "chart.bar.fill" }
        if name.contains("科技") || name.contains("地理") { return "globe.asia.australia.fill" }
        return "book.closed.fill"
    }

    private func reviewMetric(_ value: String, _ title: String, _ detail: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon).foregroundStyle(.tint)
            Text(value).font(.headline).monospacedDigit()
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(uiColor: .tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func reviewSeconds(_ milliseconds: Int?) -> String {
        guard let milliseconds, milliseconds > 0 else { return "--" }
        return "\(max(1, Int((Double(milliseconds) / 1000).rounded())))秒"
    }

    private func highlightLabel(_ round: BattleReviewRound) -> String {
        let english: [String: String] = [
            "first_blood": "First Blood", "shutdown": "Shutdown", "clutch": "Clutch",
            "final_blow": "Final Blow", "speed_demon": "Speed Demon", "photo_finish": "Photo Finish",
            "match_point": "Match Point"
        ]
        if let kind = round.kind, let value = english[kind] { return value }
        return round.label.flatMap { $0.isEmpty ? nil : $0 } ?? "关键回合"
    }

    private func playRankedEntranceIfNeeded() {
        guard !rankedEntrancePlayed, let state = store.state else { return }
        guard state.mode == "quick", state.waitingOpponent != true, !state.finished, state.players.count >= 2 else { return }
        rankedEntrancePlayed = true
        showRankedEntrance = true
        Haptics.medium()
    }

    private func myPlayer(_ state: BattleState) -> BattlePlayer? {
        guard let userID = session.user?.id else { return state.players.first }
        return state.players.first { $0.id == userID }
    }

    private func scopeText(_ state: BattleState) -> String {
        if let topic = state.topic, !topic.isEmpty, let subject = state.subject, !subject.isEmpty { return "\(subject) · \(topic)" }
        if let subject = state.subject, !subject.isEmpty { return subject }
        return "全部题库"
    }

    private func outcomeTitle(_ outcome: String?) -> String {
        switch outcome { case "win": "胜利"; case "loss": "失败"; default: "平局" }
    }
    private func outcomeIcon(_ outcome: String?) -> String {
        switch outcome { case "win": "trophy.fill"; case "loss": "flag.checkered"; default: "equal.circle.fill" }
    }
    private func outcomeColor(_ outcome: String?) -> Color {
        switch outcome { case "win": .yellow; case "loss": .secondary; default: .accentColor }
    }
}


private struct RankedBattleEntranceOverlay: View {
    let players: [BattlePlayer]
    let scope: String
    let reduceMotion: Bool
    let onFinished: () -> Void

    @State private var reveal = false
    @State private var leaving = false

    var body: some View {
        VStack {
            HStack(spacing: 12) {
                player(players.first, leading: true)

                VStack(spacing: 2) {
                    Text("排位已匹配")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("VS")
                        .font(.system(.headline, design: .rounded, weight: .heavy))
                        .foregroundStyle(TijingDesign.indigo)
                    Text(scope)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                .frame(maxWidth: 96)

                player(players.dropFirst().first, leading: false)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 11)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06))
            }
            .shadow(color: Color.black.opacity(0.08), radius: 18, y: 8)
            .padding(.horizontal, 20)
            .offset(y: reveal ? 0 : -28)
            .scaleEffect(reveal ? 1 : 0.96)
            .opacity(leaving ? 0 : (reveal ? 1 : 0))

            Spacer()
        }
        .padding(.top, 8)
        .allowsHitTesting(false)
        .task {
            if reduceMotion {
                reveal = true
                try? await Task.sleep(for: .milliseconds(360))
                leaving = true
                try? await Task.sleep(for: .milliseconds(100))
                onFinished()
                return
            }

            withAnimation(.spring(response: 0.46, dampingFraction: 0.78)) {
                reveal = true
            }
            try? await Task.sleep(for: .milliseconds(760))
            withAnimation(.easeInOut(duration: 0.22)) {
                leaving = true
            }
            try? await Task.sleep(for: .milliseconds(200))
            onFinished()
        }
    }

    @ViewBuilder
    private func player(_ player: BattlePlayer?, leading: Bool) -> some View {
        HStack(spacing: 8) {
            if !leading { playerText(player) }
            if let player {
                RemoteAvatar(urlString: player.avatarURL, name: player.nickname, size: 42)
                    .overlay { Circle().strokeBorder(Color.white.opacity(0.72), lineWidth: 1.5) }
            } else {
                Circle().fill(.secondary.opacity(0.10)).frame(width: 42, height: 42)
            }
            if leading { playerText(player) }
        }
        .frame(maxWidth: .infinity, alignment: leading ? .leading : .trailing)
    }

    private func playerText(_ player: BattlePlayer?) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(player?.nickname ?? "对手")
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            if let rank = player?.rank, !rank.isEmpty {
                Text(rank)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
