import Foundation

struct DownloadItem: Identifiable, Codable, Hashable {
    let id: UUID
    let sourceURL: String
    let title: String
    let filePath: String
    let thumbnailPath: String?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        sourceURL: String,
        title: String,
        filePath: String,
        thumbnailPath: String?,
        createdAt: Date
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.title = title
        self.filePath = filePath
        self.thumbnailPath = thumbnailPath
        self.createdAt = createdAt
    }

    var displayName: String {
        if !title.isEmpty {
            return title
        }

        return fileName
    }

    var fileName: String {
        URL(fileURLWithPath: filePath).lastPathComponent
    }

    /// True when the downloaded file is a still image rather than a video.
    var isImageFile: Bool {
        let ext = URL(fileURLWithPath: filePath).pathExtension.lowercased()
        return ["jpg", "jpeg", "png", "webp", "gif", "heic", "bmp", "tiff", "avif"].contains(ext)
    }

    /// True for a bundled .zip, e.g. everything from a Pinterest board/Idea Pin.
    var isZipFile: Bool {
        URL(fileURLWithPath: filePath).pathExtension.lowercased() == "zip"
    }

    var sourceName: String {
        guard let host = URLComponents(string: sourceURL)?.host else {
            return "Web"
        }

        let normalizedHost = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        let source = normalizedHost.split(separator: ".").first.map(String.init) ?? normalizedHost

        switch source.lowercased() {
        case "instagram":
            return "Instagram"
        case "youtube", "youtu":
            return "YouTube"
        case "tiktok":
            return "TikTok"
        case "x", "twitter":
            return "X"
        case "vimeo":
            return "Vimeo"
        default:
            return source.prefix(1).uppercased() + source.dropFirst()
        }
    }
}
