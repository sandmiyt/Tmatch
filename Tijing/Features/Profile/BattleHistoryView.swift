import SwiftUI

struct BattleHistoryView: View {
    @Environment(SessionStore.self) private var session
    @State private var items: [BattleHistoryItem] = []
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        Group {
            if loading && items.isEmpty {
                ProgressView("正在加载战绩…")
            } else if items.isEmpty {
                ContentUnavailableView("暂无排位战绩", systemImage: "clock.arrow.circlepath", description: Text(error ?? "完成排位对战后会出现在这里"))
            } else {
                List {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    NavigationLink {
                        BattleHistoryDetailView(recordID: item.id)
                    } label: {
                        HStack(spacing: 13) {
                            TijingStickerIcon(
                                systemImage: item.draw ? "equal.circle.fill" : (item.won ? "trophy.fill" : "flag.checkered"),
                                tint: item.draw ? .secondary : (item.won ? TijingDesign.mint : TijingDesign.coral),
                                background: item.draw ? TijingDesign.sky : (item.won ? TijingDesign.sage : TijingDesign.rose),
                                size: 42,
                                rotation: item.won ? -5 : 5,
                                sparkle: item.won
                            )

                            VStack(alignment: .leading, spacing: 5) {
                                Text("VS \(item.opponent)")
                                    .font(.headline)
                                Text("\(TijingFormat.dateTime(item.createdAt)) · 10题抢答")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 8)

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("\(item.correctCount) : \(item.opponentCorrectCount)")
                                    .font(.headline.monospacedDigit())
                                Text(item.draw ? "平局" : (item.won ? "胜利" : "失败"))
                                    .font(.caption.bold())
                                    .foregroundStyle(item.draw ? .secondary : (item.won ? Color.green : Color.red))
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .listRowBackground(Color.clear)
                    .tijingReveal(order: min(index, 8))
                }
                }
                .scrollContentBackground(.hidden)
                .background(TijingPageBackground())
                .animation(.spring(response: 0.40, dampingFraction: 0.86), value: items.map(\.id))
            }
        }
        .navigationTitle("排位战绩")
        .refreshable { await load() }
        .task { await load() }
    }


    @MainActor private func load() async {
        guard let token = session.token else { return }
        let cacheKey = session.userCacheKey("battle.history.quick")
        if items.isEmpty, let cached: [BattleHistoryItem] = session.api.cachedResponse(for: cacheKey) {
            items = cached
        }
        loading = items.isEmpty
        defer { loading = false }
        do {
            items = try await session.api.requestCached(
                "/api/battles/history",
                token: token,
                query: [URLQueryItem(name: "mode", value: "quick")],
                cacheKey: cacheKey
            )
            error = nil
        } catch {
            self.error = items.isEmpty ? error.localizedDescription : nil
        }
    }
}

private struct BattleHistoryDetailView: View {
    @Environment(SessionStore.self) private var session
    let recordID: Int
    @State private var detail: BattleHistoryDetail?
    @State private var loading = false
    @State private var error: String?
    @State private var correctionTarget: CorrectionTarget?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if loading && detail == nil {
                        ProgressView("正在读取对局详情…")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 48)
                    } else if let detail {
                        summary(detail)

                        if let review = detail.review {
                            HistoryBattleReviewPanel(review: review) { index in
                                withAnimation(.easeInOut) {
                                    proxy.scrollTo("history-question-\(index)", anchor: .top)
                                }
                            }
                        }

                        if detail.legacy {
                            ContentUnavailableView(
                                "旧版本战绩",
                                systemImage: "archivebox",
                                description: Text("这条战绩产生时还没有保存逐题详情；新产生的排位战绩会完整记录每一道题。")
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                        } else {
                            ForEach(Array(detail.details.enumerated()), id: \.element.id) { offset, item in
                                questionCard(item, number: offset + 1)
                                    .id("history-question-\(item.questionIndex)")
                            }
                        }
                    } else {
                        ContentUnavailableView("无法读取对局详情", systemImage: "exclamationmark.triangle", description: Text(error ?? "稍后再试"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 42)
                    }

                    if detail != nil, let error {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding()
                .padding(.bottom, 18)
            }
        }
        .navigationTitle("对局详情")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $correctionTarget) { target in
            QuestionCorrectionView(questionID: target.id)
        }
    }

    private func summary(_ detail: BattleHistoryDetail) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(detail.draw ? "平局" : (detail.won ? "胜利" : "失败"))
                        .font(.title2.bold())
                        .foregroundStyle(detail.draw ? .secondary : (detail.won ? Color.green : Color.red))
                    Text("对手 \(detail.opponent) · \(TijingFormat.dateTime(detail.createdAt))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(detail.correctCount) : \(detail.opponentCorrectCount)")
                    .font(.title2.bold().monospacedDigit())
            }

            HStack(spacing: 10) {
                historyMetric("\(detail.correctCount)", title: "我答对")
                historyMetric("\(detail.opponentCorrectCount)", title: "对手答对")
                historyMetric(ratingText(detail.ratingDelta), title: "竞点变化")
            }
        }
        .padding(18)
        .background(resultTint(detail).opacity(0.18), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(resultTint(detail).opacity(0.16)) }
    }

    private func resultTint(_ detail: BattleHistoryDetail) -> Color {
        if detail.draw { return TijingDesign.sky }
        return detail.won ? TijingDesign.sage : TijingDesign.rose
    }

    private func historyMetric(_ value: String, title: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.headline.monospacedDigit())
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(uiColor: .tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private func questionCard(_ item: BattleHistoryQuestion, number: Int) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 11) {
                TijingStickerIcon(systemImage: item.correct ? "checkmark.circle.fill" : "xmark.circle.fill", tint: item.correct ? TijingDesign.mint : TijingDesign.coral, background: item.correct ? TijingDesign.sage : TijingDesign.rose, size: 38, rotation: -4, sparkle: false)
                VStack(alignment: .leading, spacing: 3) {
                    Text("第 \(number) 题")
                        .font(.headline)
                    Text([item.subject, item.topic].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(item.answered ? (item.correct ? "正确" : "错误") : "未作答")
                    .font(.caption.bold())
                    .foregroundStyle(item.answered ? (item.correct ? Color.green : Color.red) : .secondary)
            }

            HStack(spacing: 10) {
                Button {
                    correctionTarget = CorrectionTarget(id: item.questionID)
                    Haptics.selection()
                } label: {
                    Label("纠错", systemImage: "exclamationmark.bubble")
                }
                .buttonStyle(.bordered)

                Button {
                    toggleFavorite(item.questionID)
                } label: {
                    Label(item.favorite ? "已收藏" : "收藏", systemImage: item.favorite ? "heart.fill" : "heart")
                }
                .buttonStyle(.bordered)
            }
            .font(.caption)

            if !item.material.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !(item.media?.material ?? []).isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Text("材料").font(.caption.bold()).foregroundStyle(.secondary)
                    if !item.material.isEmpty { Text(item.material).font(.subheadline) }
                    QuestionMediaStrip(urls: item.media?.material ?? [])
                }
                .padding(11)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Text(item.stem)
                .font(.body.weight(.semibold))
            QuestionMediaStrip(urls: item.media?.stem ?? [])

            let options = Question.cleanOptionLabels(item.options)
            let optionMedia = item.media?.options ?? []
            VStack(spacing: 9) {
                ForEach(options.indices, id: \.self) { index in
                    let isAnswer = index == item.answer
                    let isPickedWrong = item.answered && index == item.picked && !isAnswer
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 10) {
                            Text(TijingFormat.optionLetter(index))
                                .font(.caption.bold())
                                .frame(width: 28, height: 28)
                                .background(optionColor(isAnswer: isAnswer, isPickedWrong: isPickedWrong).opacity(0.14), in: Circle())
                            Text(options[index])
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if optionMedia.indices.contains(index) {
                            QuestionMediaStrip(urls: optionMedia[index])
                        }
                    }
                    .padding(11)
                    .background(optionColor(isAnswer: isAnswer, isPickedWrong: isPickedWrong).opacity(isAnswer || isPickedWrong ? 0.09 : 0), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(optionColor(isAnswer: isAnswer, isPickedWrong: isPickedWrong).opacity(isAnswer || isPickedWrong ? 0.45 : 0.12), lineWidth: 0.8))
                }
            }

            HStack(spacing: 12) {
                Text("我的答案：\(answerLetter(item.answered ? item.picked : nil))")
                Text("正确答案：\(answerLetter(item.answer))")
                if let elapsed = item.elapsedMS {
                    Text("用时：\(max(1, Int((Double(elapsed) / 1000).rounded())))秒")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if !item.explanation.isEmpty || !(item.media?.explanation ?? []).isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("解析").font(.subheadline.bold())
                    if !item.explanation.isEmpty { Text(item.explanation).font(.subheadline) }
                    QuestionMediaStrip(urls: item.media?.explanation ?? [])
                }
                .padding(12)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(15)
        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.secondary.opacity(0.18), lineWidth: 0.6))
    }

    private func optionColor(isAnswer: Bool, isPickedWrong: Bool) -> Color {
        if isAnswer { return .green }
        if isPickedWrong { return .red }
        return .secondary
    }

    private func answerLetter(_ index: Int?) -> String {
        guard let index, index >= 0, index < 26 else { return "未作答" }
        return TijingFormat.optionLetter(index)
    }

    private func ratingText(_ delta: Int?) -> String {
        let value = delta ?? 0
        return value > 0 ? "+\(value)" : "\(value)"
    }

    private func toggleFavorite(_ questionID: Int) {
        guard let token = session.token else { return }
        Task { @MainActor in
            do {
                let response: FavoriteResponse = try await session.api.request("/api/questions/\(questionID)/favorite", method: .post, body: EmptyBody(), token: token)
                guard let favorite = response.favorite, var value = detail else { return }
                if let index = value.details.firstIndex(where: { $0.questionID == questionID }) {
                    value.details[index].favorite = favorite
                    detail = value
                }
                session.api.removeCachedResponse(for: session.userCacheKey("battle.history.detail.\(recordID)"))
                Haptics.selection()
            } catch {
                self.error = error.localizedDescription
                Haptics.error()
            }
        }
    }

    @MainActor private func load() async {
        guard let token = session.token else { return }
        let cacheKey = session.userCacheKey("battle.history.detail.\(recordID)")
        if detail == nil { detail = session.api.cachedResponse(for: cacheKey) }
        loading = detail == nil
        defer { loading = false }
        do {
            detail = try await session.api.requestCached(
                "/api/battles/history/\(recordID)", token: token, cacheKey: cacheKey
            )
            error = nil
        } catch {
            self.error = detail == nil ? error.localizedDescription : nil
        }
    }
}

private struct HistoryBattleReviewPanel: View {
    let review: BattleReview
    let onRoundTap: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("本局复盘 · 为什么赢 / 为什么输", systemImage: "chart.line.uptrend.xyaxis")
                .font(.headline)
            Text(review.reason)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                metric("\(review.myAccuracy)%", "我的正确率", "对手 \(review.opponentAccuracy)%")
                metric(seconds(review.myAvgElapsedMS ?? review.myAvgCorrectElapsedMS), "平均答题速度", "对手 \(seconds(review.opponentAvgElapsedMS ?? review.opponentAvgCorrectElapsedMS))")
            }

            if !review.keyRounds.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("关键回合").font(.subheadline.bold())
                    ForEach(review.keyRounds) { round in
                        keyRoundRow(round)
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
                        weakSubjectRow(item)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func weakSubjectRow(_ item: BattleReviewWeakSubject) -> some View {
        let ratio = item.total > 0 ? min(max(Double(item.wrong) / Double(item.total), 0), 1) : 0
        let rate = item.wrongRate ?? Int((ratio * 100).rounded())
        let tint: Color = rate >= 67 ? TijingDesign.coral : (rate >= 34 ? TijingDesign.amber : TijingDesign.indigo)
        let status = rate >= 67 ? "优先回看" : (rate >= 34 ? "需要巩固" : "轻度失分")

        return VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                Image(systemName: weakSubjectIcon(item.subject))
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

    private func weakSubjectIcon(_ name: String) -> String {
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

    private func keyRoundRow(_ round: BattleReviewRound) -> some View {
        let style = roundStyle(round)
        return Button {
            onRoundTap(round.questionIndex)
            Haptics.selection()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: style.icon)
                            .font(.caption.weight(.bold))
                        Text(style.title)
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(style.tint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(style.tint.opacity(0.11), in: Capsule())

                    Spacer(minLength: 8)

                    Text("第 \(round.questionIndex + 1) 题")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)

                    Image(systemName: "chevron.right")
                        .font(.caption2.bold())
                        .foregroundStyle(.tertiary)
                }

                Text(round.detail)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                if let stem = round.stem, !stem.isEmpty {
                    Text(stem)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(13)
            .background(style.tint.opacity(0.055), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(style.tint.opacity(0.11))
            }
        }
        .buttonStyle(TijingPressableCardStyle())
    }

    private func metric(_ value: String, _ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.headline.monospacedDigit())
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(uiColor: .tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    private func seconds(_ milliseconds: Int?) -> String {
        guard let milliseconds, milliseconds > 0 else { return "--" }
        return "\(max(1, Int((Double(milliseconds) / 1000).rounded())))秒"
    }

    private func roundStyle(_ round: BattleReviewRound) -> (title: String, icon: String, tint: Color) {
        switch round.kind {
        case "first_blood": return ("先手拿分", "sparkles", TijingDesign.cyan)
        case "shutdown": return ("止住失分", "hand.raised.fill", TijingDesign.violet)
        case "clutch": return ("关键拿分", "bolt.fill", TijingDesign.coral)
        case "final_blow": return ("终局定胜", "flag.checkered", TijingDesign.indigo)
        case "speed_demon": return ("极速作答", "timer", TijingDesign.mint)
        case "photo_finish": return ("毫厘胜负", "scope", TijingDesign.amber)
        case "match_point": return ("赛点", "target", TijingDesign.coral)
        default:
            let title = round.label.flatMap { $0.isEmpty ? nil : $0 } ?? "关键回合"
            return (title, "sparkle", TijingDesign.indigo)
        }
    }
}

private struct BattleHistoryItem: Decodable, Identifiable {
    let id: Int
    let roomID: String
    let mode: String
    let rule: String
    let opponent: String
    let score: Int
    let opponentScore: Int
    let correctCount: Int
    let opponentCorrectCount: Int
    let won: Bool
    let draw: Bool
    let ratingDelta: Int?
    let hasDetails: Bool?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, mode, rule, opponent, score, won, draw
        case roomID = "room_id"
        case opponentScore = "opponent_score"
        case correctCount = "correct_count"
        case opponentCorrectCount = "opponent_correct_count"
        case ratingDelta = "rating_delta"
        case hasDetails = "has_details"
        case createdAt = "created_at"
    }
}

private struct BattleHistoryDetail: Decodable {
    let id: Int
    let roomID: String
    let mode: String
    let rule: String
    let opponent: String
    let correctCount: Int
    let opponentCorrectCount: Int
    let won: Bool
    let draw: Bool
    let ratingDelta: Int?
    let createdAt: String
    var details: [BattleHistoryQuestion]
    let review: BattleReview?
    let legacy: Bool

    enum CodingKeys: String, CodingKey {
        case id, mode, rule, opponent, won, draw, details, review, legacy
        case roomID = "room_id"
        case correctCount = "correct_count"
        case opponentCorrectCount = "opponent_correct_count"
        case ratingDelta = "rating_delta"
        case createdAt = "created_at"
    }
}

private struct BattleHistoryQuestion: Decodable, Identifiable {
    let questionIndex: Int
    let questionID: Int
    let stem: String
    let material: String
    let options: [String]
    let media: QuestionMediaData?
    let picked: Int?
    let answer: Int
    let answered: Bool
    let correct: Bool
    let elapsedMS: Int?
    let subject: String
    let topic: String
    let explanation: String
    var favorite: Bool

    var id: String { "\(questionIndex)-\(questionID)" }

    enum CodingKeys: String, CodingKey {
        case stem, material, options, media, picked, answer, answered, correct, subject, topic, explanation, favorite
        case questionIndex = "question_index"
        case questionID = "question_id"
        case elapsedMS = "elapsed_ms"
    }
}

private struct CorrectionTarget: Identifiable { let id: Int }
