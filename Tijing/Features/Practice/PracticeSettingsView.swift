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
        Form {
            Section("每组题量") {
                Stepper(value: $draft.questionCount, in: 10...40, step: 1) {
                    LabeledContent("题量") {
                        Text("\(draft.questionCount) 题")
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                }
                Text("可在 10～40 题之间调整。已经生成的未完成题组不会因为这里的修改而被重建。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("题目难度") {
                LabeledContent("当前范围") {
                    Text("\(draft.difficultyMinRatio)% ～ \(draft.difficultyMaxRatio)%")
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("最低正确率")
                        Spacer()
                        Text("\(draft.difficultyMinRatio)%")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
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
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("最高正确率")
                        Spacer()
                        Text("\(draft.difficultyMaxRatio)%")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
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
                }

                Text("只推送所选正确率范围内的试题；两个边界始终至少相差 30%。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("答题方式") {
                Picker("答题方式", selection: $draft.answerMode) {
                    Text("背题模式").tag("immediate")
                    Text("做题模式").tag("submit")
                }
                .pickerStyle(.segmented)

                Label(
                    draft.answerMode == "immediate"
                    ? "选完答案显示正确答案与解析，由你手动切换下一题。"
                    : "作答时不显示答案，完成本题后自动进入下一题，最后手动交卷统一看解析。",
                    systemImage: draft.answerMode == "immediate" ? "lightbulb" : "doc.text"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
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
}
