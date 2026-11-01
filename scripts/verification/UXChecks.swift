import AppKit
import Foundation
import PDFKit

@main struct UXCheck {
    @MainActor static func main() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("downloadit-ux-check-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let suiteName = "DownloadItTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = HistoryStore(historyURL: directory.appendingPathComponent("history.json"))
        let item = DownloadItem(sourceURL: "https://example.com", title: "Test", filePath: directory.appendingPathComponent("retained.txt").path, thumbnailPath: nil, createdAt: Date())
        try Data("Keep this file".utf8).write(to: URL(fileURLWithPath: item.filePath))
        store.save([item])
        let model = AppModel(historyStore: store, defaults: defaults)
        model.deleteHistoryItem(item)
        precondition(model.history.isEmpty && FileManager.default.fileExists(atPath: item.filePath))
        model.undoHistoryRemoval()
        precondition(model.history == [item] && store.load().first?.id == item.id)
        model.clearHistory(); model.undoHistoryRemoval()
        precondition(model.history.count == 1)
        print("PASS: remove, clear, Undo, saved history, original file preserved")

        model.handleDroppedPDF(directory.appendingPathComponent("missing.pdf"))
        for _ in 0..<100 {
            if model.activity?.state == .failed { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        precondition(model.activity?.state == .failed && model.canRetry)
        let detail = model.activity?.detail
        // Allow scheduler delay under a concurrent build while still bounding the toast timeout.
        for _ in 0..<300 {
            if model.statusMessage == nil { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        precondition(model.statusMessage == nil && model.activity?.detail == detail)
        let restored = AppModel(historyStore: store, defaults: defaults)
        precondition(restored.activity == model.activity)
        model.retryActivity()
        try await Task.sleep(nanoseconds: 200_000_000)
        precondition(model.activity?.state == .failed && !model.isBusy)
        model.dismissActivity()
        precondition(AppModel(historyStore: store, defaults: defaults).activity == nil)
        print("PASS: error retention, persisted result, retry and dismissal")

        let pdfURL = directory.appendingPathComponent("sample.pdf")
        let image = NSImage(size: NSSize(width: 72, height: 48))
        image.lockFocus(); NSColor.red.setFill(); NSBezierPath(rect: NSRect(x: 0, y: 0, width: 72, height: 48)).fill(); image.unlockFocus()
        let pdf = PDFDocument()
        pdf.insert(PDFPage(image: image)!, at: 0)
        precondition(pdf.write(to: pdfURL))
        model.handleDroppedPDF(pdfURL)
        for _ in 0..<100 {
            if model.activity?.state == .succeeded { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        precondition(model.activity?.state == .succeeded && model.conversionPrompt != nil)
        let prompt = model.conversionPrompt!
        model.cancelConversion()
        if case .localFiles(let pages) = prompt.source { precondition(!FileManager.default.fileExists(atPath: pages[0].path)) }
        print("PASS: PDF preparation and temporary page cleanup")

        let task = Task { try await MediaConversionProcess.run(executable: "/bin/sleep", arguments: ["30"]) }
        try await Task.sleep(nanoseconds: 200_000_000)
        let started = Date()
        task.cancel()
        do { try await task.value; fatalError("Cancelled process returned success") } catch { }
        precondition(Date().timeIntervalSince(started) < 3)
        let cancelled = CancellableProcess()
        cancelled.cancel()
        let child = Process(); child.executableURL = URL(fileURLWithPath: "/bin/sleep"); child.arguments = ["30"]
        do { try cancelled.start(child); fatalError("Started a cancelled process") } catch { }
        precondition(!child.isRunning)
        print("PASS: cancellation during execution and before process launch")
    }
}
