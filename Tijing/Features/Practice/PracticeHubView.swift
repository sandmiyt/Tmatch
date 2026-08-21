import SwiftUI

struct PracticeHubView: View {
    var body: some View {
        ZStack {
            TijingPageBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("刷题")
                            .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                        Text("选一个范围，直接进入这一组。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .tijingReveal(order: 0)

                    NavigationLink {
                        PracticeCatalogView(initialMode: .random)
                    } label: {
                        TijingHeroCard(
                            gradient: LinearGradient(
                                colors: [TijingDesign.indigo, Color.accentColor, TijingDesign.cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        ) {
                            VStack(alignment: .leading, spacing: 14) {
                                TijingStickerIcon(
                                    systemImage: "book.pages.fill",
                                    tint: .white,
                                    background: .white.opacity(0.18),
                                    size: 48,
                                    rotation: -5,
                                    sparkle: false
                                )
                                Text("专注刷题")
                                    .font(.system(.title, design: .rounded, weight: .bold))
                                Text("选择题库和章节后开始练习。题量、难度与做题方式继续使用你当前的练习设置；未完成题组仍按原快照续做。")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.80))
                                    .fixedSize(horizontal: false, vertical: true)

                                HStack(spacing: 8) {
                                    Text("开始刷题")
                                        .font(.headline)
                                    Image(systemName: "arrow.right")
                                        .font(.caption.bold())
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(.white.opacity(0.17), in: Capsule())
                            }
                            .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(TijingPressableCardStyle())
                    .tijingTactileLink()
                    .tijingReveal(order: 1)
                }
                .padding(.horizontal, TijingDesign.pageHorizontalPadding)
                .padding(.top, 10)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}
