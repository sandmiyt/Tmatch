import SwiftUI

struct AccountSecurityView: View {
    @Environment(SessionStore.self) private var session
    @State private var info: AccountSecurityInfo?

    @State private var passwordCurrent = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""

    @State private var email = ""
    @State private var emailPassword = ""
    @State private var emailCode = ""
    @State private var emailCooldown = 0

    @State private var unbindPassword = ""
    @State private var unbindCode = ""
    @State private var unbindCooldown = 0

    @State private var message: String?
    @State private var busyAction: String?

    var body: some View {
        ZStack {
            TijingPageBackground()
            ScrollView {
                VStack(spacing: TijingDesign.sectionSpacing) {
                    accountSummary
                    passwordSection
                    emailSection
                    if info?.hasEmail == true { unbindSection }
                    if let message { messageCard(message) }
                }
                .padding(.horizontal, TijingDesign.pageHorizontalPadding)
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("账号与安全")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var accountSummary: some View {
        TijingPaperCard(tint: TijingDesign.sky, rotation: -0.2) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    TijingStickerIcon(systemImage: "lock.shield.fill", tint: TijingDesign.indigo, background: TijingDesign.sky, size: 48, rotation: -6)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("账号与安全")
                            .font(.headline)
                        Text("重要操作会要求密码或邮箱验证码确认。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                HStack(spacing: 18) {
                    TijingCompactMetric(value: info?.username ?? session.user?.username ?? "--", label: "8 位数字账号")
                    TijingCompactMetric(value: info?.hasEmail == true ? (info?.email ?? "已验证") : "未绑定", label: "绑定邮箱")
                }
            }
        }
    }

    private var passwordSection: some View {
        VStack(spacing: 12) {
            TijingSectionHeading("修改密码", subtitle: "修改后其他设备上的旧登录会立即失效")
            TijingFieldSurface {
                VStack(spacing: 12) {
                    SecureField("当前密码", text: $passwordCurrent).textContentType(.password)
                    Divider()
                    SecureField("新密码（至少 6 位）", text: $newPassword).textContentType(.newPassword)
                    Divider()
                    SecureField("再次输入新密码", text: $confirmPassword).textContentType(.newPassword)
                    if !confirmPassword.isEmpty, confirmPassword != newPassword {
                        Label("两次输入的新密码不一致", systemImage: "exclamationmark.circle")
                            .font(.footnote).foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            Button {
                Task { await changePassword() }
            } label: {
                if busyAction == "password" { ProgressView().frame(maxWidth: .infinity) }
                else { Text("修改密码").frame(maxWidth: .infinity) }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isBusy || passwordCurrent.count < 4 || newPassword.count < 6 || confirmPassword != newPassword)
        }
    }

    private var emailSection: some View {
        VStack(spacing: 12) {
            TijingSectionHeading(info?.hasEmail == true ? "更换绑定邮箱" : "绑定邮箱", subtitle: info?.hasEmail == true ? "新邮箱验证成功后才会替换当前邮箱" : "绑定后可使用邮箱验证码找回密码")
            TijingPastelCard(tint: TijingDesign.sage) {
                VStack(spacing: 12) {
                    TextField("新的邮箱地址", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Divider().opacity(0.35)
                    SecureField("当前密码", text: $emailPassword)
                    Divider().opacity(0.35)
                    HStack(spacing: 10) {
                        TextField("6 位验证码", text: $emailCode)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .onChange(of: emailCode) { _, value in emailCode = String(value.filter(\.isNumber).prefix(6)) }
                        Button(emailCooldown > 0 ? "\(emailCooldown)s" : "发送") { Task { await sendBindCode() } }
                            .buttonStyle(.bordered)
                            .disabled(isBusy || emailCooldown > 0 || !emailLooksValid || emailPassword.count < 4)
                    }
                }
            }
            Button {
                Task { await bindEmail() }
            } label: {
                Text(info?.hasEmail == true ? "验证并更换" : "验证并绑定")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isBusy || !emailLooksValid || emailPassword.count < 4 || emailCode.count != 6)
        }
    }

    private var unbindSection: some View {
        VStack(spacing: 12) {
            TijingSectionHeading("解绑邮箱", subtitle: "验证码会发送到当前绑定邮箱")
            TijingFieldSurface {
                VStack(alignment: .leading, spacing: 12) {
                    Text(info?.email ?? "当前绑定邮箱")
                        .font(.footnote).foregroundStyle(.secondary)
                    SecureField("当前密码", text: $unbindPassword)
                    Divider()
                    HStack(spacing: 10) {
                        TextField("6 位解绑验证码", text: $unbindCode)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .onChange(of: unbindCode) { _, value in unbindCode = String(value.filter(\.isNumber).prefix(6)) }
                        Button(unbindCooldown > 0 ? "\(unbindCooldown)s" : "发送") { Task { await sendUnbindCode() } }
                            .buttonStyle(.bordered)
                            .disabled(isBusy || unbindCooldown > 0 || unbindPassword.count < 4)
                    }
                }
            }
            Button(role: .destructive) { Task { await unbindEmail() } } label: {
                Text("验证并解绑").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(isBusy || unbindPassword.count < 4 || unbindCode.count != 6)
        }
    }

    private func messageCard(_ text: String) -> some View {
        Label(text, systemImage: "info.circle.fill")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var isBusy: Bool { busyAction != nil }
    private var emailLooksValid: Bool {
        let value = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let at = value.firstIndex(of: "@"), at != value.startIndex else { return false }
        return value[value.index(after: at)...].contains(".")
    }

    @MainActor private func load() async {
        guard let token = session.token else { return }
        do { info = try await session.api.request("/api/account/security", token: token) }
        catch { message = error.localizedDescription }
    }

    @MainActor private func changePassword() async {
        guard let token = session.token else { return }
        guard newPassword == confirmPassword else { message = "两次输入的新密码不一致"; return }
        await perform("password") {
            let response: AuthResponseWithOK = try await session.api.request(
                "/api/account/change-password", method: .post,
                body: ChangePasswordBody(currentPassword: passwordCurrent, newPassword: newPassword), token: token
            )
            session.replaceToken(response.token, user: response.user)
            passwordCurrent = ""; newPassword = ""; confirmPassword = ""
            message = "密码修改成功，其他设备上的旧登录已失效。"
        }
    }

    @MainActor private func sendBindCode() async {
        guard let token = session.token else { return }
        await perform("email-code") {
            let response: CodeResponse = try await session.api.request(
                "/api/account/email/code", method: .post,
                body: AccountEmailCodeBody(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: emailPassword), token: token
            )
            emailCooldown = response.resendIn ?? 60
            startCooldown(kind: .email)
            message = "验证码已发送至 \(response.email ?? "新邮箱")，10 分钟内有效。"
        }
    }

    @MainActor private func bindEmail() async {
        guard let token = session.token else { return }
        await perform("email-bind") {
            let response: AccountSecurityInfo = try await session.api.request(
                "/api/account/email/bind", method: .post,
                body: AccountEmailBindBody(email: email.trimmingCharacters(in: .whitespacesAndNewlines), emailCode: emailCode, password: emailPassword), token: token
            )
            info = AccountSecurityInfo(username: info?.username, hasEmail: response.hasEmail ?? true, email: response.email ?? info?.email)
            email = ""; emailPassword = ""; emailCode = ""; emailCooldown = 0
            message = "邮箱验证成功，已经绑定到当前题竞账号。"
            await load()
        }
    }

    @MainActor private func sendUnbindCode() async {
        guard let token = session.token else { return }
        await perform("email-unbind-code") {
            let response: CodeResponse = try await session.api.request(
                "/api/account/email/unbind/code", method: .post,
                body: PasswordOnlyBody(password: unbindPassword), token: token
            )
            unbindCooldown = response.resendIn ?? 60
            startCooldown(kind: .unbind)
            message = "解绑验证码已发送至 \(response.email ?? info?.email ?? "当前绑定邮箱")，10 分钟内有效。"
        }
    }

    @MainActor private func unbindEmail() async {
        guard let token = session.token else { return }
        await perform("email-unbind") {
            let _: AccountSecurityInfo = try await session.api.request(
                "/api/account/email/unbind", method: .post,
                body: AccountEmailUnbindBody(password: unbindPassword, emailCode: unbindCode), token: token
            )
            unbindPassword = ""; unbindCode = ""; unbindCooldown = 0
            message = "邮箱已解绑。之后如需使用邮箱找回密码，可重新绑定邮箱。"
            await load()
        }
    }

    @MainActor private func perform(_ action: String, _ work: @escaping @MainActor () async throws -> Void) async {
        guard busyAction == nil else { return }
        busyAction = action
        defer { busyAction = nil }
        do { try await work(); Haptics.success() }
        catch { message = error.localizedDescription; Haptics.error() }
    }

    @MainActor private func startCooldown(kind: CooldownKind) {
        Task { @MainActor in
            while true {
                let value = kind == .email ? emailCooldown : unbindCooldown
                guard value > 0 else { return }
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                if kind == .email { emailCooldown = max(0, emailCooldown - 1) }
                else { unbindCooldown = max(0, unbindCooldown - 1) }
            }
        }
    }
}

private enum CooldownKind { case email, unbind }
private struct AccountSecurityInfo: Decodable {
    let username: String?; let hasEmail: Bool?; let email: String?
    enum CodingKeys: String, CodingKey { case username, email; case hasEmail = "has_email" }
}
private struct ChangePasswordBody: Encodable {
    let currentPassword: String; let newPassword: String
    enum CodingKeys: String, CodingKey { case currentPassword = "current_password"; case newPassword = "new_password" }
}
private struct AuthResponseWithOK: Decodable { let ok: Bool?; let token: String; let user: User }
private struct AccountEmailCodeBody: Encodable { let email: String; let password: String }
private struct AccountEmailBindBody: Encodable {
    let email: String; let emailCode: String; let password: String
    enum CodingKeys: String, CodingKey { case email, password; case emailCode = "email_code" }
}
private struct PasswordOnlyBody: Encodable { let password: String }
private struct AccountEmailUnbindBody: Encodable {
    let password: String; let emailCode: String
    enum CodingKeys: String, CodingKey { case password; case emailCode = "email_code" }
}
