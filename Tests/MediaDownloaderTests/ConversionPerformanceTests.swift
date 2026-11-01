@testable import MediaDownloader
import XCTest
import ImageIO
import UniformTypeIdentifiers

final class ConversionPerformanceTests: XCTestCase {
    func testPDFRasterizationKeepsPageCountAndRenderResolution() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let input = directory.appendingPathComponent("pages.pdf")
        var bounds = CGRect(x: 0, y: 0, width: 72, height: 48)
        let pdf = CGContext(input as CFURL, mediaBox: &bounds, nil)!
        for _ in 0..<2 {
            pdf.beginPDFPage(nil)
            pdf.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
            pdf.fill(bounds)
            pdf.endPDFPage()
        }
        pdf.closePDF()
        let pages = try await PDFConversionService().rasterizePages(of: input)
        defer {
            if let first = pages.first { try? FileManager.default.removeItem(at: first.deletingLastPathComponent()) }
        }
        XCTAssertEqual(pages.count, 2)
        for page in pages {
            let source = try XCTUnwrap(CGImageSourceCreateWithURL(page as CFURL, nil))
            let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
            XCTAssertEqual(image.width, 216)
            XCTAssertEqual(image.height, 144)
        }
    }

    func testPNGConversionPreservesExistingPixelsAndAvoidsReencoding() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        // A real PNG with a non-PNG extension also covers downloaded temp files.
        let input = directory.appendingPathComponent("source.tmp")
        let context = CGContext(data: nil, width: 16, height: 16, bitsPerComponent: 8,
                                bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let writer = CGImageDestinationCreateWithURL(input as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(writer, context.makeImage()!, nil)
        XCTAssertTrue(CGImageDestinationFinalize(writer))
        let output = try await ImageConversionService().convert(
            sourceURL: input, to: .png, quality: 75, destinationFolder: directory
        )
        XCTAssertEqual(try Data(contentsOf: input), try Data(contentsOf: output))
        XCTAssertNotEqual(input, output)
    }

    func testVerboseSubprocessCompletesWithoutFillingAPipe() async throws {
        try await MediaConversionProcess.run(executable: "/bin/sh", arguments: [
            "-c", "dd if=/dev/zero bs=1024 count=256 >&2 2>/dev/null"
        ])
    }

    func testFailedSubprocessKeepsDiagnosticTail() async {
        do {
            try await MediaConversionProcess.run(executable: "/bin/sh", arguments: [
                "-c", "dd if=/dev/zero bs=1024 count=256 >&2 2>/dev/null; echo conversion-failed >&2; exit 1"
            ])
            XCTFail("Expected a process error")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("conversion-failed"))
            XCTAssertLessThanOrEqual(error.localizedDescription.utf8.count, 65_536)
        }
    }
}
