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
        .sensoryFeedback(.selection, trigger: draft.questionCount)
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
            TijingSectionHeading("每组题量", subtitle: "10～40 题；修改不会重建已经生成的未完成题组")

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(draft.questionCount)")
                        .font(.system(size: 46, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("题 / 组")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Stepper("题量", value: $draft.questionCount, in: 10...40, step: 1)
                    .labelsHidden()
            }
            .padding(18)
            .tijingCard()
        }
    }

    private var difficultyCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            TijingSectionHeading("题目难度", subtitle: "按全站正确率筛选；两个边界始终至少相差 30%")

            VStack(spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("当前范围")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(draft.difficultyMinRatio)% ～ \(draft.difficultyMaxRatio)%")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .monospacedDigit()
                    }
                    Spacer()
                    Image(systemName: "dial.medium.fill")
                        .font(.title2)
                        .foregroundStyle(TijingDesign.violet)
                }

                VStack(spacing: 10) {
                    valueHeader("最低正确率", value: draft.difficultyMinRatio)
                    Slider(
                        value: Binding(
                            get: { Double(draft.difficultyMinRatio) },
                            set: { value in
                                let next = Int(value.rounded())
                                draft.difficultyMinRatio = min(next, draft.difficultyMaxRatio - 30)
                            }
                        ),
                        in: 0...70,
                        step: 1
                    )
                    .tint(TijingDesign.indigo)
                }

                VStack(spacing: 10) {
                    valueHeader("最高正确率", value: draft.difficultyMaxRatio)
                    Slider(
                        value: Binding(
                            get: { Double(draft.difficultyMaxRatio) },
                            set: { value in
                                let next = Int(value.rounded())
                                draft.difficultyMaxRatio = max(next, draft.difficultyMinRatio + 30)
                            }
                        ),
                        in: 30...100,
                        step: 1
                    )
                    .tint(TijingDesign.cyan)
                }
            }
            .padding(18)
            .tijingCard()
        }
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
                        ? "选完答案立即显示正确答案与解析，由你手动切换下一题。"
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

    private func valueHeader(_ title: String, value: Int) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.medium))
            Spacer()
            Text("\(value)%")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}
