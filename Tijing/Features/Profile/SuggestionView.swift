import SwiftUI

struct SuggestionView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var content = ""
    @State private var busy = false
    @State private var message: String?

    var body: some View {
        Form {
            Section {
                Label("你的想法会进入管理员后台", systemImage: "sparkles")
                    .font(.headline)
                Text("可以反馈功能、界面、题库、对战或 Bug。请尽量描述清楚使用场景。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("建议内容") {
                TextField("例如：希望错题页可以按知识点筛选……", text: $content, axis: .vertical)
                    .lineLimit(5...10)
                    .onChange(of: content) { _, value in
                        if value.count > 1000 { content = String(value.prefix(1000)) }
                    }
                HStack {
                    Spacer()
                    Text("\(content.count)/1000")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if let message {
                Section { Text(message).foregroundStyle(.secondary) }
            }

            Section {
                Button {
                    Task { await submit() }
                } label: {
                    HStack {
                        Spacer()
                        if busy { ProgressView().controlSize(.small) }
                        Text("提交建议").bold()
                        Spacer()
                    }
                }
                .disabled(busy || content.trimmingCharacters(in: .whitespacesAndNewlines).count < 5)
            }
        }
        .navigationTitle("功能建议")
        .navigationBarTitleDisplayMode(.inline)
    }

    @MainActor
    private func submit() async {
        guard let token = session.token else { return }
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 5 else { return }
        busy = true
        message = nil
        defer { busy = false }
        do {
            let _: EmptyResponse = try await session.api.request(
                "/api/suggestions",
                method: .post,
                body: SuggestionBody(content: text),
                token: token
            )
            Haptics.success()
            dismiss()
        } catch {
            message = error.localizedDescription
            Haptics.error()
        }
    }
}

private struct SuggestionBody: Encodable { let content: String }
