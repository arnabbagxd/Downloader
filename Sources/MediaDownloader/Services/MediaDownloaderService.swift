import Foundation

enum MediaDownloaderError: LocalizedError {
    case missingTool(String)
    case processFailed(String)
    case missingOutputFile

    var errorDescription: String? {
        switch self {
        case .missingTool(let tool):
            return "\(tool) was not found in PATH."
        case .processFailed(let message):
            return message.isEmpty ? "Download failed." : message
        case .missingOutputFile:
            return "Download finished but no output file was found."
        }
    }
}

actor MediaDownloaderService {
    private let fileManager = FileManager.default

    func download(
        sourceURL: String,
        destinationFolder: URL,
        formatSelector: String? = nil,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> DownloadResult {
        guard let ytDlp = ToolManager.ytDlpPath else { throw MediaDownloaderError.missingTool("yt-dlp") }
        guard let ffmpeg = ToolManager.ffmpegPath else { throw MediaDownloaderError.missingTool("ffmpeg") }
        try fileManager.createDirectory(at: destinationFolder, withIntermediateDirectories: true)

        let startDate = Date()
        var arguments = [
            "--no-playlist",
            "--newline",
            "--restrict-filenames",
            // Download in parallel pieces for a real throughput boost on fragmented sources.
            "--concurrent-fragments", "4",
            "--merge-output-format", "mp4",
            // Remux into an mp4 container (fast stream copy) instead of forcing a full
            // re-encode; combined with the -S sort below, the source is almost always
            // already h264/aac, so this just repackages it instead of re-encoding it.
            "--remux-video", "mp4",
            "-S", "vcodec:h264,acodec:aac,ext:mp4:m4a",
            "--ffmpeg-location", ffmpeg
        ]

        // Cap the resolution when the user picked a specific quality.
        if let formatSelector {
            arguments += ["-f", formatSelector]
        }

        arguments += [
            "--paths", destinationFolder.path,
            "--output", "%(title).180B [%(id)s].%(ext)s",
            "--print", "after_move:%(filepath)s",
            "--print", "after_move:%(title)s",
            sourceURL
        ]

        // Track the highest percentage seen so the ring only ever moves forward,
        // even though yt-dlp reports separate 0-100% passes for video and audio.
        let highestProgress = ProgressTracker()
        let output = try await runProcess(executable: ytDlp, arguments: arguments) { line in
            guard let onProgress, let fraction = Self.parseProgress(from: line) else { return }
            if let advanced = highestProgress.advance(to: fraction) {
                onProgress(advanced)
            }
        }
        let lines = output
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let filePath = lines.first(where: { $0.hasPrefix("/") && fileManager.fileExists(atPath: $0) })
        let fileURL = try filePath.map(URL.init(fileURLWithPath:)) ?? newestMediaFile(in: destinationFolder, after: startDate)
        let title = lines.last(where: { !$0.hasPrefix("/") }) ?? fileURL.deletingPathExtension().lastPathComponent
        return DownloadResult(fileURL: fileURL, title: title)
    }

    /// Fetches a link's title, the distinct video heights it offers (highest first), and —
    /// for image-only posts — the full-resolution image URLs. Never downloads media.
    func probe(sourceURL: String) async throws -> VideoProbe {
        guard let ytDlp = ToolManager.ytDlpPath else { throw MediaDownloaderError.missingTool("yt-dlp") }

        // --ignore-no-formats-error keeps image-only posts (e.g. Instagram photos) from
        // failing outright; their metadata still contains full-resolution "thumbnails".
        let output = try await runProcess(executable: ytDlp, arguments: [
            "--no-playlist", "--no-warnings", "--ignore-no-formats-error", "-J", sourceURL
        ])

        guard let data = output.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return VideoProbe(title: nil, heights: [], imageURLs: [])
        }

        // Carousel/gallery posts arrive as a playlist of entries; single posts as one dict.
        let entries = (json["entries"] as? [[String: Any]]) ?? [json]
        var heights = Set<Int>()
        var imageURLs: [String] = []

        for entry in entries {
            var entryHasVideo = false

            if let formats = entry["formats"] as? [[String: Any]] {
                for format in formats {
                    // Skip audio-only formats.
                    if let vcodec = format["vcodec"] as? String, vcodec == "none" { continue }
                    if let height = intValue(format["height"]), height > 0 {
                        heights.insert(height)
                        entryHasVideo = true
                    }
                }
            }

            // Some extractors report a single muxed height at the top level.
            if !entryHasVideo, let height = intValue(entry["height"]), height > 0 {
                heights.insert(height)
                entryHasVideo = true
            }

            // No video in this entry: its largest thumbnail IS the image (last = biggest).
            if !entryHasVideo,
               let thumbnails = entry["thumbnails"] as? [[String: Any]],
               let imageURL = thumbnails.last?["url"] as? String {
                imageURLs.append(imageURL)
            }
        }

        let rawTitle = (json["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = (rawTitle?.isEmpty == false) ? rawTitle : nil

        return VideoProbe(title: title, heights: heights.sorted(by: >), imageURLs: imageURLs)
    }

    /// Downloads one or more images straight over HTTPS into the destination folder.
    func downloadImages(
        imageURLs: [String],
        title: String?,
        destinationFolder: URL,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> [DownloadResult] {
        try fileManager.createDirectory(at: destinationFolder, withIntermediateDirectories: true)

        var results: [DownloadResult] = []

        for (index, urlString) in imageURLs.enumerated() {
            guard let url = URL(string: urlString) else { continue }

            let (temporaryURL, response) = try await URLSession.shared.download(from: url)
            let baseName = Self.imageBaseName(title: title, index: index, total: imageURLs.count)
            let fileExtension = Self.imageExtension(response: response, url: url)
            let destination = Self.uniqueDestination(
                in: destinationFolder,
                baseName: baseName,
                fileExtension: fileExtension,
                fileManager: fileManager
            )

            try fileManager.moveItem(at: temporaryURL, to: destination)
            results.append(DownloadResult(fileURL: destination, title: baseName))
            onProgress?(Double(index + 1) / Double(imageURLs.count))
        }

        guard !results.isEmpty else {
            throw MediaDownloaderError.missingOutputFile
        }

        return results
    }

    /// A playlist or channel URL can contain hundreds/thousands of videos; cap extraction
    /// so a probe stays fast and a bulk download stays bounded.
    static let maxPlaylistItems = 50

    /// Cheap heuristic to avoid running an extra yt-dlp lookup on every plain video link:
    /// only URLs that look like a playlist/channel/user page trigger the flat-playlist probe.
    static func mightBePlaylistOrChannel(_ sourceURL: String) -> Bool {
        guard let url = URL(string: sourceURL) else { return false }
        let path = url.path.lowercased()
        let query = url.query?.lowercased() ?? ""

        if query.contains("list=") { return true }
        let markers = ["/playlist", "/playlists", "/channel/", "/c/", "/user/", "/videos", "/uploads", "/@"]
        return markers.contains { path.contains($0) }
    }

    /// Probes a link that might be a playlist or channel using `--flat-playlist`, which is
    /// fast because it doesn't resolve formats for every entry. Returns `nil` when the link
    /// turns out to be a single video, so the caller can fall back to the normal flow.
    func probePlaylist(sourceURL: String) async throws -> PlaylistProbeResult? {
        guard let ytDlp = ToolManager.ytDlpPath else { throw MediaDownloaderError.missingTool("yt-dlp") }

        let output = try await runProcess(executable: ytDlp, arguments: [
            "--flat-playlist", "--no-warnings", "--ignore-no-formats-error",
            "--playlist-items", "1-\(Self.maxPlaylistItems)",
            "-J", sourceURL
        ])

        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        guard (json["_type"] as? String) == "playlist",
              let rawEntries = json["entries"] as? [[String: Any]],
              rawEntries.count > 1 else {
            return nil
        }

        let rawTitle = (json["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = (rawTitle?.isEmpty == false) ? rawTitle : nil

        let entries: [PlaylistEntry] = rawEntries.compactMap { entry in
            guard let id = entry["id"] as? String else { return nil }
            let webpageURL = (entry["url"] as? String) ?? (entry["webpage_url"] as? String) ?? id
            let rawEntryTitle = (entry["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return PlaylistEntry(id: id, webpageURL: webpageURL, title: (rawEntryTitle?.isEmpty == false) ? rawEntryTitle : nil)
        }

        guard entries.count > 1 else { return nil }
        return PlaylistProbeResult(title: title, entries: entries)
    }

    /// Downloads every entry in a playlist/channel into the destination folder, one at a
    /// time. A single failed item is skipped rather than aborting the whole batch.
    func downloadPlaylistItems(
        _ entries: [PlaylistEntry],
        destinationFolder: URL,
        formatSelector: String?,
        onItemStart: (@Sendable (Int, Int, String?) -> Void)? = nil
    ) async throws -> [DownloadResult] {
        var results: [DownloadResult] = []

        for (index, entry) in entries.enumerated() {
            onItemStart?(index, entries.count, entry.title)
            if let result = try? await download(
                sourceURL: entry.webpageURL,
                destinationFolder: destinationFolder,
                formatSelector: formatSelector
            ) {
                results.append(result)
            }
        }

        guard !results.isEmpty else {
            throw MediaDownloaderError.missingOutputFile
        }

        return results
    }

    /// Board/profile links can contain hundreds of pins; cap extraction so it stays bounded.
    static let maxCollectionItems = 30

    static func isPinterestLink(_ sourceURL: String) -> Bool {
        guard let host = URL(string: sourceURL)?.host?.lowercased() else { return false }
        return host.contains("pinterest.") || host == "pin.it" || host.hasSuffix(".pin.it")
    }

    /// True for a full Instagram profile link (e.g. instagram.com/someuser) as opposed to
    /// a single post, reel, story, or one of Instagram's other non-profile paths.
    static func isInstagramProfileLink(_ sourceURL: String) -> Bool {
        guard let url = URL(string: sourceURL), let host = url.host?.lowercased() else { return false }
        guard host == "instagram.com" || host.hasSuffix(".instagram.com") else { return false }

        let segments = url.path.split(separator: "/").map(String.init)
        guard segments.count == 1 else { return false }

        let reservedPaths: Set<String> = [
            "p", "reel", "reels", "tv", "stories", "explore", "accounts",
            "direct", "direct_v2", "about", "developer", "legal", "web"
        ]
        return !reservedPaths.contains(segments[0].lowercased())
    }

    /// Probes a Pinterest pin/Idea Pin/board or an Instagram profile for every video/image
    /// it contains. A single pin returns one item; a board, Idea Pin, or profile returns
    /// several. `capItems` bounds how many entries are fetched (always applied for
    /// profiles/boards, which can hold hundreds of posts).
    func probeCollection(sourceURL: String, capItems: Bool) async throws -> CollectionProbeResult {
        guard let ytDlp = ToolManager.ytDlpPath else { throw MediaDownloaderError.missingTool("yt-dlp") }

        var arguments = ["--no-warnings", "--ignore-no-formats-error", "-J"]
        if capItems {
            arguments += ["--playlist-items", "1-\(Self.maxCollectionItems)"]
        }
        arguments.append(sourceURL)

        let output = try await runProcess(executable: ytDlp, arguments: arguments)
        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return CollectionProbeResult(title: nil, items: [])
        }

        let rawOverallTitle = (json["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let overallTitle = (rawOverallTitle?.isEmpty == false) ? rawOverallTitle : nil

        let rawEntries = (json["entries"] as? [Any]) ?? [json]
        var items: [CollectionItem] = []

        for case let entry as [String: Any] in rawEntries {
            var heights = Set<Int>()
            if let formats = entry["formats"] as? [[String: Any]] {
                for format in formats {
                    if let vcodec = format["vcodec"] as? String, vcodec == "none" { continue }
                    if let height = intValue(format["height"]), height > 0 {
                        heights.insert(height)
                    }
                }
            }
            if heights.isEmpty, let height = intValue(entry["height"]), height > 0 {
                heights.insert(height)
            }

            let imageURL: String? = heights.isEmpty
                ? (entry["thumbnails"] as? [[String: Any]])?.last?["url"] as? String
                : nil

            // Skip entries that are neither a video nor an image (e.g. a private/deleted pin).
            guard !heights.isEmpty || imageURL != nil else { continue }

            let webpageURL = (entry["webpage_url"] as? String) ?? sourceURL
            let rawTitle = (entry["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

            items.append(CollectionItem(
                webpageURL: webpageURL,
                title: (rawTitle?.isEmpty == false) ? rawTitle : nil,
                heights: heights.sorted(by: >),
                imageURL: imageURL
            ))
        }

        return CollectionProbeResult(title: overallTitle, items: items)
    }

    /// Downloads every item in a collection (Pinterest board/Idea Pin, or Instagram
    /// profile) into a fresh temporary folder. Returns the saved files plus that folder,
    /// so the caller can clean it up once it's done with them (e.g. after zipping). One
    /// failed item doesn't stop the rest.
    func downloadCollectionItems(
        _ items: [CollectionItem],
        onItemStart: (@Sendable (Int, Int, String?) -> Void)? = nil,
        onItemFinish: (@Sendable (Int, Int) -> Void)? = nil
    ) async throws -> (files: [URL], directory: URL) {
        guard let ytDlp = ToolManager.ytDlpPath else { throw MediaDownloaderError.missingTool("yt-dlp") }
        guard let ffmpeg = ToolManager.ffmpegPath else { throw MediaDownloaderError.missingTool("ffmpeg") }

        let workingDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: workingDirectory, withIntermediateDirectories: true)

        var savedFiles: [URL] = []
        let total = items.count

        for (index, item) in items.enumerated() {
            onItemStart?(index, total, item.title)

            if item.isImage, let imageURLString = item.imageURL, let imageURL = URL(string: imageURLString) {
                if let saved = try? await downloadCollectionImage(imageURL, title: item.title, index: index, total: total, into: workingDirectory) {
                    savedFiles.append(saved)
                }
            } else if !item.heights.isEmpty {
                if let saved = try? await downloadCollectionVideo(item, ytDlp: ytDlp, ffmpeg: ffmpeg, index: index, total: total, into: workingDirectory) {
                    savedFiles.append(saved)
                }
            }

            onItemFinish?(index + 1, total)
        }

        guard !savedFiles.isEmpty else {
            try? fileManager.removeItem(at: workingDirectory)
            throw MediaDownloaderError.missingOutputFile
        }

        return (savedFiles, workingDirectory)
    }

    private func downloadCollectionImage(
        _ imageURL: URL,
        title: String?,
        index: Int,
        total: Int,
        into workingDirectory: URL
    ) async throws -> URL {
        let (temporaryURL, response) = try await URLSession.shared.download(from: imageURL)
        let baseName = Self.imageBaseName(title: title, index: index, total: total)
        let fileExtension = Self.imageExtension(response: response, url: imageURL)
        let destination = Self.uniqueDestination(
            in: workingDirectory, baseName: baseName, fileExtension: fileExtension, fileManager: fileManager
        )
        try fileManager.moveItem(at: temporaryURL, to: destination)
        return destination
    }

    private func downloadCollectionVideo(
        _ item: CollectionItem,
        ytDlp: String,
        ffmpeg: String,
        index: Int,
        total: Int,
        into workingDirectory: URL
    ) async throws -> URL {
        let itemDirectory = workingDirectory.appendingPathComponent("item-\(index)", isDirectory: true)
        try fileManager.createDirectory(at: itemDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: itemDirectory) }

        _ = try await runProcess(executable: ytDlp, arguments: [
            "--no-playlist", "--restrict-filenames",
            "--merge-output-format", "mp4",
            "--remux-video", "mp4",
            "-S", "vcodec:h264,acodec:aac,ext:mp4:m4a",
            "--ffmpeg-location", ffmpeg,
            "-f", "bv*[height<=?1080]+ba/b[height<=?1080]",
            "--paths", itemDirectory.path,
            "--output", "%(title).120B.%(ext)s",
            item.webpageURL
        ])

        guard let downloaded = try fileManager.contentsOfDirectory(at: itemDirectory, includingPropertiesForKeys: nil).first else {
            throw MediaDownloaderError.missingOutputFile
        }

        let baseName = Self.imageBaseName(title: item.title, index: index, total: total)
        let destination = Self.uniqueDestination(
            in: workingDirectory, baseName: baseName, fileExtension: downloaded.pathExtension, fileManager: fileManager
        )
        try fileManager.moveItem(at: downloaded, to: destination)
        return destination
    }

    static func imageBaseName(title: String?, index: Int, total: Int) -> String {
        var base = (title ?? "Image").trimmingCharacters(in: .whitespacesAndNewlines)
        if base.isEmpty { base = "Image" }

        // Keep the filename filesystem-safe and reasonably short.
        base = base
            .components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>"))
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        base = String(base.prefix(120))

        return total > 1 ? "\(base) \(index + 1)" : base
    }

    static func imageExtension(response: URLResponse?, url: URL) -> String {
        switch response?.mimeType?.lowercased() {
        case "image/jpeg": return "jpg"
        case "image/png": return "png"
        case "image/webp": return "webp"
        case "image/gif": return "gif"
        case "image/heic": return "heic"
        default:
            let ext = url.pathExtension.lowercased()
            return ["jpg", "jpeg", "png", "webp", "gif", "heic", "bmp", "tiff", "avif"].contains(ext) ? ext : "jpg"
        }
    }

    private static func uniqueDestination(
        in folder: URL,
        baseName: String,
        fileExtension: String,
        fileManager: FileManager
    ) -> URL {
        var candidate = folder.appendingPathComponent(baseName).appendingPathExtension(fileExtension)
        var counter = 2

        while fileManager.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(baseName)-\(counter)").appendingPathExtension(fileExtension)
            counter += 1
        }

        return candidate
    }

    private func intValue(_ value: Any?) -> Int? {
        if let int = value as? Int { return int }
        if let double = value as? Double { return Int(double) }
        return nil
    }

    private func newestMediaFile(in folder: URL, after date: Date) throws -> URL {
        let extensions = Set(["mp4", "m4v", "mov"])
        let files = try fileManager.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        let candidates = files.compactMap { url -> (URL, Date)? in
            guard extensions.contains(url.pathExtension.lowercased()) else {
                return nil
            }

            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            guard let modified = values?.contentModificationDate, modified >= date.addingTimeInterval(-2) else {
                return nil
            }

            return (url, modified)
        }

        guard let newest = candidates.max(by: { $0.1 < $1.1 })?.0 else {
            throw MediaDownloaderError.missingOutputFile
        }

        return newest
    }

    private func runProcess(
        executable: String,
        arguments: [String],
        onLine: (@Sendable (String) -> Void)? = nil
    ) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let stdout = Pipe()
            let stderr = Pipe()

            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.environment = DependencyChecker.processEnvironment
            process.standardOutput = stdout
            process.standardError = stderr

            // Collect output as it streams so progress lines can be parsed live.
            let collector = OutputCollector(onLine: onLine)
            stdout.fileHandleForReading.readabilityHandler = { handle in
                collector.appendStdout(handle.availableData)
            }
            stderr.fileHandleForReading.readabilityHandler = { handle in
                collector.appendStderr(handle.availableData)
            }

            process.terminationHandler = { process in
                stdout.fileHandleForReading.readabilityHandler = nil
                stderr.fileHandleForReading.readabilityHandler = nil
                // Drain anything buffered after the last readability callback.
                collector.appendStdout(stdout.fileHandleForReading.readDataToEndOfFile())
                collector.appendStderr(stderr.fileHandleForReading.readDataToEndOfFile())

                let (output, error) = collector.finish()
                if process.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    continuation.resume(throwing: MediaDownloaderError.processFailed(error))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Extracts a 0.0-1.0 fraction from a yt-dlp progress line like "[download]  42.3% of ...".
    static func parseProgress(from line: String) -> Double? {
        guard line.contains("[download]"), let percentRange = line.range(of: "%") else {
            return nil
        }

        // Walk backwards from the '%' to grab the number in front of it.
        var digits = ""
        var index = percentRange.lowerBound
        while index > line.startIndex {
            index = line.index(before: index)
            let character = line[index]
            if character.isNumber || character == "." {
                digits.insert(character, at: digits.startIndex)
            } else if character == " " {
                if digits.isEmpty { continue }
                break
            } else {
                break
            }
        }

        guard let value = Double(digits) else { return nil }
        return min(max(value / 100.0, 0), 1)
    }
}

/// Thread-safe holder that only lets the reported progress move forward.
private final class ProgressTracker: @unchecked Sendable {
    private let lock = NSLock()
    private var highest = 0.0

    func advance(to fraction: Double) -> Double? {
        lock.lock()
        defer { lock.unlock() }
        guard fraction > highest else { return nil }
        highest = fraction
        return fraction
    }
}

/// Accumulates process output off the main thread and emits complete lines as they arrive.
private final class OutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private let onLine: (@Sendable (String) -> Void)?
    private var stdoutData = Data()
    private var stderrData = Data()
    private var lineBuffer = ""

    init(onLine: (@Sendable (String) -> Void)?) {
        self.onLine = onLine
    }

    func appendStdout(_ data: Data) {
        guard !data.isEmpty else { return }
        lock.lock()
        stdoutData.append(data)
        lock.unlock()
        emitLines(from: data)
    }

    func appendStderr(_ data: Data) {
        guard !data.isEmpty else { return }
        lock.lock()
        stderrData.append(data)
        lock.unlock()
        // yt-dlp writes progress to stdout, but parse stderr too in case that changes.
        emitLines(from: data)
    }

    func finish() -> (stdout: String, stderr: String) {
        lock.lock()
        defer { lock.unlock() }
        return (
            String(data: stdoutData, encoding: .utf8) ?? "",
            String(data: stderrData, encoding: .utf8) ?? ""
        )
    }

    private func emitLines(from data: Data) {
        guard let onLine, let chunk = String(data: data, encoding: .utf8) else { return }

        lock.lock()
        lineBuffer += chunk
        // yt-dlp uses both \n (with --newline) and \r for in-place progress updates.
        let normalized = lineBuffer.replacingOccurrences(of: "\r", with: "\n")
        var pieces = normalized.components(separatedBy: "\n")
        lineBuffer = pieces.removeLast()
        lock.unlock()

        for piece in pieces where !piece.isEmpty {
            onLine(piece)
        }
    }
}
