import AppKit
import PDFKit

enum PDFConversionError: LocalizedError {
    case unreadablePDF
    case noPages

    var errorDescription: String? {
        switch self {
        case .unreadablePDF: return "That file couldn't be read as a PDF."
        case .noPages: return "That PDF has no pages to convert."
        }
    }
}

/// Rasterizes a PDF's pages into PNG files using the system's PDFKit, so they can be fed
/// straight into the existing image-conversion flow (pick a format, pick a quality).
actor PDFConversionService {
    private let fileManager = FileManager.default

    /// Roughly 216 DPI from PDFKit's 72-DPI page space — sharp enough for prints and
    /// screen viewing without producing unreasonably large intermediate files.
    private static let renderScale: CGFloat = 3

    /// Renders every page of a PDF into a fresh temporary folder and returns their URLs,
    /// highest-quality page first through last. The caller is responsible for cleaning
    /// these files up once it's done with them.
    func rasterizePages(of pdfURL: URL) async throws -> [URL] {
        guard let document = PDFDocument(url: pdfURL), document.pageCount > 0 else {
            throw PDFConversionError.unreadablePDF
        }

        let baseName = pdfURL.deletingPathExtension().lastPathComponent
        let workingDirectory = fileManager.temporaryDirectory.appendingPathComponent("pdf-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: workingDirectory, withIntermediateDirectories: true)

        var pageURLs: [URL] = []

        for index in 0..<document.pageCount {
            guard let page = document.page(at: index),
                  let destination = renderPage(page, index: index, baseName: baseName, pageCount: document.pageCount, into: workingDirectory) else {
                continue
            }
            pageURLs.append(destination)
        }

        guard !pageURLs.isEmpty else {
            try? fileManager.removeItem(at: workingDirectory)
            throw PDFConversionError.noPages
        }

        return pageURLs
    }

    private func renderPage(_ page: PDFPage, index: Int, baseName: String, pageCount: Int, into workingDirectory: URL) -> URL? {
        let bounds = page.bounds(for: .mediaBox)
        let pixelSize = CGSize(
            width: max(bounds.width, 1) * Self.renderScale,
            height: max(bounds.height, 1) * Self.renderScale
        )

        let image = page.thumbnail(of: pixelSize, for: .mediaBox)
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }

        let pageName = pageCount > 1 ? "\(baseName) page \(index + 1)" : baseName
        let destination = workingDirectory.appendingPathComponent(pageName).appendingPathExtension("png")

        do {
            try pngData.write(to: destination)
            return destination
        } catch {
            return nil
        }
    }
}
