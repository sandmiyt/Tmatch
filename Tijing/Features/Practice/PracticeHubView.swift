import SwiftUI

struct PracticeHubView: View {
    var body: some View {
        List {
            Section {
                NavigationLink {
                    PracticeCatalogView(initialMode: .random)
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("专注刷题").font(.headline)
                            Text("选择题库与章节，沿用当前题量、难度和答题方式")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "book.pages.fill")
                            .foregroundStyle(.tint)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("开始练习")
            } footer: {
                Text("当前正式规则会由服务器同步到 iPhone，未完成题组仍按创建时的题目集合与设置续做。")
            }

            Section("复习") {
                NavigationLink {
                    PracticeCatalogView(initialMode: .smartReview)
                } label: {
                    Label("智能复习", systemImage: "brain.head.profile")
                }

                NavigationLink {
                    PracticeCatalogView(initialMode: .wrong)
                } label: {
                    Label("错题重练", systemImage: "arrow.counterclockwise.circle")
                }

                NavigationLink {
                    PracticeCatalogView(initialMode: .favorite)
                } label: {
                    Label("收藏练习", systemImage: "star")
                }
            }

            Section("专项") {
                NavigationLink {
                    PracticeCatalogView(initialMode: .exam)
                } label: {
                    Label("模拟考试", systemImage: "doc.text.magnifyingglass")
                }

                NavigationLink {
                    LearningView()
                } label: {
                    Label("学习诊断", systemImage: "chart.xyaxis.line")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("刷题")
        .navigationBarTitleDisplayMode(.large)
    }
}
