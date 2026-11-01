import Foundation

enum MediaConversionProcess {
    /// Redirect diagnostics to a file rather than an unread pipe: a verbose
    /// encoder must never block waiting for the app to consume its stderr.
    static func run(executable: String, arguments: [String]) async throws {
        let logURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("conversion-\(UUID().uuidString).log")
        guard FileManager.default.createFile(atPath: logURL.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        defer { try? FileManager.default.removeItem(at: logURL) }
        let log = try FileHandle(forWritingTo: logURL)
        defer { try? log.close() }

        let cancellation = CancellableProcess()
        return try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.environment = DependencyChecker.processEnvironment
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = FileHandle.nullDevice
            process.standardError = log
            process.terminationHandler = { process in
                if process.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    // Bound the diagnostic read even if a helper emits a huge log.
                    let reader = try? FileHandle(forReadingFrom: logURL)
                    defer { try? reader?.close() }
                    let length = (try? reader?.seekToEnd()) ?? 0
                    try? reader?.seek(toOffset: length > 65_536 ? length - 65_536 : 0)
                    let data = (try? reader?.readToEnd()) ?? Data()
                    let message = String(data: data, encoding: .utf8) ?? ""
                    continuation.resume(throwing: ImageConversionError.conversionFailed(message))
                }
            }
            do {
                try cancellation.start(process)
            } catch {
                continuation.resume(throwing: error)
            }
        }
        } onCancel: { cancellation.cancel() }
    }
}
