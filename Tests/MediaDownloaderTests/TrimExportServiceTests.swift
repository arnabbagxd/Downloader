@testable import MediaDownloader
import XCTest

final class TrimExportServiceTests: XCTestCase {
    func testTrimExportUsesAccurateReencodeInsteadOfKeyframeStreamCopy() {
        let sourceURL = URL(fileURLWithPath: "/tmp/source.mp4")
        let outputURL = URL(fileURLWithPath: "/tmp/output.mp4")
        let arguments = TrimExportService.exportArguments(
            sourceURL: sourceURL,
            selection: TrimSelection(start: 1.234, end: 3.456),
            outputURL: outputURL
        )

        // ffmpeg itself is now the executable, so the arguments start at "-y".
        XCTAssertEqual(arguments.first, "-y")
        XCTAssertFalse(arguments.contains("-c") && arguments.contains("copy"))
        XCTAssertContainsSequence(arguments, ["-i", sourceURL.path, "-ss", "1.234"])
        XCTAssertContainsSequence(arguments, ["-t", "2.222"])
        XCTAssertContainsSequence(arguments, ["-c:v", "libx264"])
        XCTAssertContainsSequence(arguments, ["-pix_fmt", "yuv420p"])
        XCTAssertEqual(arguments.last, outputURL.path)
    }

    private func XCTAssertContainsSequence(
        _ arguments: [String],
        _ expected: [String],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard !expected.isEmpty, expected.count <= arguments.count else {
            XCTFail("Invalid expected sequence", file: file, line: line)
            return
        }

        let contains = arguments.indices.contains { index in
            let end = index + expected.count
            guard end <= arguments.count else { return false }
            return Array(arguments[index..<end]) == expected
        }

        XCTAssertTrue(contains, "Expected arguments to contain \(expected), got \(arguments)", file: file, line: line)
    }
}
