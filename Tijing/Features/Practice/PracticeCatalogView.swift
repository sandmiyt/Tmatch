import SwiftUI

/// Direct launcher used by Home and learning-diagnostics shortcuts.
/// It intentionally has no intermediate catalog/settings page: it reads the
/// shared practice settings and immediately starts the requested practice mode.
struct DirectPracticeLauncherView: View {
    @Environment(SessionStore.self) private var session
    let mode: PracticeMode
    var subject: String? = nil
    var topic: String? = nil

    @State private var store: PracticeSessionStore?
    @State private var error: String?

    var body: some View {
        ZStack {
            TijingPageBackground()

            if let store {
                PracticeSessionView(store: store)
            } else if let error {
                ContentUnavailableView(
                    "无法开始\(mode.title)",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("正在准备\(mode.title)…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task { await prepare() }
    }

    @MainActor private func prepare() async {
        guard store == nil else { return }
        guard let token = session.token, let userID = session.user?.id else {
            error = "请先登录"
            return
        }

        do {
            let cacheKey = session.userCacheKey("practice.settings")
            var settings: PracticeSettings
            if let cached: PracticeSettings = session.api.cachedResponse(for: cacheKey) {
                settings = cached
            } else {
                settings = try await session.api.requestCached(
                    "/api/practice/settings", token: token, cacheKey: cacheKey
                )
            }
            settings.normalize()
            store = PracticeSessionStore(
                mode: mode,
                subject: subject,
                topic: topic,
                settings: settings,
                token: token,
                userID: userID
            )
        } catch {
            self.error = error.localizedDescription
        }
    }
}
