import SwiftUI
import PhotosUI
import UIKit

struct ProfileView: View {
    @Environment(SessionStore.self) private var session
    @Binding var showingAuth: Bool
    @State private var stats: StatsResponse?
    @State private var confirmLogout = false

    var body: some View {
        Group {
            if let user = session.user {
                List {
                    Section {
                        NavigationLink {
                            PublicProfileView(userID: user.id)
                        } label: {
                            HStack(spacing: 14) {
                                RemoteAvatar(urlString: user.avatarURL, name: user.nickname, size: 62)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(user.nickname)
                                        .font(.title3.bold())
                                        .lineLimit(1)
                                    Text("\(user.rank) · \(user.rating) 竞点")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                    if let bio = user.bio, !bio.isEmpty {
                                        Text(bio)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                            .padding(.vertical, 5)
                        }
                    }

                    Section("学习与对战") {
                        LabeledContent {
                            Text("\(stats?.questions ?? user.questions ?? 0)")
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        } label: {
                            Label("已刷题量", systemImage: "checkmark.circle")
                        }

                        LabeledContent {
                            Text(TijingFormat.percent(stats?.accuracy ?? user.accuracy))
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        } label: {
                            Label("正确率", systemImage: "scope")
                        }

                        LabeledContent {
                            Text("\(stats?.wins ?? user.wins)胜  \(stats?.losses ?? user.losses)负")
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        } label: {
                            Label("排位战绩", systemImage: "trophy")
                        }
                    }

                    Section("个人") {
                        NavigationLink {
                            EditProfileView()
                        } label: {
                            Label("编辑资料", systemImage: "person.crop.circle.badge.pencil")
                        }

                        NavigationLink {
                            AccountSecurityView()
                        } label: {
                            Label("账号与安全", systemImage: "lock.shield")
                        }
                    }

                    Section("记录与社交") {
                        NavigationLink {
                            BattleHistoryView()
                        } label: {
                            Label("历史战绩", systemImage: "clock.arrow.circlepath")
                        }

                        NavigationLink {
                            NotificationsView()
                        } label: {
                            HStack {
                                Label("通知中心", systemImage: "bell")
                                Spacer()
                                if session.unreadNotifications > 0 {
                                    Text("\(session.unreadNotifications)")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 2)
                                        .background(.tint, in: Capsule())
                                }
                            }
                        }

                        NavigationLink {
                            FriendsView()
                        } label: {
                            Label("好友与黑名单", systemImage: "person.2")
                        }
                    }

                    Section("关于与反馈") {
                        NavigationLink {
                            SuggestionView()
                        } label: {
                            Label("功能建议", systemImage: "text.bubble")
                        }

                        NavigationLink {
                            TermsView()
                        } label: {
                            Label("使用条款", systemImage: "doc.text")
                        }

                        NavigationLink {
                            PrivacyView()
                        } label: {
                            Label("隐私政策", systemImage: "hand.raised")
                        }
                    }

                    Section {
                        Button("退出登录", role: .destructive) {
                            Haptics.warning()
                            confirmLogout = true
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable { await refresh() }
            } else {
                ContentUnavailableView {
                    Label("尚未登录", systemImage: "person.crop.circle")
                } description: {
                    Text("登录后可同步你的刷题、错题、收藏、好友和对战数据。")
                } actions: {
                    Button("登录 / 注册") {
                        Haptics.selection()
                        showingAuth = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
        }
        .navigationTitle("我的")
        .navigationBarTitleDisplayMode(.large)
        .task(id: session.user?.id) { await refresh() }
        .confirmationDialog("退出当前账号？", isPresented: $confirmLogout, titleVisibility: .visible) {
            Button("退出登录", role: .destructive) {
                session.logout()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("本机登录状态会被清除；服务器上的刷题、收藏、好友和对战记录不会删除。")
        }
    }

    @MainActor
    private func refresh() async {
        guard let token = session.token else {
            stats = nil
            return
        }
        try? await session.refreshUser()
        stats = try? await session.api.request("/api/stats/me", token: token)
    }
}

struct EditProfileView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var nickname = ""
    @State private var bio = ""
    @State private var gender = "保密"
    @State private var item: PhotosPickerItem?
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        Form {
            Section("头像") {
                HStack {
                    RemoteAvatar(urlString: session.user?.avatarURL, name: session.user?.nickname ?? "题", size: 64)
                    Spacer()
                    PhotosPicker(selection: $item, matching: .images) {
                        Label("选择照片", systemImage: "photo")
                    }
                }
                if session.user?.avatarReviewStatus == "pending" {
                    Text("新头像正在审核，审核通过前继续显示当前头像。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section("资料") {
                TextField("昵称", text: $nickname)
                    .onChange(of: nickname) { _, value in
                        if value.count > 8 { nickname = String(value.prefix(8)) }
                    }
                TextField("简介", text: $bio, axis: .vertical).lineLimit(2...4)
                Picker("性别", selection: $gender) {
                    ForEach(["保密", "男", "女"], id: \.self) { Text($0).tag($0) }
                }
            }
            if let error {
                Section {
                    Label(error, systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("编辑资料")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: gender)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    Task { await save() }
                }
                .bold()
                .disabled(busy || nickname.count < 2 || nickname.count > 8 || bio.count > 50)
            }
        }
        .task {
            nickname = session.user?.nickname ?? ""
            bio = session.user?.bio ?? ""
            gender = session.user?.gender ?? "保密"
        }
        .onChange(of: item) { _, newItem in
            guard let newItem else { return }
            Task { await upload(newItem) }
        }
    }

    @MainActor private func save() async {
        guard let token = session.token else { return }
        busy = true; error = nil; defer { busy = false }
        do {
            let updated: User = try await session.api.request("/api/profile", method: .patch, body: ProfileBody(nickname: nickname, bio: bio, gender: gender), token: token)
            session.user = updated
            Haptics.success(); dismiss()
        } catch { self.error = error.localizedDescription; Haptics.error() }
    }

    @MainActor private func upload(_ item: PhotosPickerItem) async {
        guard let token = session.token else { return }
        busy = true; error = nil; defer { busy = false }
        do {
            guard let raw = try await item.loadTransferable(type: Data.self), let image = UIImage(data: raw) else {
                throw APIError(message: "无法读取照片", statusCode: 0, retryAfter: nil)
            }
            var data = image.jpegData(compressionQuality: 0.86)
            if let current = data, current.count > 3 * 1024 * 1024 { data = image.jpegData(compressionQuality: 0.65) }
            guard let data, data.count <= 3 * 1024 * 1024 else {
                throw APIError(message: "头像处理后仍超过 3MB，请选择尺寸更小的照片", statusCode: 0, retryAfter: nil)
            }
            session.user = try await session.api.uploadAvatar(data, token: token)
            Haptics.success()
        } catch { self.error = error.localizedDescription; Haptics.error() }
    }
}
