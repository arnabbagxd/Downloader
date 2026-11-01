import XCTest
@testable import MediaDownloader

final class CancellationTests: XCTestCase {
    func testCancellationStopsProcess() async throws {
        let task = Task { try await MediaConversionProcess.run(executable: "/bin/sleep", arguments: ["30"]) }
        try await Task.sleep(nanoseconds: 100_000_000)
        let start = Date()
        task.cancel()
        do { try await task.value; XCTFail("Cancelled process must fail") } catch { }
        XCTAssertLessThan(Date().timeIntervalSince(start), 3)
    }

    func testCancellationBeforeLaunch() async throws {
        let process = CancellableProcess()
        process.cancel()
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/bin/sleep")
        child.arguments = ["30"]
        XCTAssertThrowsError(try process.start(child))
        XCTAssertFalse(child.isRunning)
    }

    func testActivityPersistenceRoundTrip() throws {
        let activity = AppActivity(title: "Example", detail: "Cancelled", state: .cancelled)
        let decoded = try JSONDecoder().decode(AppActivity.self, from: JSONEncoder().encode(activity))
        XCTAssertEqual(decoded, activity)
    }
}
