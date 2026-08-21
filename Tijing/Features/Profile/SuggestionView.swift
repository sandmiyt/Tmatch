import SwiftUI

struct SuggestionView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var content = ""
    @State private var busy = false
    @State private var message: String?

    var body: some View {
        ZStack {
            TijingPageBackground()
            ScrollView {
                VStack(spacing: 16) {
                    TijingPaperCard(tint: TijingDesign.butter, rotation: -0.25) {
                        HStack(spacing: 13) {
                            TijingStickerIcon(systemImage: "lightbulb.fill", tint: TijingDesign.amber, background: TijingDesign.butter, size: 50, rotation: -7)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("说说你的想法")
                                    .font(.headline)
                                Text("功能、界面、题库、对战或 Bug 都可以。描述得越具体，越容易真正改到点上。")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                    }

                    TijingFieldSurface("建议内容") {
                        TextField("例如：希望错题页可以按知识点筛选……", text: $content, axis: .vertical)
                            .lineLimit(6...10)
                            .onChange(of: content) { _, value in
                                if value.count > 1000 { content = String(value.prefix(1000)) }
                            }
                        Text("\(content.count)/1000")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    if let message {
                        Label(message, systemImage: "info.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .tijingCard()
                    }

                    Button {
                        Haptics.medium()
                        Task { await submit() }
                    } label: {
                        HStack(spacing: 8) {
                            if busy { ProgressView().controlSize(.small).tint(.white) }
                            Text("提交建议")
                            Image(systemName: "paperplane.fill")
                        }
                    }
                    .buttonStyle(TijingPrimaryButtonStyle())
                    .disabled(busy || content.trimmingCharacters(in: .whitespacesAndNewlines).count < 5)
                }
                .padding(.horizontal, TijingDesign.pageHorizontalPadding)
                .padding(.top, 10)
                .padding(.bottom, 28)
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
