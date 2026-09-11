import SwiftUI
import PhotosUI
import UIKit

struct ProfileView: View {
    @Environment(SessionStore.self) private var session
    @Binding var showingAuth: Bool
    private var stats: StatsResponse? { session.homeStats }
    @State private var confirmLogout = false


    var body: some View {
        ZStack {
            TijingPageBackground()
            if let user = session.user {
                ScrollView {
                    LazyVStack(spacing: 25) {
                        header
                            .tijingReveal(order: 0)
                        identityCard(user)
                            .tijingReveal(order: 1)
                        activitySection
                            .tijingReveal(order: 2)
                        accountSection
                            .tijingReveal(order: 3)
                        supportSection
                            .tijingReveal(order: 4)
                        logoutButton
                            .tijingReveal(order: 5)
                        TijingTabBarContentFooter()
                    }
                    .padding(.horizontal, TijingDesign.pageHorizontalPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 34)
                }
                .refreshable { await refresh() }
            } else {
                signedOutView.padding(.horizontal, TijingDesign.pageHorizontalPadding)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: session.user?.id) { await refresh() }
        .confirmationDialog("退出当前账号？", isPresented: $confirmLogout, titleVisibility: .visible) {
            Button("退出登录", role: .destructive) { session.logout() }
            Button("取消", role: .cancel) { }
        } message: {
            Text("本机登录状态会被清除；服务器上的刷题、收藏、好友和对战记录不会删除。")
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                Text("我的")
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                Text("资料、记录和设置，都收在这里。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            TijingStickerIcon(systemImage: "person.crop.circle.fill", tint: TijingDesign.indigo, background: TijingDesign.sky, size: 52, rotation: 6)
        }
    }

    private func identityCard(_ user: User) -> some View {
        TijingPaperCard(tint: TijingDesign.peach, rotation: -0.25) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 15) {
                    ZStack(alignment: .bottomTrailing) {
                        RemoteAvatar(urlString: user.avatarURL, name: user.nickname, size: 82)
                            .overlay { Circle().stroke(.white.opacity(0.85), lineWidth: 3) }
                            .shadow(color: .black.opacity(0.07), radius: 10, y: 5)
                        TijingFloatingSparkles(tint: TijingDesign.amber)
                            .offset(x: 8, y: 6)
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 7) {
                            Text(user.nickname)
                                .font(.system(.title2, design: .rounded, weight: .bold))
                                .lineLimit(1)
                            if user.isAdmin == true {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(TijingDesign.indigo)
                            }
                        }

                        Text(user.bio.flatMap { $0.isEmpty ? nil : $0 } ?? "写一句属于自己的介绍吧。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)

                        HStack(spacing: 7) {
                            TijingMicroBadge(title: user.rank, systemImage: "seal.fill", tint: TijingDesign.indigo)
                            TijingMicroBadge(title: "\(user.rating) 竞点", systemImage: "sparkles", tint: TijingDesign.amber)
                        }
                    }
                    Spacer(minLength: 0)
                }

                Divider().opacity(0.28)

                HStack(spacing: 0) {
                    identityMetric("\(stats?.questions ?? user.questions ?? 0)", "已刷题", "checkmark.circle.fill", TijingDesign.indigo)
                    Divider().frame(height: 42)
                    identityMetric(TijingFormat.percent(stats?.accuracy ?? user.accuracy), "正确率", "scope", TijingDesign.mint)
                    Divider().frame(height: 42)
                    identityMetric("\(stats?.wins ?? user.wins)胜", "排位胜场", "trophy.fill", TijingDesign.amber)
                }

                NavigationLink {
                    EditProfileView()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "pencil.line")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 30, height: 30)
                            .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        Text("编辑个人资料")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(.tertiary)
                    }
                    .foregroundStyle(.primary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .tijingTactileLink()
            }
        }
    }

    private func identityMetric(_ value: String, _ label: String, _ icon: String, _ tint: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.36), value: value)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }


    private var activitySection: some View {
        VStack(spacing: 12) {
            TijingSectionHeading("记录与社交")
            TijingSettingsGroup {
                navRow("历史战绩", subtitle: "回看对局和逐题详情", icon: "clock.arrow.circlepath", tint: TijingDesign.lilac) { BattleHistoryView() }
                Divider().padding(.leading, 62)
                navRow("通知中心", subtitle: "好友、挑战和系统消息", icon: "bell.fill", tint: TijingDesign.rose, trailing: session.unreadNotifications > 0 ? "\(session.unreadNotifications)" : nil) { NotificationsView() }
                Divider().padding(.leading, 62)
                navRow("好友与黑名单", subtitle: "好友状态、邀请和管理", icon: "person.2.fill", tint: TijingDesign.sky) { FriendsView() }
            }
        }
    }

    private var accountSection: some View {
        VStack(spacing: 12) {
            TijingSectionHeading("账号")
            TijingSettingsGroup {
                navRow("账号与安全", subtitle: "密码、邮箱与登录安全", icon: "lock.shield.fill", tint: TijingDesign.sage) { AccountSecurityView() }
            }
        }
    }

    private var supportSection: some View {
        VStack(spacing: 12) {
            TijingSectionHeading("关于")
            TijingSettingsGroup {
                navRow("功能建议", subtitle: "告诉我们哪里还能更顺手", icon: "text.bubble.fill", tint: TijingDesign.butter) { SuggestionView() }
                Divider().padding(.leading, 62)
                navRow("使用条款", subtitle: nil, icon: "doc.text.fill", tint: .secondary) { TermsView() }
                Divider().padding(.leading, 62)
                navRow("隐私政策", subtitle: nil, icon: "hand.raised.fill", tint: .secondary) { PrivacyView() }
            }
        }
    }

    private func navRow<Destination: View>(_ title: String, subtitle: String?, icon: String, tint: Color, trailing: String? = nil, @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink(destination: destination()) {
            TijingSettingsRow(title, subtitle: subtitle, systemImage: icon, tint: tint, trailing: trailing)
        }
        .buttonStyle(.plain)
        .tijingTactileLink()
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
            TijingPaperCard(tint: TijingDesign.sky, rotation: -0.5) {
                VStack(alignment: .leading, spacing: 15) {
                    TijingStickerIcon(systemImage: "person.crop.circle.badge.plus", tint: TijingDesign.indigo, background: TijingDesign.sky, size: 56)
                    Text("登录后，这里才是你的")
                        .font(.title2.bold())
                    Text("同步刷题、错题、收藏、好友和排位记录。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        Haptics.medium()
                        showingAuth = true
                    } label: {
                        Text("登录 / 注册")
                            .font(.headline)
                            .foregroundStyle(Color(uiColor: .systemBackground))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 11)
                            .background(TijingDesign.ink, in: Capsule())
                    }
                    .buttonStyle(TijingPressableCardStyle())
                }
            }
            Spacer()
        }
    }

    @MainActor
    private func refresh() async {
        guard session.token != nil else { return }
        try? await session.refreshUser()
        try? await session.refreshHomeSnapshot()
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
        ZStack {
            TijingPageBackground()
            ScrollView {
                VStack(spacing: 18) {
                    TijingPastelCard(tint: TijingDesign.peach) {
                        VStack(spacing: 14) {
                            RemoteAvatar(urlString: session.user?.avatarURL, name: session.user?.nickname ?? "题", size: 92)
                                .overlay { Circle().stroke(.white.opacity(0.75), lineWidth: 3) }
                            PhotosPicker(selection: $item, matching: .images) {
                                Label("更换头像", systemImage: "photo")
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .background(.white.opacity(0.48), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            if session.user?.avatarReviewStatus == "pending" {
                                Text("新头像正在审核，审核通过前继续显示当前头像。")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }

                    TijingFieldSurface("昵称") {
                        TextField("2～8 个字符", text: $nickname)
                            .textContentType(.nickname)
                            .onChange(of: nickname) { _, value in
                                if value.count > 8 { nickname = String(value.prefix(8)) }
                            }
                    }

                    TijingFieldSurface("个人简介") {
                        TextField("写一句简单的介绍", text: $bio, axis: .vertical)
                            .lineLimit(3...6)
                        Text("\(bio.count)/50")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    TijingFieldSurface("性别") {
                        Picker("性别", selection: $gender) {
                            ForEach(["保密", "男", "女"], id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }

                    if let error {
                        Label(error, systemImage: "exclamationmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    TijingTabBarContentFooter()
                }
                .padding(.horizontal, TijingDesign.pageHorizontalPadding)
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("编辑资料")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: gender)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(busy ? "保存中…" : "保存") { Task { await save() } }
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
            session.updateCurrentUser(updated)
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
            session.updateCurrentUser(try await session.api.uploadAvatar(data, token: token))
            Haptics.success()
        } catch { self.error = error.localizedDescription; Haptics.error() }
    }
}
