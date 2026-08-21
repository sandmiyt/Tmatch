import SwiftUI

struct PracticeSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var settings: PracticeSettings
    let onSave: @MainActor (PracticeSettings) async -> Void
    @State private var draft: PracticeSettings

    init(settings: Binding<PracticeSettings>, onSave: @escaping @MainActor (PracticeSettings) async -> Void) {
        _settings = settings
        self.onSave = onSave
        _draft = State(initialValue: settings.wrappedValue)
    }

    var body: some View {
        ZStack {
            TijingPageBackground()

            ScrollView {
                VStack(spacing: 22) {
                    questionCountCard
                    difficultyCard
                    answerModeCard
                }
                .padding(.horizontal, TijingDesign.pageHorizontalPadding)
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("练习设置")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: draft.questionCount / 5)
        .sensoryFeedback(.selection, trigger: draft.difficultyMinRatio / 5)
        .sensoryFeedback(.selection, trigger: draft.difficultyMaxRatio / 5)
        .sensoryFeedback(.selection, trigger: draft.answerMode)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("完成") {
                    Task {
                        await onSave(draft)
                        dismiss()
                    }
                }
                .bold()
            }
        }
    }

    private var questionCountCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            TijingSectionHeading("每组题量", subtitle: "滑动选择每组题数；修改不会重建已经生成的未完成题组")

            VStack(spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(draft.questionCount)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .animation(.snappy(duration: 0.22), value: draft.questionCount)
                        Text("题 / 组")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    TijingMicroBadge(
                        title: "滑动选择 · 5题一反馈",
                        systemImage: "hand.draw.fill",
                        tint: TijingDesign.indigo
                    )
                }

                TijingQuestionCountSlider(value: $draft.questionCount)

                HStack {
                    ForEach([10, 15, 20, 25, 30, 35, 40], id: \.self) { value in
                        Text("\(value)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(abs(value - draft.questionCount) <= 1 ? TijingDesign.indigo : .secondary)
                            .fontWeight(abs(value - draft.questionCount) <= 1 ? .semibold : .regular)
                        if value != 40 { Spacer(minLength: 0) }
                    }
                }
            }
            .padding(18)
            .tijingCard()
        }
    }

    private var difficultyCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            TijingSectionHeading("题目难度", subtitle: "拖动一条难度范围；两个端点始终至少相差 30%")

            VStack(spacing: 18) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("当前范围")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(draft.difficultyMinRatio)% ～ \(draft.difficultyMaxRatio)%")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("全站正确率")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("越左越难 · 越右越易")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(TijingDesign.violet)
                    }
                }

                TijingDifficultyRangeSlider(
                    lower: $draft.difficultyMinRatio,
                    upper: $draft.difficultyMaxRatio,
                    minimumGap: 30
                )

                HStack(spacing: 0) {
                    ForEach([0, 20, 40, 60, 80, 100], id: \.self) { value in
                        Button {
                            snapDifficulty(to: value)
                        } label: {
                            Text("\(value)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(difficultyAnchorIsActive(value) ? TijingDesign.indigo : .secondary)
                                .fontWeight(difficultyAnchorIsActive(value) ? .semibold : .regular)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    Label("更难", systemImage: "flame.fill")
                        .foregroundStyle(TijingDesign.coral)
                    Spacer()
                    Text("正确率范围")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Label("更易", systemImage: "leaf.fill")
                        .foregroundStyle(TijingDesign.mint)
                }
                .font(.caption)
            }
            .padding(18)
            .tijingCard()
        }
    }

    private func difficultyAnchorIsActive(_ value: Int) -> Bool {
        abs(value - draft.difficultyMinRatio) <= 4 || abs(value - draft.difficultyMaxRatio) <= 4
    }

    private func snapDifficulty(to value: Int) {
        let lowerDistance = abs(value - draft.difficultyMinRatio)
        let upperDistance = abs(value - draft.difficultyMaxRatio)
        withAnimation(.snappy(duration: 0.24)) {
            if lowerDistance <= upperDistance {
                draft.difficultyMinRatio = min(value, draft.difficultyMaxRatio - 30)
            } else {
                draft.difficultyMaxRatio = max(value, draft.difficultyMinRatio + 30)
            }
        }
        Haptics.selection()
    }

    private var answerModeCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            TijingSectionHeading("答题方式")

            VStack(spacing: 15) {
                Picker("答题方式", selection: $draft.answerMode) {
                    Text("背题模式").tag("immediate")
                    Text("做题模式").tag("submit")
                }
                .pickerStyle(.segmented)

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: draft.answerMode == "immediate" ? "lightbulb.fill" : "doc.text.fill")
                        .font(.headline)
                        .foregroundStyle(draft.answerMode == "immediate" ? TijingDesign.amber : TijingDesign.indigo)
                        .frame(width: 36, height: 36)
                        .background(
                            (draft.answerMode == "immediate" ? TijingDesign.amber : TijingDesign.indigo).opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                        )
                    Text(
                        draft.answerMode == "immediate"
                        ? "单选点选后立即显示答案与解析，多选确认后提交；不会自动跳题，可手动切换下一题。"
                        : "作答时不显示答案，完成本题后自动进入下一题，最后手动交卷统一看解析。"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(18)
            .tijingCard()
        }
    }

}


private struct TijingQuestionCountSlider: View {
    @Binding var value: Int
    @State private var dragValue: CGFloat?
    @State private var lastFeedbackBucket: Int?

    private let lowerBound = 10
    private let upperBound = 40
    private let thumbSize: CGFloat = 34

    var body: some View {
        GeometryReader { proxy in
            let trackWidth = max(1, proxy.size.width - thumbSize)
            let displayValue = dragValue ?? CGFloat(value)
            let progress = (displayValue - CGFloat(lowerBound)) / CGFloat(upperBound - lowerBound)
            let thumbX = thumbSize / 2 + progress * trackWidth

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.13))
                    .frame(height: 8)
                    .padding(.horizontal, thumbSize / 2)

                Capsule()
                    .fill(LinearGradient(colors: [TijingDesign.indigo, TijingDesign.violet], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, thumbX - thumbSize / 2), height: 8)
                    .offset(x: thumbSize / 2)

                ForEach([10, 15, 20, 25, 30, 35, 40], id: \.self) { tick in
                    let tickProgress = CGFloat(tick - lowerBound) / CGFloat(upperBound - lowerBound)
                    let tickX = thumbSize / 2 + tickProgress * trackWidth
                    Circle()
                        .fill(CGFloat(tick) <= displayValue ? Color.white.opacity(0.92) : Color.secondary.opacity(0.28))
                        .frame(width: abs(CGFloat(tick) - displayValue) < 0.65 ? 6 : 4,
                               height: abs(CGFloat(tick) - displayValue) < 0.65 ? 6 : 4)
                        .position(x: tickX, y: 30)
                        .allowsHitTesting(false)
                }

                ZStack {
                    Circle().fill(.background)
                        .shadow(color: Color.black.opacity(dragValue == nil ? 0.08 : 0.15), radius: dragValue == nil ? 4 : 8, y: 2)
                    Circle().strokeBorder(TijingDesign.indigo.opacity(dragValue == nil ? 0.72 : 1), lineWidth: dragValue == nil ? 1.5 : 2.5)
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(TijingDesign.indigo)
                }
                .frame(width: thumbSize, height: thumbSize)
                .scaleEffect(dragValue == nil ? 1 : 1.10)
                .position(x: thumbX, y: 30)
            }
            .frame(height: 60)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let localX = min(max(0, gesture.location.x - thumbSize / 2), trackWidth)
                        let raw = CGFloat(lowerBound) + (localX / trackWidth) * CGFloat(upperBound - lowerBound)
                        dragValue = raw
                        let rounded = min(upperBound, max(lowerBound, Int(raw.rounded())))
                        if rounded != value { value = rounded }
                        let bucket = Int((Double(rounded) / 5.0).rounded())
                        if bucket != lastFeedbackBucket {
                            lastFeedbackBucket = bucket
                            Haptics.selection()
                        }
                    }
                    .onEnded { _ in
                        let snapped = min(upperBound, max(lowerBound, value))
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) { dragValue = nil }
                        value = snapped
                        lastFeedbackBucket = nil
                        Haptics.light()
                    }
            )
            .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.86), value: value)
        }
        .frame(height: 60)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("每组题量")
        .accessibilityValue("\(value) 题")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(upperBound, value + 1)
            case .decrement: value = max(lowerBound, value - 1)
            @unknown default: break
            }
        }
    }
}

private struct TijingDifficultyRangeSlider: View {
    @Binding var lower: Int
    @Binding var upper: Int
    let minimumGap: Int

    @State private var activeHandle: Handle?
    @State private var dragDisplayValue: CGFloat?
    @State private var lastFeedbackBucket: Int?

    private enum Handle { case lower, upper }
    private let thumbSize: CGFloat = 30

    var body: some View {
        GeometryReader { proxy in
            let trackWidth = max(1, proxy.size.width - thumbSize)
            let lowerDisplay = activeHandle == .lower ? (dragDisplayValue ?? CGFloat(lower)) : CGFloat(lower)
            let upperDisplay = activeHandle == .upper ? (dragDisplayValue ?? CGFloat(upper)) : CGFloat(upper)
            let lowerX = xPosition(for: lowerDisplay, trackWidth: trackWidth)
            let upperX = xPosition(for: upperDisplay, trackWidth: trackWidth)

            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.14)).frame(height: 8).padding(.horizontal, thumbSize / 2)
                Capsule()
                    .fill(LinearGradient(colors: [TijingDesign.violet, TijingDesign.indigo, TijingDesign.cyan], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, upperX - lowerX), height: 8)
                    .offset(x: lowerX)

                thumb(value: Int(lowerDisplay.rounded()), isActive: activeHandle == .lower)
                    .position(x: lowerX, y: 29)
                thumb(value: Int(upperDisplay.rounded()), isActive: activeHandle == .upper)
                    .position(x: upperX, y: 29)
            }
            .frame(height: 58)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if activeHandle == nil {
                            activeHandle = abs(gesture.location.x - lowerX) <= abs(gesture.location.x - upperX) ? .lower : .upper
                            Haptics.light()
                        }
                        updateContinuously(locationX: gesture.location.x, trackWidth: trackWidth)
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.84)) {
                            dragDisplayValue = nil
                            activeHandle = nil
                        }
                        lastFeedbackBucket = nil
                        Haptics.light()
                    }
            )
        }
        .frame(height: 58)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("题目难度范围")
        .accessibilityValue("最低正确率 \(lower)%，最高正确率 \(upper)%")
    }

    private func xPosition(for value: CGFloat, trackWidth: CGFloat) -> CGFloat {
        thumbSize / 2 + min(100, max(0, value)) / 100 * trackWidth
    }

    private func rawValue(for x: CGFloat, trackWidth: CGFloat) -> CGFloat {
        let local = min(max(0, x - thumbSize / 2), trackWidth)
        return min(100, max(0, local / trackWidth * 100))
    }

    private func updateContinuously(locationX: CGFloat, trackWidth: CGFloat) {
        let raw = rawValue(for: locationX, trackWidth: trackWidth)
        let clamped: CGFloat
        switch activeHandle {
        case .lower:
            clamped = min(raw, CGFloat(upper - minimumGap))
            dragDisplayValue = clamped
            lower = min(Int(clamped.rounded()), upper - minimumGap)
        case .upper:
            clamped = max(raw, CGFloat(lower + minimumGap))
            dragDisplayValue = clamped
            upper = max(Int(clamped.rounded()), lower + minimumGap)
        case nil:
            return
        }
        let bucket = Int((Double(Int(clamped.rounded())) / 5.0).rounded())
        if bucket != lastFeedbackBucket {
            lastFeedbackBucket = bucket
            Haptics.selection()
        }
    }

    private func thumb(value: Int, isActive: Bool) -> some View {
        ZStack {
            Circle().fill(.background)
                .shadow(color: Color.black.opacity(isActive ? 0.16 : 0.09), radius: isActive ? 8 : 4, y: 2)
            Circle().strokeBorder(isActive ? TijingDesign.indigo : Color.secondary.opacity(0.25), lineWidth: isActive ? 2.5 : 1)
            Text("\(value)")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isActive ? TijingDesign.indigo : .secondary)
        }
        .frame(width: thumbSize, height: thumbSize)
        .scaleEffect(isActive ? 1.13 : 1)
    }
}
