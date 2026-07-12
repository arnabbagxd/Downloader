import Foundation

enum ToolInstallError: LocalizedError {
    case downloadFailed(String)
    case extractionFailed
    case notRunnable(String)

    var errorDescription: String? {
        switch self {
        case .downloadFailed(let name):
            return "Couldn't download \(name). Check your internet connection and try again."
        case .extractionFailed:
            return "Couldn't unpack ffmpeg after downloading."
        case .notRunnable(let name):
            return "\(name) was downloaded but couldn't run on this Mac."
        }
    }
}

/// Locates yt-dlp and ffmpeg — preferring copies the app manages in Application Support,
/// falling back to any system install — and downloads them on first run so users never
/// need Homebrew or the Terminal.
enum ToolManager {
    static let binDirectory: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)
        return support.appendingPathComponent("MediaDownloader/bin", isDirectory: true)
    }()

    static var managedYtDlp: URL { binDirectory.appendingPathComponent("yt-dlp") }
    static var managedFfmpeg: URL { binDirectory.appendingPathComponent("ffmpeg") }

    /// Absolute path to a tool: the app-managed copy if present, otherwise a system copy.
    static func resolvedPath(for tool: String) -> String? {
        let managed = (tool == "ffmpeg") ? managedFfmpeg : managedYtDlp
        if FileManager.default.isExecutableFile(atPath: managed.path) {
            return managed.path
        }
        return DependencyChecker.executablePath(named: tool)
    }

    static var ytDlpPath: String? { resolvedPath(for: "yt-dlp") }
    static var ffmpegPath: String? { resolvedPath(for: "ffmpeg") }

    /// True once both tools can be found (managed or system).
    static var isReady: Bool { ytDlpPath != nil && ffmpegPath != nil }

    // MARK: - Download sources

    private static let ytDlpURL = URL(string: "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos")!

    private static var ffmpegURL: URL {
        // Hosted on our own GitHub release for stable, self-controlled URLs.
        // #if arch(...) resolves per-slice in the universal binary, so each Mac fetches its own build.
        #if arch(arm64)
        return URL(string: "https://github.com/arnabbagxd/Downloader/releases/download/runtime-tools/ffmpeg-arm64")!
        #else
        return URL(string: "https://github.com/arnabbagxd/Downloader/releases/download/runtime-tools/ffmpeg-x86_64")!
        #endif
    }

    // MARK: - Installation

    /// Downloads whichever tools are missing. `progress` reports a short status for the UI.
    static func ensureInstalled(progress: @escaping @Sendable (String) -> Void) async throws {
        try FileManager.default.createDirectory(at: binDirectory, withIntermediateDirectories: true)

        if ytDlpPath == nil {
            progress("Downloading the video engine…")
            try await installYtDlp()
        }

        if ffmpegPath == nil {
            progress("Downloading the media converter…")
            try await installFfmpeg()
        }

        progress("Finishing setup…")
    }

    private static func installYtDlp() async throws {
        let temporaryURL: URL
        do {
            (temporaryURL, _) = try await URLSession.shared.download(from: ytDlpURL)
        } catch {
            throw ToolInstallError.downloadFailed("yt-dlp")
        }

        try? FileManager.default.removeItem(at: managedYtDlp)
        try FileManager.default.moveItem(at: temporaryURL, to: managedYtDlp)
        try await makeRunnable(managedYtDlp)
        try await verify(managedYtDlp, argument: "--version", name: "yt-dlp")
    }

    private static func installFfmpeg() async throws {
        let temporaryURL: URL
        do {
            (temporaryURL, _) = try await URLSession.shared.download(from: ffmpegURL)
        } catch {
            throw ToolInstallError.downloadFailed("ffmpeg")
        }

        try? FileManager.default.removeItem(at: managedFfmpeg)
        try FileManager.default.moveItem(at: temporaryURL, to: managedFfmpeg)
        try await makeRunnable(managedFfmpeg)
        try await verify(managedFfmpeg, argument: "-version", name: "ffmpeg")
    }

    /// Runs `yt-dlp -U` in the background to keep the downloader current. Best-effort.
    static func updateYtDlpIfManaged() async {
        guard FileManager.default.isExecutableFile(atPath: managedYtDlp.path) else { return }
        try? await runProcess(executable: managedYtDlp.path, arguments: ["-U"])
    }

    // MARK: - Helpers

    private static func makeRunnable(_ url: URL) async throws {
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        // Clear any quarantine flag so the binary isn't blocked by Gatekeeper when launched.
        await runProcessIgnoringResult(executable: "/usr/bin/xattr", arguments: ["-c", url.path])
    }

    private static func verify(_ url: URL, argument: String, name: String) async throws {
        do {
            try await runProcess(executable: url.path, arguments: [argument])
        } catch {
            throw ToolInstallError.notRunnable(name)
        }
    }

    private static func runProcessIgnoringResult(executable: String, arguments: [String]) async {
        try? await runProcess(executable: executable, arguments: arguments)
    }

    @discardableResult
    private static func runProcess(executable: String, arguments: [String]) async throws -> Void {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.environment = DependencyChecker.processEnvironment
            process.standardOutput = Pipe()
            process.standardError = Pipe()

            process.terminationHandler = { process in
                if process.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: ToolInstallError.notRunnable(executable))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
