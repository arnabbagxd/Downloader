import Foundation

enum ZipServiceError: LocalizedError {
    case nothingToZip
    case zippingFailed(String)

    var errorDescription: String? {
        switch self {
        case .nothingToZip:
            return "There was nothing to bundle into a zip."
        case .zippingFailed(let message):
            return message.isEmpty ? "Couldn't create the zip file." : message
        }
    }
}

/// Bundles a set of downloaded files into a single flat .zip (no wrapper folder, no
/// macOS resource-fork junk) using the system's built-in `ditto`.
actor ZipService {
    private let fileManager = FileManager.default

    func zip(files: [URL], to destinationZipURL: URL) async throws -> URL {
        guard !files.isEmpty else { throw ZipServiceError.nothingToZip }

        // ditto zips a folder's *contents* flat (no wrapper directory), so stage the
        // files in a temporary folder first — that also lets us dedupe filenames safely.
        let stagingDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: stagingDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: stagingDir) }

        for file in files {
            let destination = uniqueDestination(in: stagingDir, baseName: file.deletingPathExtension().lastPathComponent, fileExtension: file.pathExtension)
            try? fileManager.copyItem(at: file, to: destination)
        }

        try? fileManager.removeItem(at: destinationZipURL)
        try fileManager.createDirectory(at: destinationZipURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        try await runProcess(executable: "/usr/bin/ditto", arguments: [
            "--norsrc", "-c", "-k", stagingDir.path, destinationZipURL.path
        ])

        return destinationZipURL
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
            process.standardOutput = Pipe()
            process.standardError = stderr

            process.terminationHandler = { process in
                if process.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    let message = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    continuation.resume(throwing: ZipServiceError.zippingFailed(message))
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
