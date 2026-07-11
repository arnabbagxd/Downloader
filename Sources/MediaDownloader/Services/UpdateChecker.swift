import Foundation

struct AppUpdate: Equatable {
    let version: String
    let releaseURL: URL
    let downloadURL: URL?
}

struct DownloadedUpdate: Equatable {
    let update: AppUpdate
    let fileURL: URL
}

enum UpdateCheckResult: Equatable {
    case upToDate
    case updateAvailable(AppUpdate)
}

enum UpdateCheckError: LocalizedError {
    case invalidResponse
    case missingDownloadAsset

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Could not read the latest GitHub release."
        case .missingDownloadAsset:
            return "The latest GitHub release does not include a downloadable macOS app."
        }
    }
}

struct UpdateChecker {
    private let latestReleaseURL: URL
    private let session: URLSession

    init(
        repository: String = "arnabbagxd/Downloader",
        session: URLSession = .shared
    ) {
        latestReleaseURL = URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
        self.session = session
    }

    func check(currentVersion: String) async throws -> UpdateCheckResult {
        var request = URLRequest(url: latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("DownloadIt", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw UpdateCheckError.invalidResponse
        }

        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        let latestVersion = release.tagName.normalizedVersionTag
        guard Version(latestVersion) > Version(currentVersion.normalizedVersionTag) else {
            return .upToDate
        }

        return .updateAvailable(AppUpdate(
            version: latestVersion,
            releaseURL: release.htmlURL,
            downloadURL: release.preferredDownloadURL
        ))
    }

    func download(_ update: AppUpdate) async throws -> DownloadedUpdate {
        guard let downloadURL = update.downloadURL else {
            throw UpdateCheckError.missingDownloadAsset
        }

        var request = URLRequest(url: downloadURL)
        request.setValue("DownloadIt", forHTTPHeaderField: "User-Agent")

        let (temporaryURL, response) = try await session.download(for: request)
        let fileName = Self.downloadFileName(from: response, fallbackURL: downloadURL)
        let directory = try Self.updateDownloadDirectory(for: update.version)
        let destinationURL = directory.appendingPathComponent(fileName, isDirectory: false)

        try? FileManager.default.removeItem(at: destinationURL)
        try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)

        return DownloadedUpdate(update: update, fileURL: destinationURL)
    }

    static func downloadFileName(from response: URLResponse?, fallbackURL: URL) -> String {
        if let suggested = response?.suggestedFilename, let safe = sanitizedFileName(suggested) {
            return safe
        }

        if let safe = sanitizedFileName(fallbackURL.lastPathComponent) {
            return safe
        }

        return "DownloadIt-update.zip"
    }

    /// Reduces a server-supplied name to a bare, safe filename ending in .zip/.dmg,
    /// preventing path traversal via components like "../".
    private static func sanitizedFileName(_ raw: String) -> String? {
        let base = (raw as NSString).lastPathComponent
        let lowercased = base.lowercased()
        guard !base.isEmpty, base != "..", base != ".",
              lowercased.hasSuffix(".zip") || lowercased.hasSuffix(".dmg") else {
            return nil
        }
        return base
    }

    private static func updateDownloadDirectory(for version: String) throws -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let directory = caches
            .appendingPathComponent("MediaDownloader", isDirectory: true)
            .appendingPathComponent("Updates", isDirectory: true)
            .appendingPathComponent(version, isDirectory: true)

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

struct Version: Comparable, Equatable {
    private let parts: [Int]

    init(_ rawValue: String) {
        parts = rawValue
            .normalizedVersionTag
            .split(separator: ".")
            .map { component in
                let numericPrefix = component.prefix { $0.isNumber }
                return Int(numericPrefix) ?? 0
            }
    }

    static func < (lhs: Version, rhs: Version) -> Bool {
        let count = max(lhs.parts.count, rhs.parts.count)

        for index in 0..<count {
            let left = index < lhs.parts.count ? lhs.parts[index] : 0
            let right = index < rhs.parts.count ? rhs.parts[index] : 0

            if left != right {
                return left < right
            }
        }

        return false
    }
}

private struct GitHubRelease: Decodable {
    struct Asset: Decodable {
        let name: String
        let browserDownloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    let tagName: String
    let htmlURL: URL
    let assets: [Asset]

    var preferredDownloadURL: URL? {
        assets.first { asset in
            asset.name.lowercased().hasSuffix(".dmg")
        }?.browserDownloadURL ?? assets.first { asset in
            let name = asset.name.lowercased()
            return name.hasSuffix(".zip") || name.hasSuffix(".dmg")
        }?.browserDownloadURL
    }

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case assets
    }
}

private extension String {
    var normalizedVersionTag: String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("v") {
            return String(trimmed.dropFirst())
        }

        return trimmed
    }
}
