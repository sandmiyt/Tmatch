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
        Form {
            Section("账号信息") {
                LabeledContent("8 位数字账号", value: info?.username ?? session.user?.username ?? "--")
                LabeledContent("绑定邮箱", value: info?.hasEmail == true ? (info?.email ?? "已验证") : "未绑定")
            }

            Section("修改密码") {
                SecureField("当前密码", text: $passwordCurrent)
                    .textContentType(.password)
                SecureField("新密码（至少 6 位）", text: $newPassword)
                    .textContentType(.newPassword)
                SecureField("再次输入新密码", text: $confirmPassword)
                    .textContentType(.newPassword)
                if !confirmPassword.isEmpty, confirmPassword != newPassword {
                    Text("两次输入的新密码不一致")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                Button("修改密码") { Task { await changePassword() } }
                    .disabled(isBusy || passwordCurrent.count < 4 || newPassword.count < 6 || confirmPassword != newPassword)
            } footer: {
                Text("修改后其他设备上的旧登录会立即失效，当前 iPhone 会自动换用服务器返回的新 Token。")
            }

            Section(info?.hasEmail == true ? "更换绑定邮箱" : "绑定邮箱") {
                TextField("新的邮箱地址", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("当前密码", text: $emailPassword)
                HStack {
                    TextField("6 位验证码", text: $emailCode)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .onChange(of: emailCode) { _, value in
                            emailCode = String(value.filter(\.isNumber).prefix(6))
                        }
                    Button(emailCooldown > 0 ? "\(emailCooldown)s" : "发送验证码") {
                        Task { await sendBindCode() }
                    }
                    .disabled(isBusy || emailCooldown > 0 || !emailLooksValid || emailPassword.count < 4)
                }
                Button(info?.hasEmail == true ? "验证并更换" : "验证并绑定") {
                    Task { await bindEmail() }
                }
                .disabled(isBusy || !emailLooksValid || emailPassword.count < 4 || emailCode.count != 6)
            } footer: {
                Text(info?.hasEmail == true ? "只有新邮箱验证成功后才会替换当前邮箱。" : "绑定后可使用邮箱验证码找回密码。")
            }

            if info?.hasEmail == true {
                Section("解绑邮箱") {
                    Text("验证码会发送到当前绑定邮箱 \(info?.email ?? "")。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    SecureField("当前密码", text: $unbindPassword)
                    HStack {
                        TextField("6 位解绑验证码", text: $unbindCode)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .onChange(of: unbindCode) { _, value in
                                unbindCode = String(value.filter(\.isNumber).prefix(6))
                            }
                        Button(unbindCooldown > 0 ? "\(unbindCooldown)s" : "发送验证码") {
                            Task { await sendUnbindCode() }
                        }
                        .disabled(isBusy || unbindCooldown > 0 || unbindPassword.count < 4)
                    }
                    Button("验证并解绑", role: .destructive) {
                        Task { await unbindEmail() }
                    }
                    .disabled(isBusy || unbindPassword.count < 4 || unbindCode.count != 6)
                } footer: {
                    Text("解绑后如需使用邮箱找回密码，可重新绑定邮箱。")
                }
            }

            if let message {
                Section { Text(message).foregroundStyle(.secondary) }
            }
        }
        .navigationTitle("账号与安全")
        .task { await load() }
    }

    private var isBusy: Bool { busyAction != nil }
    private var emailLooksValid: Bool {
        let value = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let at = value.firstIndex(of: "@"), at != value.startIndex else { return false }
        return value[value.index(after: at)...].contains(".")
    }

    @MainActor private func load() async {
        guard let token = session.token else { return }
        do {
            info = try await session.api.request("/api/account/security", token: token)
        } catch {
            message = error.localizedDescription
        }
    }

    @MainActor private func changePassword() async {
        guard let token = session.token else { return }
        guard newPassword == confirmPassword else { message = "两次输入的新密码不一致"; return }
        await perform("password") {
            let response: AuthResponseWithOK = try await session.api.request(
                "/api/account/change-password",
                method: .post,
                body: ChangePasswordBody(currentPassword: passwordCurrent, newPassword: newPassword),
                token: token
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
                "/api/account/email/code",
                method: .post,
                body: AccountEmailCodeBody(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: emailPassword),
                token: token
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
                "/api/account/email/bind",
                method: .post,
                body: AccountEmailBindBody(email: email.trimmingCharacters(in: .whitespacesAndNewlines), emailCode: emailCode, password: emailPassword),
                token: token
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
                "/api/account/email/unbind/code",
                method: .post,
                body: PasswordOnlyBody(password: unbindPassword),
                token: token
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
                "/api/account/email/unbind",
                method: .post,
                body: AccountEmailUnbindBody(password: unbindPassword, emailCode: unbindCode),
                token: token
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
        do {
            try await work()
            Haptics.success()
        } catch {
            message = error.localizedDescription
            Haptics.error()
        }
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
    let username: String?
    let hasEmail: Bool?
    let email: String?
    enum CodingKeys: String, CodingKey { case username, email; case hasEmail = "has_email" }
}

private struct ChangePasswordBody: Encodable {
    let currentPassword: String
    let newPassword: String
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
