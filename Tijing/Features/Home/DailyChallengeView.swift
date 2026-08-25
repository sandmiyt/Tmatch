import SwiftUI

struct DailyChallengeView: View {
    @Environment(SessionStore.self) private var session
    let challengeID: String?

    @State private var detail: ChallengeDetail?
    @State private var answers: [Int: Set<Int>] = [:]
    @State private var excluded: [Int: Set<Int>] = [:]
    @State private var index = 0
    @State private var startedAt = Date()
    @State private var busy = false
    @State private var error: String?
    @State private var showingAnswerSheet = false
    @State private var confirmUnanswered = false
    @State private var suppressNextTap = false
    @State private var correctionQuestionID: Int?

    init(challengeID: String? = nil) {
        self.challengeID = challengeID
    }

    var body: some View {
        ZStack {
            TijingPageBackground()
            Group {
            if let detail {
                if let mine = detail.myAttempt {
                    resultView(detail: detail, mine: mine)
                } else if detail.expired {
                    expiredView(detail)
                } else {
                    answerView(detail)
                }
            } else if let error {
                ContentUnavailableView("挑战暂不可用", systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                ProgressView("正在准备挑战…")
            }
            }
        }
        .navigationTitle(detail?.isFriend == true ? "好友挑战" : "今日挑战")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .tijingTabBarHidden()
        .task(id: challengeID) { await load() }
        .sheet(isPresented: $showingAnswerSheet) {
            if let detail { answerSheet(detail) }
        }
        .sheet(item: correctionBinding) { target in
            QuestionCorrectionView(questionID: target.id)
        }
        .confirmationDialog("还有未作答题目", isPresented: $confirmUnanswered, titleVisibility: .visible) {
            Button("仍然提交", role: .destructive) { Task { await submit(force: true) } }
            Button("继续作答", role: .cancel) { }
        } message: {
            Text("未作答题会按错误计算。")
        }
    }

    @ViewBuilder
    private func answerView(_ detail: ChallengeDetail) -> some View {
        let question = detail.questions[index]
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                progressHeader(detail, question: question)

                TijingQuestionToolStrip(
                    isFavorite: question.favorite == true,
                    favoriteAction: {
                        Task { await toggleFavorite(questionID: question.questionID) }
                    },
                    correctionAction: {
                        Haptics.selection()
                        correctionQuestionID = question.questionID
                    },
                    answerSheetAction: {
                        Haptics.selection()
                        showingAnswerSheet = true
                    }
                )

                if let material = question.material, !material.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("材料").font(.caption.bold()).foregroundStyle(.tint)
                        QuestionRichContent(
                            text: material,
                            urls: question.media?.material ?? [],
                            blocks: question.materialBlocks ?? [],
                            style: .material
                        )
                    }
                    .padding(14)
                    .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                QuestionRichContent(
                    text: question.stem,
                    urls: question.media?.stem ?? [],
                    blocks: question.stemBlocks ?? [],
                    style: .stem,
                    tint: TijingDesign.violet
                )
                .textSelection(.disabled)

                VStack(spacing: 10) {
                    ForEach(question.options.indices, id: \.self) { optionIndex in
                        challengeOption(question: question, optionIndex: optionIndex)
                    }
                }

                Label("长按选项可排除，再次长按恢复", systemImage: "hand.tap")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let error { Text(error).font(.footnote).foregroundStyle(.red) }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            challengeBottomBar(detail, question: question)
        }
    }

    private func challengeBottomBar(_ detail: ChallengeDetail, question: ChallengeQuestion) -> some View {
        HStack(spacing: 12) {
            Button {
                guard index > 0 else { return }
                index -= 1
                Haptics.selection()
            } label: {
                Label("上一题", systemImage: "chevron.left")
            }
            .buttonStyle(.bordered)
            .disabled(index == 0)

            Spacer(minLength: 8)

            if index == detail.questions.count - 1 {
                Button {
                    Task { await submit(force: false) }
                } label: {
                    HStack(spacing: 6) {
                        if busy { ProgressView().controlSize(.small) }
                        Text("提交挑战")
                        Image(systemName: "checkmark.seal")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(busy)
            } else {
                Button {
                    index = min(detail.questions.count - 1, index + 1)
                    Haptics.selection()
                } label: {
                    if question.isMultiple {
                        Text("确认答案（已选 \(answers[index]?.count ?? 0) 项）")
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        Label("下一题", systemImage: "chevron.right")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(question.isMultiple && (answers[index]?.isEmpty ?? true))
            }
        }
        .controlSize(.large)
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.regularMaterial)
        .overlay(alignment: .top) { Divider() }
    }

    private func progressHeader(_ detail: ChallengeDetail, question: ChallengeQuestion) -> some View {
        TijingPaperCard(tint: detail.isDaily ? TijingDesign.butter : TijingDesign.lilac) {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 12) {
                    TijingStickerIcon(systemImage: detail.isDaily ? "sun.max.fill" : "person.2.fill", tint: detail.isDaily ? TijingDesign.amber : TijingDesign.violet, background: detail.isDaily ? TijingDesign.butter : TijingDesign.lilac, size: 42, rotation: -5, sparkle: false)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(detail.isDaily ? "今日挑战" : "好友挑战")
                            .font(.headline)
                        Text([question.questionTypeLabel, question.subject, question.topic]
                            .compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    TijingMicroBadge(title: "\(index + 1)/\(detail.questionCount)", systemImage: "circle.grid.3x3.fill", tint: TijingDesign.indigo)
                }
                ProgressView(value: Double(index + 1), total: Double(max(detail.questionCount, 1)))
                    .tint(TijingDesign.indigo)
            }
        }
    }

    private func challengeOption(question: ChallengeQuestion, optionIndex: Int) -> some View {
        let isPicked = answers[index]?.contains(optionIndex) == true
        let isExcluded = excluded[question.questionID]?.contains(optionIndex) == true
        let optionMedia: [String]
        if let values = question.media?.options, values.indices.contains(optionIndex) {
            optionMedia = values[optionIndex]
        } else {
            optionMedia = []
        }
        let optionBlocks: [QuestionContentBlock]
        if let values = question.optionBlocks, values.indices.contains(optionIndex) {
            optionBlocks = values[optionIndex]
        } else {
            optionBlocks = []
        }

        return Button {
            if suppressNextTap { suppressNextTap = false; return }
            guard !isExcluded else { return }
            let currentIndex = index
            if question.isMultiple {
                var selected = answers[currentIndex] ?? []
                if selected.contains(optionIndex) { selected.remove(optionIndex) }
                else { selected.insert(optionIndex) }
                answers[currentIndex] = selected
            } else {
                answers[currentIndex] = [optionIndex]
            }
            Haptics.selection()
            if !question.isMultiple, let detail, currentIndex < detail.questions.count - 1 {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(120))
                    guard index == currentIndex, answers[currentIndex] == Set([optionIndex]) else { return }
                    index = min(detail.questions.count - 1, index + 1)
                }
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Text(TijingFormat.optionLetter(optionIndex))
                    .font(.headline.monospaced())
                    .frame(width: 28, height: 28)
                    .background(isPicked ? Color.accentColor : Color.secondary.opacity(0.12), in: Circle())
                    .foregroundStyle(isPicked ? Color.white : Color.primary)
                VStack(alignment: .leading, spacing: 8) {
                    QuestionRichContent(
                        text: question.options[optionIndex],
                        urls: optionMedia,
                        blocks: optionBlocks,
                        style: .option
                    )
                    .strikethrough(isExcluded)
                    .foregroundStyle(isExcluded ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)
            .background(isPicked ? Color.accentColor.opacity(0.10) : Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 19, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 19, style: .continuous).stroke(isPicked ? Color.accentColor : Color.secondary.opacity(0.16)))
            .shadow(color: isPicked ? Color.clear : Color.black.opacity(0.025), radius: 7, y: 3)
            .opacity(isExcluded ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                suppressNextTap = true
                toggleExcluded(questionID: question.questionID, optionIndex: optionIndex)
            }
        )
        .accessibilityHint(question.isMultiple ? "轻点选择或取消，选好后确认答案；长按可排除或恢复" : "轻点作答，长按可排除或恢复该选项")
    }

    private func resultView(detail: ChallengeDetail, mine: ChallengeAttempt) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                resultHero(detail: detail, mine: mine)

                if detail.isFriend {
                    friendComparison(detail: detail, mine: mine)
                    if detail.creatorAttempt == nil || detail.targetAttempt == nil {
                        waitingCard(detail)
                    }
                } else {
                    HStack {
                        Label("今日已挑战 \(detail.challengerCount ?? 0) 人", systemImage: "person.2")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                        Button("再挑战一次") { retryDaily() }
                            .buttonStyle(.bordered)
                    }
                    dailyRanking(detail)
                }

                if let review = detail.review, !review.isEmpty {
                    reviewSection(review)
                }
                if let error { Text(error).font(.footnote).foregroundStyle(.red) }
            }
            .padding()
        }
    }

    private func resultHero(detail: ChallengeDetail, mine: ChallengeAttempt) -> some View {
        TijingPaperCard(tint: resultTint(detail: detail, mine: mine), rotation: -0.2) {
            HStack(spacing: 16) {
                TijingStickerIcon(systemImage: outcomeSymbol(detail: detail, mine: mine), tint: resultAccent(detail: detail, mine: mine), background: resultTint(detail: detail, mine: mine), size: 60, rotation: -7)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(mine.correctCount)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("/ \(detail.questionCount)")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    if let label = outcomeLabel(detail: detail, mine: mine) {
                        Text(label).font(.headline)
                    }
                    Text("用时 \(TijingFormat.duration(milliseconds: mine.elapsedMS))")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if detail.isFriend {
                        Text("只比较正确数和用时，不影响竞点")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func resultTint(detail: ChallengeDetail, mine: ChallengeAttempt) -> Color {
        guard let label = outcomeLabel(detail: detail, mine: mine) else { return TijingDesign.sky }
        if label.contains("胜") { return TijingDesign.sage }
        if label.contains("负") { return TijingDesign.rose }
        return TijingDesign.butter
    }

    private func resultAccent(detail: ChallengeDetail, mine: ChallengeAttempt) -> Color {
        guard let label = outcomeLabel(detail: detail, mine: mine) else { return TijingDesign.indigo }
        if label.contains("胜") { return TijingDesign.mint }
        if label.contains("负") { return TijingDesign.coral }
        return TijingDesign.amber
    }

    private func friendComparison(detail: ChallengeDetail, mine: ChallengeAttempt) -> some View {
        HStack(spacing: 14) {
            challengePerson(name: detail.creator?.nickname ?? "发起者", attempt: detail.creatorAttempt, fallback: "待完成")
            Image(systemName: "bolt.horizontal.fill").foregroundStyle(.tint)
            challengePerson(name: detail.target?.nickname ?? "好友", attempt: detail.targetAttempt, fallback: detail.expired ? "已过期" : "待应战")
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func challengePerson(name: String, attempt: ChallengeAttempt?, fallback: String) -> some View {
        VStack(spacing: 5) {
            Text(name).font(.subheadline.bold()).lineLimit(1)
            Text(attempt.map { "\($0.correctCount)/10" } ?? fallback)
                .font(.title3.bold())
                .monospacedDigit()
            Text(attempt.map { TijingFormat.duration(milliseconds: $0.elapsedMS) } ?? "--")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func waitingCard(_ detail: ChallengeDetail) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(detail.expired ? "挑战已过期" : "等待好友完成挑战").font(.headline)
                Text(detail.expired ? "结果记录已保留，但另一方不能再正式应战。" : "有效期至 \(TijingFormat.dateTime(detail.expiresAt))")
                    .font(.caption).foregroundStyle(.secondary)
            }
        } icon: { Image(systemName: "clock") }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func dailyRanking(_ detail: ChallengeDetail) -> some View {
        let ranking = Array((detail.ranking ?? []).prefix(20))
        return VStack(alignment: .leading, spacing: 10) {
            Label("今日排行", systemImage: "crown.fill").font(.headline)
            if !ranking.isEmpty {
                ForEach(ranking) { item in
                    HStack {
                        Text("#\(item.position)").font(.caption.bold().monospacedDigit()).frame(width: 34, alignment: .leading)
                        Text(item.nickname ?? "用户").lineLimit(1)
                        Spacer()
                        Text("\(item.correctCount)/10").font(.subheadline.bold().monospacedDigit())
                        Text(TijingFormat.duration(milliseconds: item.elapsedMS)).font(.caption).foregroundStyle(.secondary).frame(minWidth: 54, alignment: .trailing)
                    }
                    .padding(.vertical, 5)
                    if item.id != ranking.last?.id { Divider() }
                }
            } else {
                Text("暂无排行").foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func reviewSection(_ items: [ChallengeReviewItem]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("答案解析").font(.title2.bold())
            ForEach(Array(items.enumerated()), id: \.element.id) { offset, item in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(["第 \(offset + 1) 题", item.questionTypeLabel, item.subject, item.topic]
                            .compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: " · "))
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        Spacer()
                        Text(item.selectedAnswers.isEmpty ? "未作答" : item.correct ? "正确" : "错误")
                            .font(.caption.bold())
                            .foregroundStyle(item.correct ? .green : .red)
                    }
                    if let material = item.material, !material.isEmpty {
                        Text(material).tijingQuestionMaterial().padding(10).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
                    }
                    QuestionMediaStrip(urls: item.media?.material ?? [])
                    Text(item.stem).tijingQuestionStem(compact: true)
                    QuestionMediaStrip(urls: item.media?.stem ?? [])
                    VStack(spacing: 7) {
                        let correctAnswers = Set(item.correctAnswers)
                        let selectedAnswers = Set(item.selectedAnswers)
                        ForEach(item.options.indices, id: \.self) { option in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top, spacing: 9) {
                                    Text(TijingFormat.optionLetter(option)).bold().frame(width: 24)
                                    Text(item.options[option]).frame(maxWidth: .infinity, alignment: .leading)
                                    if correctAnswers.contains(option) { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                                    if selectedAnswers.contains(option) && !correctAnswers.contains(option) { Image(systemName: "xmark.circle.fill").foregroundStyle(.red) }
                                }
                                if let optionMedia = item.media?.options, optionMedia.indices.contains(option) {
                                    QuestionMediaStrip(urls: optionMedia[option], layout: .compact)
                                }
                            }
                            .padding(10)
                            .background(correctAnswers.contains(option) ? Color.green.opacity(0.09) : selectedAnswers.contains(option) ? Color.red.opacity(0.07) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    if let explanation = item.explanation, !explanation.isEmpty {
                        Text(explanation).font(.subheadline).foregroundStyle(.secondary)
                    }
                    QuestionMediaStrip(urls: item.media?.explanation ?? [])
                    HStack {
                        Button {
                            Task { await toggleReviewFavorite(questionID: item.questionID) }
                        } label: { Label(item.favorite == true ? "已收藏" : "收藏", systemImage: item.favorite == true ? "star.fill" : "star") }
                        .buttonStyle(.borderless)
                        Spacer()
                        Button("纠错") { correctionQuestionID = item.questionID }.buttonStyle(.borderless)
                    }
                }
                .padding(15)
                .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.secondary.opacity(0.16)))
            }
        }
    }

    private func expiredView(_ detail: ChallengeDetail) -> some View {
        ContentUnavailableView {
            Label("挑战已过期", systemImage: "clock.badge.exclamationmark")
        } description: {
            Text("48 小时有效期已结束，这条挑战记录仍会保留，但不能再正式应战。")
        }
    }

    private func answerSheet(_ detail: ChallengeDetail) -> some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 10)], spacing: 10) {
                    ForEach(detail.questions.indices, id: \.self) { value in
                        Button {
                            index = value; Haptics.selection(); showingAnswerSheet = false
                        } label: {
                            Text("\(value + 1)")
                                .font(.headline.monospacedDigit())
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(answerSheetColor(value), in: RoundedRectangle(cornerRadius: 11))
                                .overlay(RoundedRectangle(cornerRadius: 11).stroke(value == index ? Color.accentColor : Color.clear, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("答题卡")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { showingAnswerSheet = false } } }
        }
        .presentationDetents([.medium, .large])
    }

    private func answerSheetColor(_ value: Int) -> Color {
        if value == index { return Color.accentColor.opacity(0.16) }
        if answers[value]?.isEmpty == false { return Color.green.opacity(0.12) }
        return Color(uiColor: .secondarySystemBackground)
    }

    @MainActor
    private func load() async {
        guard let token = session.token else { error = "请先登录"; return }
        do {
            let path = challengeID.map { "/api/challenges/\($0)" } ?? "/api/challenges/daily"
            detail = try await session.api.request(path, token: token)
            answers = [:]
            excluded = [:]
            index = 0
            startedAt = Date()
            error = nil
        } catch { self.error = error.localizedDescription }
    }

    @MainActor
    private func submit(force: Bool) async {
        guard let token = session.token, let detail, !busy else { return }
        let unanswered = detail.questions.indices.filter { answers[$0]?.isEmpty != false }.count
        if unanswered > 0 && !force {
            confirmUnanswered = true
            Haptics.warning()
            return
        }
        busy = true; defer { busy = false }
        let mapped = Dictionary(uniqueKeysWithValues: answers.compactMap { key, value -> (String, PickValue)? in
            guard !value.isEmpty else { return nil }
            let sorted = value.sorted()
            return (String(key), detail.questions[key].isMultiple ? .many(sorted) : .one(sorted[0]))
        })
        let elapsed = max(0, Int(Date().timeIntervalSince(startedAt) * 1000))
        do {
            let response: ChallengeDetail = try await session.api.request("/api/challenges/\(detail.challengeID)/submit", method: .post, body: ChallengeSubmitBody(answers: mapped, elapsedMS: elapsed), token: token)
            self.detail = response
            self.error = nil
            Haptics.success()
        } catch { self.error = error.localizedDescription; Haptics.error() }
    }

    private func retryDaily() {
        guard var detail, detail.isDaily else { return }
        detail = ChallengeDetail(
            challengeID: detail.challengeID, kind: detail.kind, dayKey: detail.dayKey, subject: detail.subject, topic: detail.topic,
            expiresAt: detail.expiresAt, expired: detail.expired, questionCount: detail.questionCount, questions: detail.questions,
            myAttempt: nil, submitted: nil, review: nil, ranking: detail.ranking, challengerCount: detail.challengerCount,
            creator: detail.creator, target: detail.target, creatorAttempt: detail.creatorAttempt, targetAttempt: detail.targetAttempt
        )
        self.detail = detail
        answers = [:]; excluded = [:]; index = 0; startedAt = Date(); error = nil
        Haptics.medium()
    }

    private func toggleExcluded(questionID: Int, optionIndex: Int) {
        var set = excluded[questionID] ?? []
        if set.contains(optionIndex) { set.remove(optionIndex) }
        else { set.insert(optionIndex) }
        excluded[questionID] = set
        if var selected = answers[index], selected.remove(optionIndex) != nil {
            if selected.isEmpty { answers.removeValue(forKey: index) }
            else { answers[index] = selected }
        }
        Haptics.light()
    }

    @MainActor
    private func toggleFavorite(questionID: Int) async {
        guard let token = session.token else { return }
        do {
            let response: FavoriteResponse = try await session.api.request("/api/questions/\(questionID)/favorite", method: .post, body: EmptyBody(), token: token)
            guard var detail else { return }
            if let idx = detail.questions.firstIndex(where: { $0.questionID == questionID }) {
                detail.questions[idx].favorite = response.favorite ?? !(detail.questions[idx].favorite ?? false)
            }
            self.detail = detail
            Haptics.selection()
        } catch { self.error = error.localizedDescription; Haptics.error() }
    }

    @MainActor
    private func toggleReviewFavorite(questionID: Int) async {
        guard let token = session.token else { return }
        do {
            let response: FavoriteResponse = try await session.api.request("/api/questions/\(questionID)/favorite", method: .post, body: EmptyBody(), token: token)
            guard var detail, var review = detail.review else { return }
            if let idx = review.firstIndex(where: { $0.questionID == questionID }) {
                review[idx].favorite = response.favorite ?? !(review[idx].favorite ?? false)
            }
            detail.review = review
            self.detail = detail
            Haptics.selection()
        } catch { self.error = error.localizedDescription; Haptics.error() }
    }

    private func outcomeLabel(detail: ChallengeDetail, mine: ChallengeAttempt) -> String? {
        guard detail.isFriend, let other = otherAttempt(detail: detail, mine: mine) else { return nil }
        if mine.correctCount != other.correctCount { return mine.correctCount > other.correctCount ? "挑战胜利" : "挑战失败" }
        if mine.elapsedMS != other.elapsedMS { return mine.elapsedMS < other.elapsedMS ? "挑战胜利" : "挑战失败" }
        return "挑战平局"
    }

    private func outcomeSymbol(detail: ChallengeDetail, mine: ChallengeAttempt) -> String {
        switch outcomeLabel(detail: detail, mine: mine) {
        case "挑战胜利": "trophy.fill"
        case "挑战失败": "shield.slash"
        case "挑战平局": "equal.circle.fill"
        default: "checkmark.seal.fill"
        }
    }

    private func otherAttempt(detail: ChallengeDetail, mine: ChallengeAttempt) -> ChallengeAttempt? {
        guard let creator = detail.creatorAttempt, let target = detail.targetAttempt else { return nil }
        if creator.userID == mine.userID { return target }
        if target.userID == mine.userID { return creator }
        return nil
    }

    private var correctionBinding: Binding<CorrectionRoute?> {
        Binding(
            get: { correctionQuestionID.map(CorrectionRoute.init(id:)) },
            set: { correctionQuestionID = $0?.id }
        )
    }
}

private struct CorrectionRoute: Identifiable { let id: Int }
