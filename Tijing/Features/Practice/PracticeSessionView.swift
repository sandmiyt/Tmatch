import SwiftUI

struct PracticeSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @State var store: PracticeSessionStore
    @State private var confirmQuit = false
    @State private var confirmSubmit = false
    @State private var showAnswerSheet = false
    @State private var correctionTarget: CorrectionTarget?

    var body: some View {
        ZStack {
            TijingPageBackground()
            Group {
            if store.isLoading && store.questions.isEmpty {
                ProgressView("正在读取题组")
            } else if let error = store.error, store.questions.isEmpty {
                ContentUnavailableView("题组读取失败", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if store.questions.isEmpty {
                ContentUnavailableView {
                    Label(emptyTitle, systemImage: "checkmark.circle")
                } description: {
                    Text(emptyDescription)
                }
            } else if let question = store.currentQuestion {
                questionContent(question)
            }
            }
        }
        .navigationTitle(store.mode.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(!store.questions.isEmpty && store.batchResult == nil)
        .toolbar {
            if !store.questions.isEmpty {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        confirmQuit = true
                    } label: { Image(systemName: "xmark") }
                    .accessibilityLabel("退出本组")
                }
                ToolbarItem(placement: .principal) {
                    Text(store.progressText).font(.headline.monospacedDigit())
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let question = store.currentQuestion, store.batchResult == nil {
                bottomControls(question)
            }
        }
        .task { await store.load() }
        .confirmationDialog("退出当前题组？", isPresented: $confirmQuit, titleVisibility: .visible) {
            Button("保留进度并退出") { dismiss() }
            Button("放弃本组进度", role: .destructive) { store.clearResume(); dismiss() }
            Button("继续答题", role: .cancel) {}
        } message: {
            Text("保留进度后，下次进入同一练习范围会继续当前题组，不受后来修改练习设置影响。")
        }
        .confirmationDialog("确认交卷？", isPresented: $confirmSubmit, titleVisibility: .visible) {
            Button("确认交卷") { Task { await store.submitBatch() } }
            Button("继续答题", role: .cancel) {}
        } message: {
            Text("还有 \(store.unansweredCount) 题未作答，未作答将按错误记录。")
        }
        .sheet(isPresented: $showAnswerSheet) {
            PracticeAnswerSheet(store: store)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $correctionTarget) { target in
            QuestionCorrectionView(questionID: target.id)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $store.showBatchResult) {
            if let result = store.batchResult {
                PracticeBatchResultView(result: result, questions: store.questions) {
                    store.showBatchResult = false
                    dismiss()
                }
            }
        }
    }

    private func questionContent(_ question: Question) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                TijingPaperCard(tint: TijingDesign.sky) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            TijingStickerIcon(systemImage: "pencil.and.outline", tint: TijingDesign.indigo, background: TijingDesign.sky, size: 42, rotation: -6, sparkle: false)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.mode.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text("第 \(store.index + 1) 题")
                                    .font(.title3.bold())
                            }
                            Spacer()
                            TijingMicroBadge(title: store.progressText, systemImage: "circle.grid.3x3.fill", tint: TijingDesign.indigo)
                        }
                        ProgressView(value: Double(store.index + 1), total: Double(max(store.questions.count, 1)))
                            .tint(TijingDesign.indigo)
                            .accessibilityLabel("答题进度")
                            .accessibilityValue(store.progressText)
                    }
                }

                questionTools(question)

                if let material = question.material, !material.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    TijingPaperCard(tint: TijingDesign.butter) {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("材料", systemImage: "doc.text.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(TijingDesign.amber)
                            Text(material)
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            QuestionMediaStrip(urls: question.media?.material ?? [])
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "text.quote")
                            .font(.caption.bold())
                            .foregroundStyle(TijingDesign.violet)
                        Text("题目")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text(question.stem)
                        .font(.title3.weight(.semibold))
                        .textSelection(.disabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    QuestionMediaStrip(urls: question.media?.stem ?? [])
                }

                VStack(spacing: 12) {
                    ForEach(question.options.indices, id: \.self) { index in
                        OptionRow(
                            letter: TijingFormat.optionLetter(index),
                            text: question.options[index],
                            media: optionMedia(question, index: index),
                            state: optionState(question, displayIndex: index),
                            excluded: store.excludedIndices(for: question).contains(index),
                            tap: { Task { await store.tapOption(index) } },
                            longPress: { store.toggleExcluded(index) }
                        )
                    }
                }

                if let feedback = store.feedbackForCurrent() {
                    FeedbackCard(question: question, feedback: feedback)
                        .tijingReveal(order: 0)
                }

                if let error = store.error {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func questionTools(_ question: Question) -> some View {
        TijingQuestionToolStrip(
            isFavorite: question.favorite == true,
            favoriteAction: {
                Task { await store.toggleFavorite() }
            },
            correctionAction: {
                if let id = store.currentQuestion?.id {
                    Haptics.selection()
                    correctionTarget = CorrectionTarget(id: id)
                }
            },
            answerSheetAction: {
                Haptics.selection()
                showAnswerSheet = true
            }
        )
    }

    private func bottomControls(_ question: Question) -> some View {
        VStack(spacing: 10) {
            if store.isDeferred && store.isLast {
                Button {
                    if store.unansweredCount > 0 {
                        confirmSubmit = true
                    } else {
                        Task { await store.submitBatch() }
                    }
                } label: {
                    HStack {
                        if store.isSubmitting { ProgressView().controlSize(.small) }
                        Text("提交本组")
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "checkmark.seal")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(store.isSubmitting)
            } else if question.isMultiple && store.feedbackForCurrent() == nil {
                Button {
                    Task { await store.confirmMultiple() }
                } label: {
                    HStack {
                        if store.isSubmitting { ProgressView().controlSize(.small) }
                        Text(store.settings.answerMode == "submit" ? "确认本题" : "确认答案")
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "checkmark.circle")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(store.selectedDisplayIndices(for: question).isEmpty || store.isSubmitting)
            } else if store.isImmediate && store.isLast && store.feedbackForCurrent() != nil {
                Button {
                    Task { await store.finishImmediateReview() }
                } label: {
                    HStack {
                        if store.isSubmitting { ProgressView().controlSize(.small) }
                        Text("完成本组")
                            .fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "checkmark.seal")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(store.isSubmitting)
            }

            HStack(spacing: 12) {
                Button {
                    store.previous()
                } label: {
                    Label("上一题", systemImage: "chevron.left")
                }
                .buttonStyle(.bordered)
                .disabled(!store.canGoBack)

                Spacer(minLength: 12)

                if store.isImmediate, store.feedbackForCurrent() != nil, store.canGoNext {
                    Button {
                        store.next()
                    } label: {
                        Label("下一题", systemImage: "chevron.right")
                    }
                    .buttonStyle(.borderedProminent)
                } else if store.settings.answerMode == "submit", store.canGoNext {
                    Button {
                        store.next()
                    } label: {
                        Label("下一题", systemImage: "chevron.right")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .controlSize(.large)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.regularMaterial)
        .overlay(alignment: .top) { Divider() }
    }

    private func optionMedia(_ question: Question, index: Int) -> [String] {
        guard let values = question.media?.options, values.indices.contains(index) else { return [] }
        return values[index]
    }

    private func optionState(_ question: Question, displayIndex: Int) -> OptionVisualState {
        let selected = store.selectedDisplayIndices(for: question).contains(displayIndex)
        guard let feedback = store.feedbackForCurrent() else { return selected ? .selected : .normal }
        let originals = feedback.answers ?? feedback.answer.map { [$0] } ?? []
        let correctDisplay = Set(question.displayIndices(fromOriginal: originals))
        if correctDisplay.contains(displayIndex) { return .correct }
        if selected && !feedback.correct { return .wrong }
        return .normal
    }

    private var emptyTitle: String {
        switch store.mode {
        case .wrong: "暂无错题"
        case .favorite: "暂无收藏题"
        case .smartReview: "暂无到期复习"
        default: "当前范围暂无可用题目"
        }
    }

    private var emptyDescription: String {
        switch store.mode {
        case .wrong: "答错的题会自动进入错题重练。"
        case .favorite: "刷题时点击星标即可收藏。"
        case .smartReview: "需要复习的题会按计划出现在这里。"
        default: "可以返回重新选择题库或调整设置。"
        }
    }
}

private struct CorrectionTarget: Identifiable { let id: Int }

private struct PracticeAnswerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let store: PracticeSessionStore
    private let columns = [GridItem(.adaptive(minimum: 44), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Array(store.questions.enumerated()), id: \.element.id) { offset, question in
                        Button {
                            store.go(to: offset)
                            dismiss()
                        } label: {
                            Text("\(offset + 1)")
                                .font(.headline.monospacedDigit())
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(offset == store.index ? Color.accentColor : (store.isAnswered(question) ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.08)), in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(offset == store.index ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("答题卡")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }
}

struct QuestionCorrectionView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    let questionID: Int
    @State private var category = "answer"
    @State private var content = ""
    @State private var busy = false
    @State private var error: String?

    private let categories = [
        ("answer", "答案错误"), ("explanation", "解析错误"), ("stem", "题干错误"),
        ("option", "选项错误"), ("source", "来源问题"), ("other", "其他")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                TijingPageBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        TijingPaperCard(tint: TijingDesign.rose, rotation: -0.25) {
                            HStack(spacing: 13) {
                                TijingStickerIcon(systemImage: "exclamationmark.bubble.fill", tint: TijingDesign.coral, background: TijingDesign.rose, size: 48, rotation: -7)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("题目纠错")
                                        .font(.headline)
                                    Text("把问题描述清楚即可，管理员复核后再处理。")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                        }

                        TijingFieldSurface("问题类型") {
                            Picker("问题类型", selection: $category) {
                                ForEach(categories, id: \.0) { value, title in Text(title).tag(value) }
                            }
                            .pickerStyle(.menu)
                        }

                        TijingFieldSurface("补充说明（可选）") {
                            TextField("例如：正确答案应该是 B，解析中的法条引用有误……", text: $content, axis: .vertical)
                                .lineLimit(4...7)
                                .onChange(of: content) { _, value in
                                    if value.count > 500 { content = String(value.prefix(500)) }
                                }
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
                        }

                        Label("提交后不会自动改题，会先进入人工复核。", systemImage: "checkmark.shield")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, TijingDesign.pageHorizontalPadding)
                    .padding(.top, 10)
                    .padding(.bottom, 26)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .sensoryFeedback(.selection, trigger: category)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("提交") { Task { await submit() } }.bold().disabled(busy)
                }
            }
        }
    }

    @MainActor private func submit() async {
        guard let token = session.token else { return }
        busy = true; error = nil; defer { busy = false }
        do {
            let _: CorrectionResponse = try await session.api.request(
                "/api/questions/\(questionID)/corrections",
                method: .post,
                body: CorrectionBody(category: category, content: content.trimmingCharacters(in: .whitespacesAndNewlines)),
                token: token
            )
            Haptics.success()
            dismiss()
        } catch {
            self.error = error.localizedDescription
            Haptics.error()
        }
    }
}

private struct CorrectionBody: Encodable { let category: String; let content: String }
private struct CorrectionResponse: Decodable { let ok: Bool; let id: Int?; let duplicate: Bool? }

private enum OptionVisualState: Equatable { case normal, selected, correct, wrong }

private struct OptionRow: View {
    let letter: String
    let text: String
    let media: [String]
    let state: OptionVisualState
    let excluded: Bool
    let tap: () -> Void
    let longPress: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Text(letter)
                    .font(.subheadline.bold())
                    .frame(width: 30, height: 30)
                    .background(circleBackground, in: Circle())
                    .foregroundStyle(circleForeground)
                Text(text)
                    .font(.body)
                    .foregroundStyle(excluded ? .secondary : .primary)
                    .strikethrough(excluded)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            QuestionMediaStrip(urls: media)
        }
        .padding(14)
        .background(background, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 19).stroke(border, lineWidth: state == .normal ? 0.7 : 1.5))
        .shadow(color: state == .normal ? Color.black.opacity(0.025) : Color.clear, radius: 7, y: 3)
        .animation(.easeOut(duration: 0.20), value: state)
        .contentShape(Rectangle())
        .onTapGesture { if !excluded { tap() } }
        .onLongPressGesture(minimumDuration: 0.45, perform: longPress)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("轻点选择，长按排除或恢复该选项")
    }

    private var background: Color {
        switch state {
        case .normal: Color(uiColor: .secondarySystemGroupedBackground)
        case .selected: Color.accentColor.opacity(0.10)
        case .correct: Color.green.opacity(0.12)
        case .wrong: Color.red.opacity(0.10)
        }
    }
    private var border: Color {
        switch state {
        case .normal: Color.secondary.opacity(0.22)
        case .selected: .accentColor
        case .correct: .green
        case .wrong: .red
        }
    }
    private var circleBackground: Color {
        switch state { case .correct: .green; case .wrong: .red; case .selected: .accentColor; case .normal: .secondary.opacity(0.12) }
    }
    private var circleForeground: Color { state == .normal ? .primary : .white }
}

private struct FeedbackCard: View {
    let question: Question
    let feedback: AnswerFeedback

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(feedback.correct ? "回答正确" : "回答错误")
                .font(.headline)
                .foregroundStyle(feedback.correct ? Color.green : Color.red)

            let answers = feedback.answers ?? feedback.answer.map { [$0] } ?? []
            let displayAnswers = question.displayIndices(fromOriginal: answers)
            Text("正确答案：\(answerLetters(displayAnswers))")
                .font(.subheadline.bold())

            if let explanation = feedback.explanation, !explanation.isEmpty {
                Text("解析").font(.headline)
                Text(remapExplanation(explanation)).font(.body)
                QuestionMediaStrip(urls: feedback.media?.explanation ?? [])
            }

            if let keypoints = feedback.keypoints, !keypoints.isEmpty {
                Text("考点：\(keypoints.joined(separator: " · "))")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            HStack(spacing: 14) {
                if let ratio = feedback.correctRatio { Label("正确率 \(TijingFormat.percent(ratio))", systemImage: "chart.bar") }
                if let elapsed = feedback.elapsedMS { Label(TijingFormat.duration(milliseconds: elapsed), systemImage: "timer") }
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17)
        .background((feedback.correct ? TijingDesign.sage : TijingDesign.rose).opacity(0.24), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder((feedback.correct ? TijingDesign.mint : TijingDesign.coral).opacity(0.18)) }
    }

    private func answerLetters(_ values: [Int]) -> String {
        values.sorted().map { index in TijingFormat.optionLetter(index) }.joined(separator: "、")
    }

    private func remapExplanation(_ text: String) -> String {
        guard let order = question.optionOrder, order.count == question.options.count else { return text }
        var inverse: [Int: Int] = [:]
        for (display, original) in order.enumerated() { inverse[original] = display }
        let pattern = #"(?<![A-Za-z])([A-E])(?![A-Za-z])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).reversed()
        var result = text
        for match in matches {
            guard match.numberOfRanges > 1 else { continue }
            let range = match.range(at: 1)
            let letter = ns.substring(with: range)
            guard let scalar = letter.unicodeScalars.first, let display = inverse[Int(scalar.value) - 65] else { continue }
            let replacement = TijingFormat.optionLetter(display)
            if let swiftRange = Range(range, in: result) { result.replaceSubrange(swiftRange, with: replacement) }
        }
        return result
    }
}

private struct PracticeBatchResultView: View {
    let result: PracticeBatchResult
    let questions: [Question]
    let done: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                TijingPageBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        TijingPaperCard(tint: result.score >= 60 ? TijingDesign.sage : TijingDesign.rose, rotation: -0.25) {
                            HStack(spacing: 16) {
                                TijingStickerIcon(
                                    systemImage: result.score >= 60 ? "checkmark.seal.fill" : "arrow.counterclockwise.circle.fill",
                                    tint: result.score >= 60 ? TijingDesign.mint : TijingDesign.coral,
                                    background: result.score >= 60 ? TijingDesign.sage : TijingDesign.rose,
                                    size: 58,
                                    rotation: -7
                                )
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("本组完成")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Text("\(result.score) 分")
                                        .font(.system(size: 42, weight: .bold, design: .rounded))
                                        .monospacedDigit()
                                        .contentTransition(.numericText())
                                        .animation(.snappy(duration: 0.42), value: result.score)
                                    Text("\(result.correct) / \(result.total) 正确")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }

                        if result.details.isEmpty {
                            TijingPaperCard(tint: TijingDesign.sky) {
                                HStack(spacing: 12) {
                                    TijingStickerIcon(systemImage: "sparkles", tint: TijingDesign.indigo, background: TijingDesign.sky, size: 44)
                                    Text("这组没有需要回看的错题，状态不错。")
                                        .font(.subheadline)
                                    Spacer(minLength: 0)
                                }
                            }
                        } else {
                            VStack(spacing: 12) {
                                TijingSectionHeading("需要再看一眼", subtitle: "结果页只保留错题和未作答题")
                                ForEach(Array(result.details.enumerated()), id: \.element.id) { offset, item in
                                    TijingPaperCard(tint: item.correct ? TijingDesign.sage : TijingDesign.rose) {
                                        HStack(alignment: .top, spacing: 12) {
                                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                                .fill(item.correct ? TijingDesign.mint : TijingDesign.coral)
                                                .frame(width: 4)
                                            VStack(alignment: .leading, spacing: 6) {
                                                Text("第 \(offset + 1) 题 · \(item.correct ? "正确" : "错误")")
                                                    .font(.subheadline.weight(.semibold))
                                                Text(item.stem ?? question(item.questionID)?.stem ?? "题目")
                                                    .font(.subheadline)
                                                    .lineLimit(3)
                                                if !item.correct, let explanation = item.explanation, !explanation.isEmpty {
                                                    Text(explanation)
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                        .lineLimit(4)
                                                }
                                            }
                                            Spacer(minLength: 0)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, TijingDesign.pageHorizontalPadding)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("练习结果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成", action: done).bold() } }
        }
    }

    private func question(_ id: Int) -> Question? { questions.first { $0.id == id } }
}
