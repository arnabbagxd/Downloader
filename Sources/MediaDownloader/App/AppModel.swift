import AppKit
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var inputText = ""
    @Published private(set) var history: [DownloadItem] = []
    @Published private(set) var isDownloading = false
    @Published private(set) var downloadProgress: Double = 0
    @Published var statusMessage: String?
    @Published var activeTrimSession: ActiveTrimSession?
    @Published private(set) var isCheckingForUpdates = false
    @Published private(set) var isProbing = false
    @Published private(set) var isRefiningResolutions = false
    @Published var resolutionPrompt: ResolutionPrompt?
    @Published var conversionPrompt: ConversionPrompt?
    @Published private(set) var pinterestBundleStatus: PinterestBundleStatus?

    private let preferences = PreferencesStore()
    private let historyStore = HistoryStore()
    private let downloader = MediaDownloaderService()
    private let imageConverter = ImageConversionService()
    private let zipper = ZipService()
    private var pendingRemotePageURL: String?
    private let thumbnailGenerator = ThumbnailGenerator()
    private let trimExporter = TrimExportService()
    private let updateChecker = UpdateChecker()
    private var pasteTask: Task<Void, Never>?
    private var probeTask: Task<Void, Never>?
    private var probeCache: [String: VideoProbe] = [:]
    private var didRunAutomaticUpdateCheck = false
    private var settingsWindowController: SettingsWindowController?

    var downloadFolderPath: String {
        preferences.downloadFolder.path
    }

    init() {
        history = historyStore.load()
    }

    func chooseDownloadFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = preferences.downloadFolder
        panel.prompt = "Choose"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        preferences.downloadFolder = url
    }

    func handlePasteCandidate() {
        pasteTask?.cancel()

        let candidate = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard URLValidator.looksLikeWebURL(candidate) else {
            return
        }

        pasteTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }
            await self?.beginResolutionSelection(candidate)
        }
    }

    func submitInput() {
        pasteTask?.cancel()
        Task { [weak self] in
            guard let self else { return }
            await self.beginResolutionSelection(self.inputText)
        }
    }

    /// Handles a URL or text string dropped onto the window.
    func handleDroppedText(_ raw: String) {
        let candidate = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard URLValidator.looksLikeWebURL(candidate) else {
            statusMessage = "That doesn't look like a URL."
            return
        }

        pasteTask?.cancel()
        inputText = candidate
        Task { [weak self] in
            await self?.beginResolutionSelection(candidate)
        }
    }

    /// Called when the user taps one of the resolution boxes.
    func chooseResolution(_ resolution: VideoResolution) {
        guard let prompt = resolutionPrompt else { return }
        let sourceURL = prompt.sourceURL
        resolutionPrompt = nil
        probeTask?.cancel()
        isRefiningResolutions = false
        Task { [weak self] in
            await self?.performDownload(sourceURL, formatSelector: resolution.formatSelector)
        }
    }

    /// Dismisses the resolution boxes without downloading.
    func cancelResolutionSelection() {
        resolutionPrompt = nil
        pasteTask?.cancel()
        probeTask?.cancel()
        isRefiningResolutions = false
    }

    /// Handles local image files dragged onto the window — shows the format picker.
    func handleDroppedImageFiles(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        pasteTask?.cancel()
        resolutionPrompt = nil
        pendingRemotePageURL = nil
        conversionPrompt = ConversionPrompt(
            source: .localFiles(urls),
            title: urls.count == 1 ? urls[0].lastPathComponent : "\(urls.count) images",
            allowsOriginal: false
        )
    }

    /// Called when the user taps a format box. `format == nil` means keep the original (remote only).
    func chooseConversionFormat(_ format: ImageFormat?, quality: Int) {
        guard let prompt = conversionPrompt else { return }
        conversionPrompt = nil

        Task { [weak self] in
            guard let self else { return }
            switch prompt.source {
            case .localFiles(let urls):
                guard let format else { return }
                await self.performLocalConversion(urls, format: format, quality: quality)
            case .remoteImages(let urls):
                if let format {
                    await self.performRemoteConversion(urls, format: format, quality: quality, title: prompt.title)
                } else {
                    await self.performImageDownload(urls, title: prompt.title, sourceURL: self.pendingRemotePageURL ?? "")
                }
            }
        }
    }

    func cancelConversion() {
        conversionPrompt = nil
        pendingRemotePageURL = nil
    }

    private func performLocalConversion(_ urls: [URL], format: ImageFormat, quality: Int) async {
        guard !isDownloading else { return }
        isDownloading = true
        downloadProgress = 0
        statusMessage = urls.count > 1 ? "Converting \(urls.count) images…" : "Converting…"

        var savedURLs: [URL] = []
        do {
            for url in urls {
                let output = try await imageConverter.convert(
                    sourceURL: url,
                    to: format,
                    quality: quality,
                    destinationFolder: preferences.downloadFolder
                )
                savedURLs.append(output)
            }
            insertImageHistory(savedURLs, sourceURL: urls.first?.absoluteString ?? "")
            statusMessage = savedURLs.count > 1
                ? "Converted \(savedURLs.count) images."
                : "Converted to \(format.displayName) and copied."
        } catch {
            statusMessage = error.localizedDescription
        }

        isDownloading = false
        downloadProgress = 0
    }

    private func performRemoteConversion(_ imageURLs: [String], format: ImageFormat, quality: Int, title: String) async {
        guard !isDownloading else { return }
        isDownloading = true
        downloadProgress = 0
        statusMessage = imageURLs.count > 1 ? "Downloading & converting \(imageURLs.count) images…" : "Downloading & converting…"

        let pageURL = pendingRemotePageURL ?? ""
        var savedURLs: [URL] = []
        do {
            for (index, urlString) in imageURLs.enumerated() {
                guard let url = URL(string: urlString) else { continue }
                let (temporaryURL, _) = try await URLSession.shared.download(from: url)
                let baseName = MediaDownloaderService.imageBaseName(title: title, index: index, total: imageURLs.count)
                let output = try await imageConverter.convert(
                    sourceURL: temporaryURL,
                    to: format,
                    quality: quality,
                    destinationFolder: preferences.downloadFolder,
                    preferredBaseName: baseName
                )
                try? FileManager.default.removeItem(at: temporaryURL)
                savedURLs.append(output)
                downloadProgress = Double(index + 1) / Double(imageURLs.count)
            }
            insertImageHistory(savedURLs, sourceURL: pageURL)
            statusMessage = savedURLs.count > 1
                ? "Downloaded \(savedURLs.count) images as \(format.displayName)."
                : "Downloaded as \(format.displayName) and copied."
        } catch {
            statusMessage = error.localizedDescription
        }

        pendingRemotePageURL = nil
        isDownloading = false
        downloadProgress = 0
    }

    /// Adds converted/downloaded image files to history (newest first) and copies the first one.
    private func insertImageHistory(_ urls: [URL], sourceURL: String) {
        guard !urls.isEmpty else { return }
        for output in urls.reversed() {
            let item = DownloadItem(
                sourceURL: sourceURL,
                title: output.deletingPathExtension().lastPathComponent,
                filePath: output.path,
                thumbnailPath: output.path,
                createdAt: Date()
            )
            history.insert(item, at: 0)
        }
        historyStore.save(history)
        if let first = urls.first {
            ClipboardService.copyFile(first)
        }
        inputText = ""
    }

    func copyFile(_ item: DownloadItem) {
        ClipboardService.copyFile(URL(fileURLWithPath: item.filePath))
        statusMessage = "Copied \(item.displayName)."
    }

    func revealInFinder(_ item: DownloadItem) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.filePath)])
    }

    func openSourceURL(_ item: DownloadItem) {
        guard let url = URL(string: item.sourceURL) else { return }
        NSWorkspace.shared.open(url)
    }

    func deleteHistoryItem(_ item: DownloadItem) {
        history.removeAll { $0.id == item.id }
        historyStore.save(history)

        if activeTrimSession?.item.id == item.id {
            activeTrimSession = nil
        }
    }

    func clearHistory() {
        history.removeAll()
        historyStore.save(history)
        activeTrimSession = nil
    }

    func checkForUpdates(manual: Bool) {
        if !manual {
            guard !didRunAutomaticUpdateCheck else { return }
            didRunAutomaticUpdateCheck = true
        }

        guard !isCheckingForUpdates else { return }
        isCheckingForUpdates = true

        Task { [weak self] in
            guard let self else { return }

            do {
                let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
                let result = try await updateChecker.check(currentVersion: currentVersion)
                let downloadedUpdate: DownloadedUpdate?

                if case .updateAvailable(let update) = result {
                    downloadedUpdate = try await updateChecker.download(update)
                } else {
                    downloadedUpdate = nil
                }

                await MainActor.run {
                    self.isCheckingForUpdates = false
                    self.presentUpdateResult(
                        result,
                        downloadedUpdate: downloadedUpdate,
                        currentVersion: currentVersion,
                        manual: manual
                    )
                }
            } catch {
                await MainActor.run {
                    self.isCheckingForUpdates = false
                    if manual {
                        self.presentUpdateError(error)
                    }
                }
            }
        }
    }

    func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                preferences: preferences,
                onCheckForUpdates: { [weak self] in
                    self?.checkForUpdates(manual: true)
                }
            )
        }

        settingsWindowController?.show()
    }

    func hotKeyShortcut(for action: HotKeyAction) -> HotKeyShortcut {
        preferences.hotKeyShortcut(for: action)
    }

    func editTrim(_ item: DownloadItem) {
        guard FileManager.default.fileExists(atPath: item.filePath) else {
            statusMessage = "The downloaded file no longer exists on disk."
            return
        }

        // Images can't be trimmed — open them in the default viewer instead.
        if item.isImageFile {
            NSWorkspace.shared.open(URL(fileURLWithPath: item.filePath))
            return
        }

        // Zip bundles aren't trimmable either — reveal so the user can extract it themselves.
        if item.isZipFile {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.filePath)])
            return
        }

        activeTrimSession = ActiveTrimSession(item: item)
    }

    func closeTrim() {
        activeTrimSession = nil
    }

    func saveActiveTrim(_ selection: TrimSelection) async throws -> URL {
        guard let session = activeTrimSession else {
            throw TrimExportError.invalidRange
        }

        let outputURL = await trimExporter.saveURL(for: session.fileURL, selection: selection)
        return try await trimExporter.exportTrim(
            sourceURL: session.fileURL,
            selection: selection,
            to: outputURL
        )
    }

    func copyActiveTrim(_ selection: TrimSelection) async throws {
        guard let session = activeTrimSession else {
            throw TrimExportError.invalidRange
        }

        let outputURL = try await trimExporter.temporaryURL(for: session.fileURL)
        let trimmedURL = try await trimExporter.exportTrim(
            sourceURL: session.fileURL,
            selection: selection,
            to: outputURL
        )
        ClipboardService.copyFile(trimmedURL)
    }

    /// Shows quality boxes immediately, then refines them from the real lookup in the background.
    private func beginResolutionSelection(_ rawURL: String) async {
        let sourceURL = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isDownloading else { return }
        guard URLValidator.looksLikeWebURL(sourceURL) else {
            statusMessage = "Enter a valid URL."
            return
        }

        probeTask?.cancel()

        // Pinterest needs its own path: a link might be a single pin (handled like any
        // other site) or a board/Idea Pin with many items, which get bundled into a zip.
        if MediaDownloaderService.isPinterestLink(sourceURL) {
            await beginPinterestSelection(sourceURL)
            return
        }

        // Direct image links (…/photo.jpg) skip the lookup and go straight to the format picker.
        if let url = URL(string: sourceURL), Self.imageExtensions.contains(url.pathExtension.lowercased()) {
            pendingRemotePageURL = sourceURL
            resolutionPrompt = nil
            conversionPrompt = ConversionPrompt(
                source: .remoteImages([sourceURL]),
                title: url.lastPathComponent,
                allowsOriginal: true
            )
            return
        }

        // Seen this link already? Use the cached result instantly — no wait at all.
        if let cached = probeCache[sourceURL] {
            conversionPrompt = nil
            applyProbeResult(cached, sourceURL: sourceURL, isInitial: true)
            return
        }

        // Show quality boxes right away so the user never stares at a spinner.
        conversionPrompt = nil
        statusMessage = nil
        resolutionPrompt = ResolutionPrompt(
            sourceURL: sourceURL,
            title: sourceURL,
            options: VideoResolution.provisionalOptions
        )
        isRefiningResolutions = true

        // Look up the real title + available resolutions in the background, then refine.
        probeTask = Task { [weak self] in
            guard let self else { return }
            do {
                let probe = try await self.downloader.probe(sourceURL: sourceURL)
                guard !Task.isCancelled else { return }
                self.probeCache[sourceURL] = probe
                self.applyProbeResult(probe, sourceURL: sourceURL, isInitial: false)
            } catch {
                // Keep the provisional boxes so the user can still try downloading.
            }
            self.isRefiningResolutions = false
        }
    }

    /// Applies a completed lookup: refine the boxes, switch to the image format picker, or report nothing found.
    private func applyProbeResult(_ probe: VideoProbe, sourceURL: String, isInitial: Bool) {
        guard !isDownloading else { return }
        // For a background refine, only act if the user is still viewing this link's boxes.
        if !isInitial {
            guard resolutionPrompt?.sourceURL == sourceURL else { return }
        }

        if probe.isImagePost {
            // Images have one size — offer a format choice instead of resolution boxes.
            resolutionPrompt = nil
            isRefiningResolutions = false
            pendingRemotePageURL = sourceURL
            conversionPrompt = ConversionPrompt(
                source: .remoteImages(probe.imageURLs),
                title: probe.title ?? sourceURL,
                allowsOriginal: true
            )
            return
        }

        guard !probe.heights.isEmpty else {
            resolutionPrompt = nil
            isRefiningResolutions = false
            statusMessage = "No downloadable video or images were found at that link."
            return
        }

        resolutionPrompt = ResolutionPrompt(
            sourceURL: sourceURL,
            title: probe.title ?? sourceURL,
            options: VideoResolution.options(from: probe.heights)
        )
        statusMessage = nil
    }

    /// Pinterest-specific entry point: a single pin behaves like any other link; a
    /// multi-page Idea Pin or a board gets downloaded whole and bundled into a zip.
    private func beginPinterestSelection(_ sourceURL: String) async {
        resolutionPrompt = nil
        conversionPrompt = nil
        isProbing = true
        statusMessage = "Checking the link..."

        do {
            let result = try await downloader.probePinterestCollection(sourceURL: sourceURL)
            isProbing = false

            guard !result.items.isEmpty else {
                statusMessage = "No downloadable video or images were found at that link."
                return
            }

            guard result.items.count > 1 else {
                // Exactly one item: behave just like any other single-pin link.
                let item = result.items[0]
                if item.isImage, let imageURL = item.imageURL {
                    pendingRemotePageURL = sourceURL
                    conversionPrompt = ConversionPrompt(
                        source: .remoteImages([imageURL]),
                        title: item.title ?? result.title ?? sourceURL,
                        allowsOriginal: true
                    )
                } else {
                    resolutionPrompt = ResolutionPrompt(
                        sourceURL: item.webpageURL,
                        title: item.title ?? result.title ?? sourceURL,
                        options: VideoResolution.options(from: item.heights)
                    )
                }
                return
            }

            // Multiple items — download everything and bundle it into one zip.
            let bundleTitle = result.title ?? "Pinterest"
            await performPinterestBundleDownload(result.items, title: bundleTitle, sourceURL: sourceURL)
        } catch {
            isProbing = false
            statusMessage = error.localizedDescription
        }
    }

    private func performPinterestBundleDownload(_ items: [PinterestCollectionItem], title: String, sourceURL: String) async {
        guard !isDownloading else { return }
        isDownloading = true
        downloadProgress = 0
        pinterestBundleStatus = PinterestBundleStatus(phase: .downloading, completed: 0, total: items.count, title: title)

        do {
            let (files, workingDirectory) = try await downloader.downloadPinterestItems(items) { [weak self] completed, total in
                Task { @MainActor in
                    guard let self else { return }
                    self.downloadProgress = Double(completed) / Double(total)
                    self.pinterestBundleStatus = PinterestBundleStatus(phase: .downloading, completed: completed, total: total, title: title)
                }
            }

            pinterestBundleStatus = PinterestBundleStatus(phase: .zipping, completed: items.count, total: items.count, title: title)
            let zipBaseName = MediaDownloaderService.imageBaseName(title: title, index: 0, total: 1)
            let zipDestination = uniquePinterestZipURL(baseName: zipBaseName)
            let savedZip = try await zipper.zip(files: files, to: zipDestination)
            try? FileManager.default.removeItem(at: workingDirectory)

            let historyItem = DownloadItem(
                sourceURL: sourceURL,
                title: zipBaseName,
                filePath: savedZip.path,
                thumbnailPath: nil,
                createdAt: Date()
            )
            history.insert(historyItem, at: 0)
            historyStore.save(history)
            ClipboardService.copyFile(savedZip)
            inputText = ""

            let skipped = items.count - files.count
            statusMessage = skipped > 0
                ? "Bundled \(files.count) of \(items.count) items into a zip (\(skipped) skipped)."
                : "Bundled \(files.count) items into a zip."
        } catch {
            statusMessage = error.localizedDescription
        }

        pinterestBundleStatus = nil
        isDownloading = false
        downloadProgress = 0
    }

    private func uniquePinterestZipURL(baseName: String) -> URL {
        let folder = preferences.downloadFolder
        var candidate = folder.appendingPathComponent(baseName).appendingPathExtension("zip")
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(baseName)-\(counter)").appendingPathExtension("zip")
            counter += 1
        }
        return candidate
    }

    private static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "webp", "gif", "heic", "bmp", "tiff", "avif"
    ]

    private func performImageDownload(_ imageURLs: [String], title: String?, sourceURL: String) async {
        guard !isDownloading else { return }

        isDownloading = true
        downloadProgress = 0
        statusMessage = imageURLs.count > 1 ? "Downloading \(imageURLs.count) images..." : "Downloading image..."

        do {
            let results = try await downloader.downloadImages(
                imageURLs: imageURLs,
                title: title,
                destinationFolder: preferences.downloadFolder
            ) { [weak self] progress in
                Task { @MainActor in
                    self?.downloadProgress = progress
                }
            }

            for result in results.reversed() {
                let item = DownloadItem(
                    sourceURL: sourceURL,
                    title: result.title,
                    filePath: result.fileURL.path,
                    thumbnailPath: result.fileURL.path, // the image is its own thumbnail
                    createdAt: Date()
                )
                history.insert(item, at: 0)
            }

            historyStore.save(history)

            if let first = results.first {
                ClipboardService.copyFile(first.fileURL)
            }

            inputText = ""
            statusMessage = results.count > 1
                ? "Downloaded \(results.count) images and copied the first."
                : "Downloaded and copied."
        } catch {
            statusMessage = error.localizedDescription
        }

        isDownloading = false
        downloadProgress = 0
    }

    private func performDownload(_ sourceURL: String, formatSelector: String?) async {
        guard !isDownloading else { return }

        isDownloading = true
        downloadProgress = 0
        statusMessage = "Downloading..."

        do {
            let result = try await downloader.download(
                sourceURL: sourceURL,
                destinationFolder: preferences.downloadFolder,
                formatSelector: formatSelector
            ) { [weak self] progress in
                Task { @MainActor in
                    self?.downloadProgress = progress
                }
            }
            let thumbnailPath = try? await thumbnailGenerator.thumbnailPath(for: result.fileURL)
            let item = DownloadItem(
                sourceURL: sourceURL,
                title: result.title,
                filePath: result.fileURL.path,
                thumbnailPath: thumbnailPath?.path,
                createdAt: Date()
            )

            history.insert(item, at: 0)
            historyStore.save(history)
            ClipboardService.copyFile(result.fileURL)
            activeTrimSession = ActiveTrimSession(item: item)
            inputText = ""
            statusMessage = "Downloaded and copied."
        } catch {
            statusMessage = error.localizedDescription
        }

        isDownloading = false
        downloadProgress = 0
    }

    private func presentUpdateResult(
        _ result: UpdateCheckResult,
        downloadedUpdate: DownloadedUpdate?,
        currentVersion: String,
        manual: Bool
    ) {
        switch result {
        case .upToDate:
            guard manual else { return }
            let alert = NSAlert()
            alert.messageText = "You're up to date"
            alert.informativeText = "Download It \(currentVersion) is the latest version."
            alert.icon = NSImage(named: NSImage.applicationIconName)
            alert.addButton(withTitle: "OK")
            alert.runModal()
        case .updateAvailable(let update):
            let alert = NSAlert()
            alert.messageText = "A new version is available"
            let instructions = "Click Update to open the installer, then drag Download It "
                + "into Applications to replace the current version (\(currentVersion))."
            alert.informativeText = downloadedUpdate == nil
                ? "Download It \(update.version) is out. \(instructions)"
                : "Download It \(update.version) has already been downloaded. \(instructions)"
            alert.icon = NSImage(named: NSImage.applicationIconName)
            alert.addButton(withTitle: "Update")
            alert.addButton(withTitle: "Later")

            if alert.runModal() == .alertFirstButtonReturn {
                if let downloadedUpdate {
                    NSWorkspace.shared.open(downloadedUpdate.fileURL)
                } else {
                    NSWorkspace.shared.open(update.downloadURL ?? update.releaseURL)
                }
            }
        }
    }

    private func presentUpdateError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Couldn't check for updates"
        alert.informativeText = error.localizedDescription
        alert.icon = NSImage(named: NSImage.applicationIconName)
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
