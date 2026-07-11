@testable import MediaDownloader
import XCTest

final class UpdateCheckerTests: XCTestCase {
    func testVersionComparisonIgnoresLeadingV() {
        XCTAssertTrue(Version("v1.2.4") > Version("1.2.3"))
        XCTAssertFalse(Version("v1.2.3") > Version("1.2.3"))
    }

    func testVersionComparisonPadsMissingComponents() {
        XCTAssertFalse(Version("1.2") > Version("1.2.0"))
        XCTAssertTrue(Version("1.2.1") > Version("1.2"))
    }

    func testVersionComparisonHandlesSuffixes() {
        XCTAssertFalse(Version("1.2.3-beta") > Version("1.2.3"))
        XCTAssertTrue(Version("1.2.4-beta") > Version("1.2.3"))
    }

    func testDownloadFileNameFallsBackToAssetURLName() {
        let url = URL(string: "https://github.com/arnabbagxd/Downloader/releases/download/v1.2.3/DownloadIt.zip")!

        XCTAssertEqual(UpdateChecker.downloadFileName(from: nil, fallbackURL: url), "DownloadIt.zip")
    }

    func testDownloadFileNameHandlesEmptyFallbackURLName() {
        let url = URL(string: "https://github.com/arnabbagxd/Downloader/releases/download/v1.2.3/")!

        XCTAssertEqual(UpdateChecker.downloadFileName(from: nil, fallbackURL: url), "DownloadIt-update.zip")
    }
}
