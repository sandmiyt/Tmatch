import SwiftUI
import UIKit
import CryptoKit

struct RemoteAvatar: View {
    let urlString: String?
    let name: String
    var size: CGFloat = 46

    @State private var image: UIImage?
    @State private var failed = false

    init(urlString: String?, name: String, size: CGFloat = 46) {
        self.urlString = urlString
        self.name = name
        self.size = size

        if let url = APIClient.shared.assetURL(urlString) {
            _image = State(initialValue: AvatarImageCache.shared.memoryImage(for: url))
        } else {
            _image = State(initialValue: nil)
        }
    }

    var body: some View {
        ZStack {
            placeholder

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
            } else if failed, APIClient.shared.assetURL(urlString) != nil {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: max(14, size * 0.34), weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.secondary.opacity(0.22), lineWidth: 0.6))
        .accessibilityLabel("\(name)的头像")
        .task(id: urlString) {
            await loadImage()
        }
    }

    private var placeholder: some View {
        ZStack {
            Circle().fill(Color.secondary.opacity(0.10))
            Text(String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased())
                .font(.system(size: max(14, size * 0.36), weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    @MainActor
    private func loadImage() async {
        guard let url = APIClient.shared.assetURL(urlString) else {
            image = nil
            failed = false
            return
        }
        if let cached = AvatarImageCache.shared.memoryImage(for: url) {
            image = cached
            failed = false
            return
        }
        if let loaded = await AvatarImageCache.shared.image(for: url) {
            withAnimation(.easeOut(duration: 0.18)) {
                image = loaded
                failed = false
            }
        } else {
            failed = true
        }
    }
}

private final class AvatarImageCache: @unchecked Sendable {
    static let shared = AvatarImageCache()

    private let memory = NSCache<NSString, UIImage>()
    private let directory: URL
    private let session: URLSession
    private let lock = NSLock()
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]

    private init() {
        memory.countLimit = 220
        memory.totalCostLimit = 48 * 1024 * 1024

        let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        directory = root.appendingPathComponent("TijingAvatarCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 22
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: configuration)

        Task.detached(priority: .background) { [directory] in
            Self.trimDiskCache(in: directory)
        }
    }

    func memoryImage(for url: URL) -> UIImage? {
        memory.object(forKey: url.absoluteString as NSString)
    }

    func image(for url: URL) async -> UIImage? {
        if let image = memoryImage(for: url) { return image }

        let task: Task<UIImage?, Never> = withStateLock {
            if let existing = inFlight[url] { return existing }
            let task = Task.detached(priority: .utility) { [directory, session] in
                let fileURL = Self.fileURL(for: url, in: directory)
                if let data = try? Data(contentsOf: fileURL, options: [.mappedIfSafe]),
                   let image = UIImage(data: data) {
                    return image
                }

                do {
                    let (data, response) = try await session.data(from: url)
                    guard let http = response as? HTTPURLResponse,
                          (200..<300).contains(http.statusCode),
                          let image = UIImage(data: data) else { return nil }
                    try? data.write(to: fileURL, options: .atomic)
                    return image
                } catch {
                    return nil
                }
            }
            inFlight[url] = task
            return task
        }

        let result = await task.value
        withStateLock { inFlight[url] = nil }
        if let result {
            memory.setObject(result, forKey: url.absoluteString as NSString, cost: result.pixelCost)
        }
        return result
    }

    private func withStateLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    private static func fileURL(for url: URL, in directory: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(digest).appendingPathExtension("img")
    }

    private static func trimDiskCache(in directory: URL) {
        let fileManager = FileManager.default
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .fileSizeKey]
        guard let urls = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: Array(keys)) else { return }
        let cutoff = Date().addingTimeInterval(-45 * 24 * 60 * 60)
        var entries: [(URL, Date, Int)] = []
        var totalBytes = 0

        for url in urls {
            let values = try? url.resourceValues(forKeys: keys)
            let date = values?.contentModificationDate ?? .distantPast
            let size = values?.fileSize ?? 0
            if date < cutoff {
                try? fileManager.removeItem(at: url)
                continue
            }
            entries.append((url, date, size))
            totalBytes += size
        }

        let maxBytes = 80 * 1024 * 1024
        guard totalBytes > maxBytes else { return }
        for entry in entries.sorted(by: { $0.1 < $1.1 }) {
            try? fileManager.removeItem(at: entry.0)
            totalBytes -= entry.2
            if totalBytes <= maxBytes { break }
        }
    }
}

private extension UIImage {
    var pixelCost: Int {
        guard let cgImage else { return 0 }
        return cgImage.bytesPerRow * cgImage.height
    }
}
