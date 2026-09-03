import SwiftUI

struct TermsView: View {
    var body: some View {
        PolicyArticleView(
            title: "使用条款",
            introduction: "题竞用于个人学习、刷题和好友竞技。请合理使用账号、题库和对战功能，不得利用平台实施骚扰、作弊、恶意刷分、攻击服务或其他影响正常使用的行为。",
            sections: [
                ("账号与资料", "昵称应保持唯一，用户需要妥善保管登录密码。公开头像、昵称和个人简介应遵守平台内容规则；明显不适宜公开展示的内容可能被拦截或驳回。"),
                ("题目与学习数据", "题目仅用于学习练习。用户的练习记录、错题、收藏、排位战绩等用于提供学习功能和统计展示，不应被用于破坏公平性的自动化刷题或刷分。"),
                ("对战公平", "排位赛影响竞点；好友对战和 AI 练习不影响竞点。恶意退出、利用漏洞或其他破坏公平性的行为可能被限制使用相关功能。"),
                ("服务调整", "为了修复问题、提升稳定性或满足合规要求，题竞可能更新功能和规则。重要变化会尽量通过界面提示。")
            ]
        )
    }
}

struct PrivacyView: View {
    var body: some View {
        PolicyArticleView(
            title: "隐私政策",
            introduction: "这里说明题竞会保存哪些信息，以及这些信息如何用于账号、练习、好友和对战功能。",
            sections: [
                ("我们保存的信息", "为了提供账号、练习、好友和对战功能，题竞会保存昵称、已验证邮箱、密码的安全哈希、公开资料、练习记录、错题、收藏、好友关系、排位战绩和必要的访问统计。"),
                ("头像审核", "新头像在公开前会进入管理员审核。待审核图片不会作为公开头像展示，审核结果会保存在账号资料中。"),
                ("账号安全", "密码和邮箱验证码不会以可直接读取的明文长期保存。新用户必须验证邮箱后才能注册；忘记密码时使用绑定邮箱验证码设置新密码，重置成功后旧登录会失效。"),
                ("数据用途", "数据用于登录验证、恢复学习进度、展示排行榜与战绩、改进功能和排查故障。题竞不会因为功能建议而公开用户的私人信息。"),
                ("用户选择", "用户可以修改公开资料、取消收藏、删除好友，也可以通过“功能建议”反馈隐私或产品问题。")
            ]
        )
    }
}

private struct PolicyArticleView: View {
    let title: String
    let introduction: String
    let sections: [(String, String)]

    var body: some View {
        ZStack {
            TijingPageBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    TijingPaperCard(tint: TijingDesign.sky, rotation: -0.2) {
                        HStack(spacing: 13) {
                            TijingStickerIcon(systemImage: title.contains("隐私") ? "hand.raised.fill" : "doc.text.fill", tint: TijingDesign.indigo, background: TijingDesign.sky, size: 50, rotation: -6)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(title)
                                    .font(.title2.bold())
                                Text(introduction)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                    }

                    ForEach(Array(sections.enumerated()), id: \.offset) { index, item in
                        TijingPaperCard(tint: sectionTint(index)) {
                            HStack(alignment: .top, spacing: 12) {
                                TijingStickerIcon(systemImage: sectionIcon(index), tint: TijingDesign.ink.opacity(0.70), background: sectionTint(index), size: 38, rotation: index.isMultiple(of: 2) ? -5 : 5, sparkle: false)
                                VStack(alignment: .leading, spacing: 7) {
                                    Text(item.0).font(.headline)
                                    Text(item.1).font(.body).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, TijingDesign.pageHorizontalPadding)
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .tijingTabBarPageClearance()
    }

    private func sectionTint(_ index: Int) -> Color {
        [TijingDesign.sky, TijingDesign.sage, TijingDesign.butter, TijingDesign.lilac, TijingDesign.peach][index % 5]
    }

    private func sectionIcon(_ index: Int) -> String {
        ["person.crop.circle.fill", "book.closed.fill", "checkmark.shield.fill", "arrow.triangle.2.circlepath", "sparkles"][index % 5]
    }
}
