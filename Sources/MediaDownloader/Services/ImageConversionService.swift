import Foundation

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
        guard let ffmpeg = ToolManager.ffmpegPath else { throw ImageConversionError.ffmpegUnavailable }
        try fileManager.createDirectory(at: destinationFolder, withIntermediateDirectories: true)

        let baseName = preferredBaseName ?? sourceURL.deletingPathExtension().lastPathComponent
        let destination = uniqueDestination(in: destinationFolder, baseName: baseName, fileExtension: format.fileExtension)

        var arguments = ["-y", "-i", sourceURL.path]
        arguments += format.ffmpegArguments(quality: quality)
        arguments.append(destination.path)

        try await runProcess(executable: ffmpeg, arguments: arguments)
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

    private func runProcess(executable: String, arguments: [String]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            let stderr = Pipe()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.environment = DependencyChecker.processEnvironment
            process.standardOutput = Pipe()
            process.standardError = stderr

            process.terminationHandler = { process in
                if process.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    let message = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    continuation.resume(throwing: ImageConversionError.conversionFailed(message))
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
