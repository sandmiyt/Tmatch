import SwiftUI
import PhotosUI
import UIKit

struct ProfileView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var showingAuth: Bool
    @State private var stats: StatsResponse?
    @State private var confirmLogout = false

    private var metricColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize { return [GridItem(.flexible())] }
        return [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    }

    var body: some View {
        ZStack {
            TijingPageBackground()

            if let user = session.user {
                ScrollView {
                    LazyVStack(spacing: TijingDesign.sectionSpacing) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("我的")
                                .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                            Text("账号、学习和对战，都收在这里。")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        profileHero(user)
                        metricsSection(user)
                        accountSection
                        activitySection
                        supportSection
                        logoutButton
                    }
                    .padding(.horizontal, TijingDesign.pageHorizontalPadding)
                    .padding(.top, 10)
                    .padding(.bottom, 30)
                }
                .refreshable { await refresh() }
            } else {
                signedOutView
                    .padding(.horizontal, TijingDesign.pageHorizontalPadding)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
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

    private func profileHero(_ user: User) -> some View {
        NavigationLink {
            PublicProfileView(userID: user.id)
        } label: {
            TijingHeroCard(
                gradient: LinearGradient(
                    colors: [Color(red: 0.12, green: 0.15, blue: 0.28), TijingDesign.indigo, Color.accentColor],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            ) {
                HStack(spacing: 16) {
                    RemoteAvatar(urlString: user.avatarURL, name: user.nickname, size: 76)
                        .overlay {
                            Circle().stroke(.white.opacity(0.35), lineWidth: 2)
                        }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 7) {
                            Text(user.nickname)
                                .font(.title2.bold())
                                .lineLimit(1)
                            if user.isAdmin == true {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(TijingDesign.cyan)
                            }
                        }
                        Text("\(user.rank) · \(user.rating) 竞点")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.80))
                            .monospacedDigit()
                        if let bio = user.bio, !bio.isEmpty {
                            Text(bio)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.68))
                                .lineLimit(2)
                        } else {
                            Text("给自己留一句上岸宣言")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.62))
                        }
                    }

                    Spacer(minLength: 6)
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.65))
                }
                .foregroundStyle(.white)
            }
        }
        .buttonStyle(TijingPressableCardStyle())
        .tijingTactileLink()
    }

    private func metricsSection(_ user: User) -> some View {
        VStack(spacing: 12) {
            TijingSectionHeading("这一阶段")
            LazyVGrid(columns: metricColumns, spacing: 10) {
                TijingMetricTile(
                    value: "\(stats?.questions ?? user.questions ?? 0)",
                    title: "已刷题量",
                    systemImage: "checkmark.circle.fill",
                    tint: .accentColor
                )
                TijingMetricTile(
                    value: TijingFormat.percent(stats?.accuracy ?? user.accuracy),
                    title: "正确率",
                    systemImage: "scope",
                    tint: TijingDesign.mint
                )
                TijingMetricTile(
                    value: "\(stats?.wins ?? user.wins)胜 \(stats?.losses ?? user.losses)负",
                    title: "排位战绩",
                    systemImage: "trophy.fill",
                    tint: TijingDesign.amber
                )
            }
        }
    }

    private var accountSection: some View {
        VStack(spacing: 12) {
            TijingSectionHeading("账号")
            TijingSettingsGroup {
                NavigationLink {
                    EditProfileView()
                } label: {
                    TijingSettingsRow("编辑资料", subtitle: "头像、昵称、简介与性别", systemImage: "person.crop.circle.badge.pencil", tint: TijingDesign.indigo)
                }
                .buttonStyle(.plain)
                .tijingTactileLink()

                Divider().padding(.leading, 62)

                NavigationLink {
                    AccountSecurityView()
                } label: {
                    TijingSettingsRow("账号与安全", subtitle: "密码、邮箱与登录安全", systemImage: "lock.shield.fill", tint: TijingDesign.mint)
                }
                .buttonStyle(.plain)
                .tijingTactileLink()
            }
        }
    }

    private var activitySection: some View {
        VStack(spacing: 12) {
            TijingSectionHeading("记录与社交")
            TijingSettingsGroup {
                NavigationLink {
                    BattleHistoryView()
                } label: {
                    TijingSettingsRow("历史战绩", systemImage: "clock.arrow.circlepath", tint: TijingDesign.violet)
                }
                .buttonStyle(.plain)
                .tijingTactileLink()

                Divider().padding(.leading, 62)

                NavigationLink {
                    NotificationsView()
                } label: {
                    TijingSettingsRow(
                        "通知中心",
                        systemImage: "bell.fill",
                        tint: TijingDesign.coral,
                        trailing: session.unreadNotifications > 0 ? "\(session.unreadNotifications)" : nil
                    )
                }
                .buttonStyle(.plain)
                .tijingTactileLink()

                Divider().padding(.leading, 62)

                NavigationLink {
                    FriendsView()
                } label: {
                    TijingSettingsRow("好友与黑名单", systemImage: "person.2.fill", tint: TijingDesign.cyan)
                }
                .buttonStyle(.plain)
                .tijingTactileLink()
            }
        }
    }

    private var supportSection: some View {
        VStack(spacing: 12) {
            TijingSectionHeading("关于")
            TijingSettingsGroup {
                NavigationLink {
                    SuggestionView()
                } label: {
                    TijingSettingsRow("功能建议", systemImage: "text.bubble.fill", tint: TijingDesign.amber)
                }
                .buttonStyle(.plain)
                .tijingTactileLink()

                Divider().padding(.leading, 62)

                NavigationLink {
                    TermsView()
                } label: {
                    TijingSettingsRow("使用条款", systemImage: "doc.text.fill", tint: .secondary)
                }
                .buttonStyle(.plain)
                .tijingTactileLink()

                Divider().padding(.leading, 62)

                NavigationLink {
                    PrivacyView()
                } label: {
                    TijingSettingsRow("隐私政策", systemImage: "hand.raised.fill", tint: .secondary)
                }
                .buttonStyle(.plain)
                .tijingTactileLink()
            }
        }
    }

    private var logoutButton: some View {
        Button(role: .destructive) {
            Haptics.warning()
            confirmLogout = true
        } label: {
            Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.bordered)
        .tint(.red)
    }

    private var signedOutView: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 60)
            TijingHeroCard {
                VStack(alignment: .leading, spacing: 14) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 40, weight: .semibold))
                    Text("登录后，这里才是你的")
                        .font(.title2.bold())
                    Text("同步刷题、错题、收藏、好友和排位记录。")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.78))
                    Button {
                        Haptics.medium()
                        showingAuth = true
                    } label: {
                        Text("登录 / 注册")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.white, in: Capsule())
                    }
                    .buttonStyle(TijingPressableCardStyle())
                }
                .foregroundStyle(.white)
            }
            Spacer()
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
