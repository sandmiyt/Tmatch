import Foundation
import Observation
import CryptoKit

struct PracticeReceipt: Codable, Identifiable {
    let id: String
    let owner: Int
    let path: String
    let payload: Data
    let createdAt: Date
    var response: Data?
    var attempts = 0
    var nextAttemptAt = Date.distantPast
    var blocked = false
    var message: String?
}

/// Durable, account-scoped delivery for ordinary practice only. No tokens are stored here.
/// A receipt is retained after acknowledgement so restoring an older practice snapshot
/// cannot accidentally create a second attempt after a crash.
@MainActor @Observable
final class PracticeOutbox {
    static let shared = PracticeOutbox()
    private(set) var entries: [PracticeReceipt] = []
    private(set) var storageError: String?
    private(set) var revision = 0
    private var owner: Int?
    private var token: String?
    private var generation = UUID()
    private var directory: URL?
    private var inFlight: [String: Task<Data, Error>] = [:]
    private var capabilitiesVerified = false
    private let root: URL
    private let api: APIClient
    private let transport: ((String, Data?, String) async throws -> Data)?
    private let now: () -> Date

    init(root: URL? = nil, api: APIClient = .shared,
         transport: ((String, Data?, String) async throws -> Data)? = nil, now: @escaping () -> Date = Date.init) {
        self.api = api
        self.transport = transport
        self.now = now
        self.root = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TijingPracticeOutbox", isDirectory: true)
    }

    var pending: [PracticeReceipt] { entries.filter { $0.response == nil } }

    func activate(userID: Int, token: String) {
        if owner == userID && self.token == token { return }
        deactivate()
        owner = userID
        self.token = token
        let server = SHA256.hash(data: Data(api.baseURL.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
        let folder = root.appendingPathComponent("\(server)-\(userID)", isDirectory: true)
        directory = folder
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            var resource = folder
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try resource.setResourceValues(values)
            // Do not silently replace a damaged queue with an empty one.
            entries = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" }.map {
                    let receipt = try JSONDecoder().decode(PracticeReceipt.self, from: Data(contentsOf: $0))
                    guard receipt.owner == userID else { throw failure("补交记录账号校验失败") }
                    return receipt
                }.sorted { $0.createdAt < $1.createdAt }
        } catch { storageError = "本地补交记录无法读取，请保留 App 数据并联系支持：\(error.localizedDescription)" }
        revision &+= 1
    }

    func deactivate() {
        generation = UUID()
        inFlight.values.forEach { $0.cancel() }
        inFlight = [:]; entries = []; owner = nil; token = nil; directory = nil
        capabilitiesVerified = false; storageError = nil
        revision &+= 1
    }

    func contains(_ id: String) -> Bool { entries.contains { $0.id == id } }
    func response<T: Decodable>(_ id: String, as type: T.Type) -> T? {
        guard let data = entries.first(where: { $0.id == id })?.response else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    func submit<T: Decodable, Body: Encodable>(id: String, path: String, body: Body,
                                              userID: Int, token: String) async throws -> T {
        guard owner == userID, self.token == token else { throw failure("登录状态已变化，请重新打开练习") }
        if let storageError { throw failure(storageError) }
        guard ["/api/practice/answer", "/api/practice/submit"].contains(path),
              id.range(of: "^[A-Za-z0-9_-]{1,96}$", options: .regularExpression) != nil else {
            throw failure("无效的练习提交标识")
        }
        if !contains(id) {
            var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(body)) as? [String: Any] ?? [:]
            object["request_id"] = id
            let payload = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            let receipt = PracticeReceipt(id: id, owner: userID, path: path, payload: payload, createdAt: now())
            try persist(receipt) // Must succeed BEFORE any network write.
            entries.append(receipt); revision &+= 1
        }
        let data = try await deliver(id)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func retryPending() async {
        let epoch = generation
        for id in pending.filter({ !$0.blocked && $0.nextAttemptAt <= now() }).map(\.id) {
            guard !Task.isCancelled, generation == epoch, token != nil else { return }
            do { _ = try await deliver(id) }
            catch let error as APIError where error.statusCode == 401 || error.statusCode == 403 { return }
            catch { }
        }
    }

    private func deliver(_ id: String) async throws -> Data {
        guard let receipt = entries.first(where: { $0.id == id }), let token, let directory else {
            throw failure("请登录原账号后补交")
        }
        if let response = receipt.response { return response }
        if let task = inFlight[id] { return try await task.value }
        if receipt.blocked { throw failure(receipt.message ?? "提交需要处理，请联系支持") }
        guard receipt.nextAttemptAt <= now() else { throw failure("已保存待补交，请稍后重试") }
        let epoch = generation
        let task = Task { () throws -> Data in
            var updated = receipt
            do {
                if !self.capabilitiesVerified {
                    let data = try await self.send("/api/practice/capabilities", payload: nil, token: token)
                    let capabilities = try JSONDecoder().decode(Capabilities.self, from: data)
                    guard capabilities.request_id_deduplication else { throw self.failure("请先更新网页版后端，再补交练习") }
                    try Task.checkCancellation()
                    guard self.generation == epoch else { throw CancellationError() }
                    self.capabilitiesVerified = true
                }
                let data = try await self.send(receipt.path, payload: receipt.payload, token: token)
                // Never acknowledge a 200 response with an incompatible body.
                if receipt.path == "/api/practice/answer" { _ = try JSONDecoder().decode(AnswerFeedback.self, from: data) }
                else { _ = try JSONDecoder().decode(PracticeBatchResult.self, from: data) }
                updated.response = data; updated.message = nil
                // Saving into the captured owner's folder is safe even if the account changed.
                try self.persist(updated, in: directory)
                if self.generation == epoch { self.replace(updated) }
                return data
            } catch {
                updated.attempts += 1
                let apiError = error as? APIError
                updated.blocked = [400, 404, 409, 422].contains(apiError?.statusCode ?? 0) && self.capabilitiesVerified
                updated.message = error.localizedDescription
                let delay = max(apiError?.retryAfter ?? 0, min(300, 5 * (1 << min(updated.attempts, 6))))
                updated.nextAttemptAt = self.now().addingTimeInterval(Double(delay))
                // Failure to save is surfaced; the previously saved immutable payload remains intact.
                do { try self.persist(updated, in: directory) }
                catch { if self.generation == epoch { self.storageError = "补交状态保存失败，请勿卸载 App" } }
                if self.generation == epoch { self.replace(updated) }
                throw error
            }
        }
        inFlight[id] = task
        defer { if generation == epoch { inFlight.removeValue(forKey: id) } }
        return try await task.value
    }

    private func send(_ path: String, payload: Data?, token: String) async throws -> Data {
        if let transport { return try await transport(path, payload, token) }
        return try await api.requestData(path, method: payload == nil ? .get : .post, bodyData: payload, token: token)
    }
    private func persist(_ receipt: PracticeReceipt, in folder: URL? = nil) throws {
        guard let folder = folder ?? directory else { throw failure("补交存储未就绪") }
        #if os(iOS)
        let options: Data.WritingOptions = [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        #else
        let options: Data.WritingOptions = [.atomic]
        #endif
        try JSONEncoder().encode(receipt).write(to: folder.appendingPathComponent(receipt.id + ".json"), options: options)
    }
    private func replace(_ receipt: PracticeReceipt) {
        if let index = entries.firstIndex(where: { $0.id == receipt.id }) { entries[index] = receipt }
        revision &+= 1
    }
    private func failure(_ message: String) -> APIError { APIError(message: message, statusCode: 0, retryAfter: nil) }
    private struct Capabilities: Decodable { let request_id_deduplication: Bool }
}
