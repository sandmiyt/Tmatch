import SwiftUI

struct PracticeDeliveryView: View {
    @Environment(SessionStore.self) private var session
    @State private var retrying = false
    var body: some View {
        ZStack {
            TijingPageBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("可靠补交").font(.title.bold())
                    Text("普通练习先保存在本机，联网且 App 在前台时自动确认。重试不会重复计分；退出账号后暂停，只能由原账号继续。不用于排位、对战或限时挑战。")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if let error = session.submissions.storageError { Text(error).foregroundStyle(.red) }
                    Button(retrying ? "正在确认…" : "检查待补交记录") {
                        Task { retrying = true; await session.submissions.retryPending(); retrying = false }
                    }.buttonStyle(.borderedProminent).disabled(retrying)
                    Text("失败重试有退避等待；请勿卸载 App 或清理 App 数据，否则未确认记录会丢失。")
                        .font(.footnote).foregroundStyle(.secondary)
                    if session.submissions.pending.isEmpty {
                        Label("没有待补交记录", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                    ForEach(session.submissions.pending) { item in
                        TijingPaperCard(tint: item.blocked ? TijingDesign.peach : TijingDesign.sky) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(item.path.hasSuffix("answer") ? "单题答案" : "整组交卷").font(.headline)
                                Text(item.createdAt, style: .date)
                                Text(item.blocked ? "需处理：服务器拒绝，已停止自动重试" : "已保存，等待服务器确认")
                                if let message = item.message { Text(message).font(.footnote).foregroundStyle(.secondary) }
                                Text("标识：\(item.id)").font(.caption2).textSelection(.enabled)
                            }
                        }
                    }
                    Text("已确认 \(session.submissions.entries.filter { $0.response != nil }.count) 条本机提交。回到原练习可恢复反馈，周报下拉刷新后查看统计。")
                        .font(.footnote).foregroundStyle(.secondary)
                    TijingTabBarContentFooter()
                }.padding(.horizontal, TijingDesign.pageHorizontalPadding).padding(.vertical, 12)
            }
        }
        .navigationTitle("补交中心").navigationBarTitleDisplayMode(.inline)
    }
}
