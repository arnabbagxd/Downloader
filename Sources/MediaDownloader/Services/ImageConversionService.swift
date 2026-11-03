import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ImageConversionError: LocalizedError {
    case ffmpegUnavailable
    case conversionFailed(String)

    var errorDescription: String? {
        switch self {
        case .ffmpegUnavailable:
            return "The image converter isn't ready yet."
        case .conversionFailed(let message):
            return message.isEmpty ? "Image conversion failed." : message
        }
    }
}

/// Converts image files to a chosen format + quality using the managed ffmpeg.
actor ImageConversionService {
    private let fileManager = FileManager.default

    func convert(
        sourceURL: URL,
        to format: ImageFormat,
        quality: Int,
        destinationFolder: URL,
        preferredBaseName: String? = nil
    ) async throws -> URL {
        try Task.checkCancellation()
        try fileManager.createDirectory(at: destinationFolder, withIntermediateDirectories: true)

        let baseName = preferredBaseName ?? sourceURL.deletingPathExtension().lastPathComponent
        let destination = uniqueDestination(in: destinationFolder, baseName: baseName, fileExtension: format.fileExtension)

        // PDF rasterization already produces lossless PNGs. Copying those bytes
        // avoids decoding and encoding every page a second time.
        if format == .png,
           let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
           CGImageSourceGetType(source) as String? == UTType.png.identifier,
           CGImageSourceGetCount(source) == 1 {
            try fileManager.copyItem(at: sourceURL, to: destination)
            return destination
        }

        guard let ffmpeg = ToolManager.ffmpegPath else { throw ImageConversionError.ffmpegUnavailable }
        var arguments = ["-y", "-hide_banner", "-loglevel", "error", "-nostdin", "-i", sourceURL.path]
        arguments += format.ffmpegArguments(quality: quality)
        arguments.append(destination.path)

        do {
            try await MediaConversionProcess.run(executable: ffmpeg, arguments: arguments)
        } catch {
            try? fileManager.removeItem(at: destination)
            throw ImageConversionError.conversionFailed(error.localizedDescription)
        }
        return destination
    }

    private func uniqueDestination(in folder: URL, baseName: String, fileExtension: String) -> URL {
        var candidate = folder.appendingPathComponent(baseName).appendingPathExtension(fileExtension)
        var counter = 2
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(baseName)-\(counter)").appendingPathExtension(fileExtension)
            counter += 1
        }
        return candidate
    }

}
