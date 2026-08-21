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
            .navigationTitle("题竞")
            .navigationBarTitleDisplayMode(.inline)
            .sensoryFeedback(.selection, trigger: mode)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("关闭") { dismiss() } }
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
            VStack(spacing: 18) {
                TijingPaperCard(tint: authTint, rotation: -0.25) {
                    HStack(spacing: 13) {
                        TijingStickerIcon(systemImage: authIcon, tint: authAccent, background: authTint, size: 52, rotation: -7)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(mode.title)
                                .font(.title3.bold())
                            Text(mode.helperText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                }

                Picker("方式", selection: $mode) {
                    ForEach(AuthMode.allCases) { item in Text(item.title).tag(item) }
                }
                .pickerStyle(.segmented)
                .onChange(of: mode) { _, _ in resetForModeSwitch() }

                VStack(spacing: 12) {
                    switch mode {
                    case .login:
                        TijingFieldSurface("账号") {
                            TextField("昵称", text: $account)
                                .textContentType(.username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        TijingFieldSurface("密码") {
                            SecureField("密码", text: $password)
                                .textContentType(.password)
                        }
                    case .register:
                        TijingFieldSurface("昵称") {
                            TextField("最多 8 格", text: $nickname)
                                .textContentType(.nickname)
                                .onChange(of: nickname) { _, value in nickname = String(value.prefix(8)) }
                            Text("\(nickname.count)/8")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        TijingFieldSurface("密码") {
                            SecureField("设置密码（至少 6 位）", text: $password)
                                .textContentType(.newPassword)
                        }
                        TijingFieldSurface("邮箱验证") {
                            TextField("邮箱地址", text: $email)
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .onChange(of: email) { _, _ in code = ""; clearNotice() }
                            Divider()
                            codeRow(
                                placeholder: "邮箱收到的 6 位验证码",
                                cooldown: registerCooldown,
                                actionName: "register-code",
                                enabled: emailLooksValid,
                                sendAction: sendRegisterCode
                            )
                        }
                    case .recover:
                        TijingFieldSurface("找回账号") {
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
                        TijingFieldSurface("新密码") {
                            SecureField("设置新密码（至少 6 位）", text: $newPassword)
                                .textContentType(.newPassword)
                            Divider()
                            SecureField("再次输入新密码", text: $confirmPassword)
                                .textContentType(.newPassword)
                            if !confirmPassword.isEmpty, newPassword != confirmPassword {
                                Label("两次输入的新密码不一致", systemImage: "exclamationmark.circle")
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }

                if let message {
                    Label(message, systemImage: isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(isError ? Color.red : TijingDesign.mint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .tijingCard()
                }

                Button {
                    Haptics.medium()
                    Task { await submit() }
                } label: {
                    HStack(spacing: 8) {
                        if busyAction == "submit" { ProgressView().controlSize(.small).tint(.white) }
                        Text(mode.actionTitle)
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(TijingPrimaryButtonStyle())
                .disabled(isBusy || !canSubmit)
            }
            .padding(.horizontal, TijingDesign.pageHorizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, 30)
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

private enum AuthMode: String, CaseIterable, Identifiable {
    case login, register, recover
    var id: String { rawValue }
    var title: String { switch self { case .login: "登录"; case .register: "注册"; case .recover: "找回" } }
    var actionTitle: String { switch self { case .login: "登录"; case .register: "验证邮箱并注册"; case .recover: "重置密码" } }
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
