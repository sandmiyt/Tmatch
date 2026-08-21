import SwiftUI

struct PracticeHubView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize { return [GridItem(.flexible())] }
        return [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    }

    var body: some View {
        ZStack {
            TijingPageBackground()

            ScrollView {
                LazyVStack(spacing: TijingDesign.sectionSpacing) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("刷题")
                            .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                        Text("少一点设置感，多一点进入状态。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

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
                                Image(systemName: "book.pages.fill")
                                    .font(.system(size: 32, weight: .semibold))
                                Text("专注刷题")
                                    .font(.system(.title, design: .rounded, weight: .bold))
                                Text("选题库和章节，题量、难度与做题方式沿用你当前设置。未完成题组继续按原快照续做。")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.80))
                                    .fixedSize(horizontal: false, vertical: true)

                                HStack(spacing: 8) {
                                    Text("开始一组")
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

                    VStack(spacing: 12) {
                        TijingSectionHeading("按目标练", subtitle: "不用每次都重新配置，直接进入你想要的训练方式")

                        LazyVGrid(columns: columns, spacing: 12) {
                            NavigationLink {
                                PracticeCatalogView(initialMode: .smartReview)
                            } label: {
                                TijingActionTile(
                                    title: "智能复习",
                                    subtitle: "优先处理最容易忘的题",
                                    systemImage: "brain.head.profile",
                                    tint: TijingDesign.violet
                                )
                            }
                            .buttonStyle(TijingPressableCardStyle())
                            .tijingTactileLink()

                            NavigationLink {
                                PracticeCatalogView(initialMode: .wrong)
                            } label: {
                                TijingActionTile(
                                    title: "错题重练",
                                    subtitle: "答对后按原规则移出错题",
                                    systemImage: "arrow.counterclockwise.circle.fill",
                                    tint: TijingDesign.coral
                                )
                            }
                            .buttonStyle(TijingPressableCardStyle())
                            .tijingTactileLink()

                            NavigationLink {
                                PracticeCatalogView(initialMode: .favorite)
                            } label: {
                                TijingActionTile(
                                    title: "收藏练习",
                                    subtitle: "把标记过的重点再过一遍",
                                    systemImage: "star.fill",
                                    tint: TijingDesign.amber
                                )
                            }
                            .buttonStyle(TijingPressableCardStyle())
                            .tijingTactileLink()

                            NavigationLink {
                                PracticeCatalogView(initialMode: .exam)
                            } label: {
                                TijingActionTile(
                                    title: "模拟考试",
                                    subtitle: "完整作答后统一交卷",
                                    systemImage: "doc.text.magnifyingglass",
                                    tint: TijingDesign.mint
                                )
                            }
                            .buttonStyle(TijingPressableCardStyle())
                            .tijingTactileLink()
                        }
                    }

                    VStack(spacing: 12) {
                        TijingSectionHeading("看清短板")
                        NavigationLink {
                            LearningView()
                        } label: {
                            TijingSettingsGroup {
                                TijingSettingsRow(
                                    "学习诊断",
                                    subtitle: "根据近期正确率、速度和错题趋势给出训练重点",
                                    systemImage: "chart.xyaxis.line",
                                    tint: TijingDesign.cyan
                                )
                            }
                        }
                        .buttonStyle(TijingPressableCardStyle())
                        .tijingTactileLink()
                    }
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
