@testable import MediaDownloader
import XCTest

final class AppActivityTests: XCTestCase {
    @MainActor
    func testPDFErrorSurvivesToastTimeoutAndCanBeDismissed() async throws {
        let suite = "DownloadIt.ActivityTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = AppModel(defaults: defaults)
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("missing-\(UUID().uuidString).pdf")
        model.handleDroppedPDF(missing)
        for _ in 0..<100 {
            if model.activity?.state == .failed { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(model.activity?.state, .failed)
        XCTAssertFalse(model.isBusy)
        XCTAssertNil(model.activityProgress)
        let error = model.activity?.detail
        // Allow scheduler delay under a concurrent build while still bounding the toast timeout.
        for _ in 0..<300 {
            if model.statusMessage == nil { break }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertNil(model.statusMessage)
        XCTAssertEqual(model.activity?.detail, error)
        model.dismissActivity()
        XCTAssertNil(model.activity)
    }
}
