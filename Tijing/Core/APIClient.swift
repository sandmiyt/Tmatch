import Foundation
import CryptoKit

extension Notification.Name {
    static let tijingAuthInvalid = Notification.Name("tijing.auth.invalid")
}

struct EmptyBody: Encodable {}
struct EmptyResponse: Decodable { let ok: Bool? }

enum HTTPMethod: String { case get = "GET", post = "POST", patch = "PATCH", delete = "DELETE", put = "PUT" }

struct APIError: LocalizedError {
    let message: String
    let statusCode: Int
    let retryAfter: Int?

    var errorDescription: String? { message }
}

final class APIClient: @unchecked Sendable {
    static let shared = APIClient()

    let baseURL: URL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let session: URLSession

    init(baseURL: URL? = nil) {
        let configured = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String
        var fallback = URLComponents()
        fallback.scheme = "https"
        fallback.host = "xiaocai.nat100.top"
        self.baseURL = baseURL ?? configured.flatMap(URL.init(string:)) ?? fallback.url ?? URL(fileURLWithPath: "/")
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 9
        config.timeoutIntervalForResource = 25
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadRevalidatingCacheData
        self.session = URLSession(configuration: config)
    }

    func cachedResponse<Response: Decodable>(for cacheKey: String) -> Response? {
        guard let data = Self.readCachedResponseData(for: cacheKey) else { return nil }
        return try? JSONDecoder().decode(Response.self, from: data)
    }

    func requestCached<Response: Decodable>(
        _ path: String,
        token: String? = nil,
        query: [URLQueryItem] = [],
        headers: [String: String] = [:],
        cacheKey: String
    ) async throws -> Response {
        try await request(
            path,
            method: .get,
            bodyData: nil,
            token: token,
            query: query,
            headers: headers,
            responseCacheKey: cacheKey
        )
    }

    func storeCachedResponse<Value: Encodable>(_ value: Value, for cacheKey: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        Self.storeCachedResponseData(data, for: cacheKey)
    }

    func removeCachedResponse(for cacheKey: String) {
        try? FileManager.default.removeItem(at: Self.responseCacheURL(for: cacheKey))
    }

    func clearResponseCache() {
        Self.clearCachedResponses()
    }

    func request<Response: Decodable>(
        _ path: String,
        method: HTTPMethod = .get,
        token: String? = nil,
        query: [URLQueryItem] = [],
        headers: [String: String] = [:]
    ) async throws -> Response {
        try await request(path, method: method, bodyData: nil, token: token, query: query, headers: headers, responseCacheKey: nil)
    }

    func request<Response: Decodable, Body: Encodable>(
        _ path: String,
        method: HTTPMethod,
        body: Body,
        token: String? = nil,
        query: [URLQueryItem] = [],
        headers: [String: String] = [:]
    ) async throws -> Response {
        let data = try encoder.encode(body)
        return try await request(path, method: method, bodyData: data, token: token, query: query, headers: headers, responseCacheKey: nil)
    }

    private func request<Response: Decodable>(
        _ path: String,
        method: HTTPMethod,
        bodyData: Data?,
        token: String?,
        query: [URLQueryItem],
        headers: [String: String],
        responseCacheKey: String?
    ) async throws -> Response {
        let attempts = method == .get ? 2 : 1
        var lastError: Error?
        for attempt in 0..<attempts {
            do {
                var request = try makeRequest(path: path, method: method, token: token, query: query, headers: headers)
                if let bodyData {
                    request.httpBody = bodyData
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                }
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw APIError(message: "服务器响应无效", statusCode: 0, retryAfter: nil)
                }
                guard (200..<300).contains(http.statusCode) else {
                    let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
                    if http.statusCode == 401,
                       let token, !token.isEmpty,
                       http.value(forHTTPHeaderField: "X-Tijing-Auth-Invalid") == "1" {
                        NotificationCenter.default.post(name: .tijingAuthInvalid, object: nil)
                    }
                    var message = Self.errorMessage(from: data) ?? "请求失败（\(http.statusCode)）"
                    if http.statusCode == 429, let retryAfter, retryAfter > 0 {
                        message += "，请 \(retryAfter) 秒后再试"
                    }
                    throw APIError(message: message, statusCode: http.statusCode, retryAfter: retryAfter)
                }
                do {
                    let decoded = try decoder.decode(Response.self, from: data)
                    if let responseCacheKey { Self.storeCachedResponseData(data, for: responseCacheKey) }
                    return decoded
                } catch {
                    throw APIError(message: "服务器数据格式与当前客户端不兼容", statusCode: http.statusCode, retryAfter: nil)
                }
            } catch {
                lastError = error
                if let apiError = error as? APIError, apiError.statusCode == 401 || apiError.statusCode == 429 { break }
                if attempt + 1 < attempts {
                    try? await Task.sleep(for: .milliseconds(350 + attempt * 250))
                }
            }
        }
        if let urlError = lastError as? URLError, urlError.code == .timedOut {
            throw APIError(message: "网络响应较慢，请稍后重试", statusCode: 0, retryAfter: nil)
        }
        throw lastError ?? APIError(message: "请求失败", statusCode: 0, retryAfter: nil)
    }

    func uploadAvatar(_ imageData: Data, token: String) async throws -> User {
        var request = try makeRequest(path: "/api/profile/avatar", method: .post, token: token, query: [], headers: [:])
        let boundary = "TijingBoundary\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        body.appendUTF8("--\(boundary)\r\n")
        body.appendUTF8("Content-Disposition: form-data; name=\"file\"; filename=\"avatar.jpg\"\r\n")
        body.appendUTF8("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        body.appendUTF8("\r\n--\(boundary)--\r\n")
        let (data, response) = try await session.upload(for: request, from: body)
        guard let http = response as? HTTPURLResponse else { throw APIError(message: "服务器响应无效", statusCode: 0, retryAfter: nil) }
        guard (200..<300).contains(http.statusCode) else {
            let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
            if http.statusCode == 401, http.value(forHTTPHeaderField: "X-Tijing-Auth-Invalid") == "1" {
                NotificationCenter.default.post(name: .tijingAuthInvalid, object: nil)
            }
            var message = Self.errorMessage(from: data) ?? "头像上传失败"
            if http.statusCode == 429, let retryAfter, retryAfter > 0 {
                message += "，请 \(retryAfter) 秒后再试"
            }
            throw APIError(message: message, statusCode: http.statusCode, retryAfter: retryAfter)
        }
        return try decoder.decode(AvatarUploadResponse.self, from: data).user
    }

    func webSocketTask(path: String) throws -> URLSessionWebSocketTask {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIError(message: "服务器地址无效", statusCode: 0, retryAfter: nil)
        }
        components.scheme = components.scheme == "https" ? "wss" : "ws"
        components.path = path
        guard let url = components.url else { throw APIError(message: "实时连接地址无效", statusCode: 0, retryAfter: nil) }
        return session.webSocketTask(with: url)
    }

    func assetURL(_ value: String?) -> URL? {
        guard let value, !value.isEmpty else { return nil }
        if let absolute = URL(string: value), absolute.scheme != nil { return absolute }
        return URL(string: value, relativeTo: baseURL)?.absoluteURL
    }

    private static let responseCacheDirectory: URL = {
        let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let directory = root.appendingPathComponent("TijingResponseCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }()

    private static func responseCacheURL(for key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return responseCacheDirectory.appendingPathComponent(digest).appendingPathExtension("json")
    }

    private static func readCachedResponseData(for key: String) -> Data? {
        try? Data(contentsOf: responseCacheURL(for: key), options: [.mappedIfSafe])
    }

    private static func storeCachedResponseData(_ data: Data, for key: String) {
        let url = responseCacheURL(for: key)
        Task.detached(priority: .utility) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private static func clearCachedResponses() {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: responseCacheDirectory, includingPropertiesForKeys: nil
        ) else { return }
        for url in urls { try? FileManager.default.removeItem(at: url) }
    }

    private static func errorMessage(from data: Data) -> String? {
        guard !data.isEmpty,
              let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any] else { return nil }
        if let detail = dictionary["detail"] as? String, !detail.isEmpty { return detail }
        if let error = dictionary["error"] as? String, !error.isEmpty { return error }
        if let detailItems = dictionary["detail"] as? [[String: Any]] {
            let messages = detailItems.compactMap { item -> String? in
                guard let message = item["msg"] as? String, !message.isEmpty else { return nil }
                if let location = item["loc"] as? [Any], !location.isEmpty {
                    let field = location.map { String(describing: $0) }.joined(separator: ".")
                    return "\(field)：\(message)"
                }
                return message
            }
            if !messages.isEmpty { return messages.prefix(2).joined(separator: "；") }
        }
        if let detail = dictionary["detail"] as? [String: Any],
           let message = detail["message"] as? String, !message.isEmpty { return message }
        return nil
    }

    private func makeRequest(path: String, method: HTTPMethod, token: String?, query: [URLQueryItem], headers: [String: String]) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIError(message: "服务器地址无效", statusCode: 0, retryAfter: nil)
        }
        let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
        components.path = normalizedPath
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw APIError(message: "请求地址无效", statusCode: 0, retryAfter: nil) }
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token, !token.isEmpty { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        return request
    }
}

private extension Data {
    mutating func appendUTF8(_ string: String) {
        if let data = string.data(using: .utf8) { append(data) }
    }
}

private struct AvatarUploadResponse: Decodable {
    let user: User
}
