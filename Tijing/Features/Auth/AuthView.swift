import SwiftUI

struct AuthView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var mode: AuthMode = .login
    @State private var account = ""
    @State private var nickname = ""
    @State private var email = ""
    @State private var code = ""
    @State private var password = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var registerCooldown = 0
    @State private var recoveryCooldown = 0
    @State private var busyAction: String?
    @State private var message: String?
    @State private var isError = false
    @State private var pending: AuthPendingResult?

    var body: some View {
        NavigationStack {
            ZStack {
                TijingPageBackground()
                Group {
                    if let pending {
                        successView(pending)
                    } else {
                        authForm
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .sensoryFeedback(.selection, trigger: mode)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.light()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.bold))
                            .frame(width: 32, height: 32)
                            .background(.thinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("关闭")
                }
            }
            .task {
                if let reason = session.lastError, !reason.isEmpty {
                    message = reason
                    isError = true
                    session.lastError = nil
                }
            }
        }
    }

    private var authForm: some View {
        ScrollView {
            VStack(spacing: 22) {
                authWelcomeHeader
                authModeTabs

                AuthPanel(tint: authTint) {
                    VStack(spacing: 14) {
                        switch mode {
                        case .login:
                            AuthInputSurface(systemImage: "person.text.rectangle", title: "账号") {
                                TextField("昵称或 8 位数字账号", text: $account)
                                    .textContentType(.username)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            }
                            AuthInputSurface(systemImage: "lock.fill", title: "密码") {
                                SecureField("输入密码", text: $password)
                                    .textContentType(.password)
                            }
                        case .register:
                            AuthInputSurface(systemImage: "person.crop.circle", title: "昵称") {
                                VStack(alignment: .leading, spacing: 6) {
                                    TextField("最多 8 格", text: $nickname)
                                        .textContentType(.nickname)
                                        .onChange(of: nickname) { _, value in nickname = String(value.prefix(8)) }
                                    HStack {
                                        Text("将显示在排行榜和好友页面")
                                        Spacer()
                                        Text("\(nickname.count)/8")
                                            .monospacedDigit()
                                    }
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                }
                            }
                            AuthInputSurface(systemImage: "lock.fill", title: "密码") {
                                SecureField("设置密码（至少 6 位）", text: $password)
                                    .textContentType(.newPassword)
                            }
                            AuthInputSurface(systemImage: "envelope.fill", title: "邮箱验证") {
                                VStack(spacing: 12) {
                                    TextField("邮箱地址", text: $email)
                                        .keyboardType(.emailAddress)
                                        .textContentType(.emailAddress)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .onChange(of: email) { _, _ in code = ""; clearNotice() }
                                    Divider()
                                    codeRow(
                                        placeholder: "6 位验证码",
                                        cooldown: registerCooldown,
                                        actionName: "register-code",
                                        enabled: emailLooksValid,
                                        sendAction: sendRegisterCode
                                    )
                                }
                            }
                        case .recover:
                            AuthInputSurface(systemImage: "person.text.rectangle", title: "找回账号") {
                                VStack(spacing: 12) {
                                    TextField("昵称或 8 位数字账号", text: $account)
                                        .textContentType(.username)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .onChange(of: account) { _, _ in code = ""; clearNotice() }
                                    Divider()
                                    codeRow(
                                        placeholder: "邮箱验证码",
                                        cooldown: recoveryCooldown,
                                        actionName: "recovery-code",
                                        enabled: account.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2,
                                        sendAction: sendRecoveryCode
                                    )
                                }
                            }
                            AuthInputSurface(systemImage: "key.fill", title: "新密码") {
                                VStack(spacing: 12) {
                                    SecureField("设置新密码（至少 6 位）", text: $newPassword)
                                        .textContentType(.newPassword)
                                    Divider()
                                    SecureField("再次输入新密码", text: $confirmPassword)
                                        .textContentType(.newPassword)
                                    if !confirmPassword.isEmpty, newPassword != confirmPassword {
                                        Label("两次输入的新密码不一致", systemImage: "exclamationmark.circle")
                                            .font(.footnote)
                                            .foregroundStyle(.red)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                        }

                        if let message {
                            HStack(alignment: .top, spacing: 9) {
                                Image(systemName: isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                                    .foregroundStyle(isError ? Color.red : TijingDesign.mint)
                                Text(message)
                                    .font(.footnote)
                                    .foregroundStyle(isError ? Color.red : Color.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                            .padding(12)
                            .background((isError ? Color.red : TijingDesign.sage).opacity(0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        Button {
                            Haptics.medium()
                            Task { await submit() }
                        } label: {
                            ZStack {
                                HStack(spacing: 8) {
                                    if busyAction == "submit" {
                                        ProgressView().controlSize(.small).tint(.white)
                                    }
                                    Text(mode.actionTitle)
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                HStack {
                                    Spacer()
                                    Image(systemName: "arrow.right")
                                }
                            }
                        }
                        .buttonStyle(TijingPrimaryButtonStyle())
                        .disabled(isBusy || !canSubmit)
                    }
                }
                .id(mode)
                .transition(.opacity.combined(with: .scale(scale: 0.985)))

                Text(authFooterText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
            .padding(.horizontal, TijingDesign.pageHorizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, 34)
            .animation(.spring(response: 0.42, dampingFraction: 0.88), value: mode)
            .animation(.spring(response: 0.34, dampingFraction: 0.9), value: message)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var authWelcomeHeader: some View {
        ZStack {
            HStack {
                TijingStickerIcon(systemImage: "book.pages.fill", tint: TijingDesign.indigo, background: TijingDesign.sky, size: 48, rotation: -9)
                    .offset(x: -5, y: 18)
                Spacer()
                TijingStickerIcon(systemImage: "sparkles", tint: TijingDesign.amber, background: TijingDesign.butter, size: 42, rotation: 8, sparkle: false)
                    .offset(x: 6, y: -10)
            }
            .padding(.horizontal, 10)

            VStack(spacing: 7) {
                TijingStickerIcon(systemImage: authIcon, tint: authAccent, background: authTint, size: 66, rotation: -4)
                Text(mode.heroTitle)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)
                Text(mode.helperText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 52)
        }
        .frame(maxWidth: .infinity, minHeight: 166)
        .accessibilityElement(children: .combine)
    }

    private var authModeTabs: some View {
        HStack(spacing: 6) {
            ForEach(AuthMode.allCases) { item in
                Button {
                    guard mode != item else { return }
                    mode = item
                    resetForModeSwitch()
                } label: {
                    Text(item.title)
                        .font(.subheadline.weight(mode == item ? .semibold : .medium))
                        .foregroundStyle(mode == item ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background {
                            if mode == item {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                                    .shadow(color: .black.opacity(0.055), radius: 8, y: 3)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.04))
        }
    }

    private var authTint: Color {
        switch mode {
        case .login: TijingDesign.sky
        case .register: TijingDesign.sage
        case .recover: TijingDesign.butter
        }
    }

    private var authAccent: Color {
        switch mode {
        case .login: TijingDesign.indigo
        case .register: TijingDesign.mint
        case .recover: TijingDesign.amber
        }
    }

    private var authIcon: String {
        switch mode {
        case .login: "person.crop.circle.fill"
        case .register: "person.crop.circle.badge.plus"
        case .recover: "key.fill"
        }
    }

    private var authFooterText: String {
        switch mode {
        case .login: "登录后会恢复你的刷题进度、收藏、战绩和好友信息。"
        case .register: "邮箱只用于验证与账号找回，不会展示给其他用户。"
        case .recover: "验证通过后会使旧密码失效，并使用新密码继续登录。"
        }
    }

    @ViewBuilder
    private func codeRow(
        placeholder: String,
        cooldown: Int,
        actionName: String,
        enabled: Bool,
        sendAction: @escaping @MainActor () async -> Void
    ) -> some View {
        HStack {
            TextField(placeholder, text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .onChange(of: code) { _, value in code = String(value.filter(\.isNumber).prefix(6)) }
            Button {
                Task { await sendAction() }
            } label: {
                if busyAction == actionName {
                    ProgressView().controlSize(.small)
                } else {
                    Text(cooldown > 0 ? "\(cooldown)s" : "发送验证码")
                }
            }
            .disabled(isBusy || cooldown > 0 || !enabled)
        }
    }

    private func successView(_ result: AuthPendingResult) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                TijingPaperCard(tint: TijingDesign.sage, rotation: -0.3) {
                    VStack(alignment: .leading, spacing: 15) {
                        TijingStickerIcon(systemImage: "checkmark.shield.fill", tint: TijingDesign.mint, background: TijingDesign.sage, size: 60, rotation: -7)
                        Text(result.kind == .register ? "账号创建成功" : "密码已重置")
                            .font(.title2.bold())
                        Text(result.kind == .register
                             ? "邮箱已经验证并绑定到账号，以后忘记密码可以直接通过邮箱找回。"
                             : "新密码已经生效，原来的登录会话已经失效。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if result.kind == .register {
                    TijingPaperCard(tint: TijingDesign.sky) {
                        VStack(alignment: .leading, spacing: 8) {
                            TijingMicroBadge(title: "记住这个账号", systemImage: "number", tint: TijingDesign.indigo)
                            Text(result.username ?? "--")
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                .textSelection(.enabled)
                            Text("8 位数字账号")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let email = result.email, !email.isEmpty {
                                Label(email, systemImage: "envelope.fill")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if result.bannedUntil != nil {
                    Label("密码已经重置，但账号仍处于封禁期，封禁结束后可正常登录。", systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .padding(14)
                        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                Button(result.token != nil && result.user != nil ? "进入题竞" : "返回登录") {
                    if let token = result.token, let user = result.user {
                        session.replaceToken(token, user: user)
                        Haptics.success()
                        dismiss()
                    } else {
                        pending = nil
                        mode = .login
                        resetForModeSwitch()
                    }
                }
                .buttonStyle(TijingPrimaryButtonStyle())
            }
            .padding(.horizontal, TijingDesign.pageHorizontalPadding)
            .padding(.top, 14)
            .padding(.bottom, 30)
        }
    }

    private var isBusy: Bool { busyAction != nil }

    private var emailLooksValid: Bool {
        let value = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.contains(" "), let at = value.firstIndex(of: "@"), at != value.startIndex else { return false }
        let domain = value[value.index(after: at)...]
        return domain.contains(".") && !domain.hasPrefix(".") && !domain.hasSuffix(".")
    }

    private var canSubmit: Bool {
        switch mode {
        case .login:
            return account.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 && password.count >= 4
        case .register:
            let visibleNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
            return visibleNickname.count >= 2 && visibleNickname.count <= 8 && password.count >= 6 && emailLooksValid && code.count == 6
        case .recover:
            return account.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 && code.count == 6 && newPassword.count >= 6 && newPassword == confirmPassword
        }
    }

    @MainActor
    private func sendRegisterCode() async {
        await perform("register-code") {
            let response: CodeResponse = try await session.api.request(
                "/api/auth/register/email-code",
                method: .post,
                body: EmailBody(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
            )
            registerCooldown = response.resendIn ?? 60
            startCooldown(.register)
            message = "验证码已发送至 \(response.email ?? "你的邮箱")，10 分钟内有效。"
        }
    }

    @MainActor
    private func sendRecoveryCode() async {
        await perform("recovery-code") {
            let response: CodeResponse = try await session.api.request(
                "/api/auth/recovery/email-code",
                method: .post,
                body: AccountBody(account: account.trimmingCharacters(in: .whitespacesAndNewlines))
            )
            recoveryCooldown = response.resendIn ?? 60
            startCooldown(.recover)
            message = "验证码已发送至 \(response.email ?? "已绑定邮箱")，10 分钟内有效。"
        }
    }

    @MainActor
    private func submit() async {
        await perform("submit") {
            switch mode {
            case .login:
                try await session.login(account: account.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
                dismiss()
            case .register:
                let response = try await session.register(
                    nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password,
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    code: code
                )
                pending = AuthPendingResult(
                    kind: .register,
                    token: response.token,
                    user: response.user,
                    username: response.credentials?.username ?? response.user.username,
                    email: response.credentials?.email,
                    bannedUntil: nil
                )
                message = nil
            case .recover:
                let body = RecoveryResetBody(
                    account: account.trimmingCharacters(in: .whitespacesAndNewlines),
                    emailCode: code,
                    newPassword: newPassword
                )
                let response: RecoveryResponse = try await session.api.request(
                    "/api/auth/recovery/email-reset",
                    method: .post,
                    body: body
                )
                pending = AuthPendingResult(
                    kind: .recover,
                    token: response.token,
                    user: response.user,
                    username: response.username,
                    email: response.email,
                    bannedUntil: response.bannedUntil
                )
                message = nil
            }
        }
    }

    @MainActor
    private func perform(_ action: String, _ work: @escaping @MainActor () async throws -> Void) async {
        guard busyAction == nil else { return }
        busyAction = action
        message = nil
        isError = false
        defer { busyAction = nil }
        do {
            try await work()
            Haptics.success()
        } catch {
            message = error.localizedDescription
            isError = true
            Haptics.error()
        }
    }

    @MainActor
    private func startCooldown(_ kind: AuthCooldownKind) {
        Task { @MainActor in
            while true {
                let current = kind == .register ? registerCooldown : recoveryCooldown
                guard current > 0 else { return }
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                if kind == .register { registerCooldown = max(0, registerCooldown - 1) }
                else { recoveryCooldown = max(0, recoveryCooldown - 1) }
            }
        }
    }

    private func clearNotice() {
        guard isError == false else { return }
        message = nil
    }

    private func resetForModeSwitch() {
        message = nil
        isError = false
        code = ""
        password = ""
        newPassword = ""
        confirmPassword = ""
    }
}


private struct AuthPanel<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let tint: Color
    private let content: Content

    init(tint: Color, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
            LinearGradient(
                colors: [tint.opacity(colorScheme == .dark ? 0.10 : 0.17), .clear],
                startPoint: .topLeading,
                endPoint: .center
            )
            Circle()
                .fill(tint.opacity(colorScheme == .dark ? 0.08 : 0.16))
                .frame(width: 86, height: 86)
                .offset(x: 30, y: -34)
            content
                .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05))
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.16 : 0.055), radius: 18, y: 9)
    }
}

private struct AuthInputSurface<Content: View>: View {
    let systemImage: String
    let title: String
    private let content: Content

    init(systemImage: String, title: String, @ViewBuilder content: () -> Content) {
        self.systemImage = systemImage
        self.title = title
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(TijingDesign.indigo)
                .frame(width: 34, height: 34)
                .background(TijingDesign.sky.opacity(0.22), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                content
                    .font(.body)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(Color(uiColor: .tertiarySystemGroupedBackground).opacity(0.82), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.045))
        }
    }
}

private enum AuthMode: String, CaseIterable, Identifiable {
    case login, register, recover
    var id: String { rawValue }
    var title: String { switch self { case .login: "登录"; case .register: "注册"; case .recover: "找回" } }
    var actionTitle: String { switch self { case .login: "登录"; case .register: "验证邮箱并注册"; case .recover: "重置密码" } }
    var heroTitle: String { switch self { case .login: "欢迎回来"; case .register: "创建你的题竞账号"; case .recover: "找回你的账号" } }
    var helperText: String {
        switch self {
        case .login: "输入昵称和密码继续学习。"
        case .register: "需要先验证邮箱，验证成功后才能注册。"
        case .recover: "验证码会发送到该账号已经绑定并验证过的邮箱。"
        }
    }
}

private enum AuthResultKind: Equatable { case register, recover }
private enum AuthCooldownKind: Equatable { case register, recover }

private struct AuthPendingResult {
    let kind: AuthResultKind
    let token: String?
    let user: User?
    let username: String?
    let email: String?
    let bannedUntil: String?
}
