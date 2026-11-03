import AppKit
import Foundation

enum AppUpdateInstallError: LocalizedError {
    case unsupportedFileType
    case mountFailed(String)
    case appNotFound
    case installFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFileType:
            return "The downloaded update isn't a .dmg or .zip file."
        case .mountFailed(let message):
            return message.isEmpty ? "Couldn't open the downloaded update." : message
        case .appNotFound:
            return "Couldn't find an app inside the downloaded update."
        case .installFailed(let message):
            return message.isEmpty
                ? "Couldn't install the update — the Applications folder may not be writable."
                : message
        }
    }
}

/// Installs a downloaded update in place: mounts the .dmg (or unzips the .zip), swaps the
/// new app bundle in for the one currently running, and relaunches it — no manual drag
/// into Applications required.
enum AppUpdateInstaller {
    /// Replaces the running app with the one inside `fileURL` and relaunches it. On
    /// success this ends by terminating the current process, so nothing after the call
    /// runs.
    static func installAndRelaunch(from fileURL: URL) async throws {
        var mountPoint: URL?
        let extractedApp: URL

        switch fileURL.pathExtension.lowercased() {
        case "dmg":
            let mounted = try await mountDMG(fileURL)
            mountPoint = mounted
            guard let app = findApp(in: mounted) else {
                try? await unmountDMG(mounted)
                throw AppUpdateInstallError.appNotFound
            }
            extractedApp = app

        case "zip":
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("DownloadIt-update-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            try await unzip(fileURL, to: destination)
            guard let app = findApp(in: destination) else {
                throw AppUpdateInstallError.appNotFound
            }
            extractedApp = app

        default:
            throw AppUpdateInstallError.unsupportedFileType
        }

        let runningAppURL = Bundle.main.bundleURL
        let targetDirectory = runningAppURL.deletingLastPathComponent()
        let stagingURL = targetDirectory.appendingPathComponent(
            "DownloadIt-update-\(UUID().uuidString).app", isDirectory: true
        )

        do {
            // Copy first — this leg can cross volumes (DMG/temp dir → Applications).
            // The actual swap below then happens entirely within the destination
            // volume, so it can be atomic even while the old bundle is running.
            try FileManager.default.copyItem(at: extractedApp, to: stagingURL)
            _ = try FileManager.default.replaceItemAt(runningAppURL, withItemAt: stagingURL)
        } catch {
            try? FileManager.default.removeItem(at: stagingURL)
            if let mountPoint { try? await unmountDMG(mountPoint) }
            throw AppUpdateInstallError.installFailed(error.localizedDescription)
        }

        if let mountPoint {
            try? await unmountDMG(mountPoint)
        }

        relaunch(at: runningAppURL)
    }

    /// Launches the freshly installed app as a new process, then quits the current one.
    private static func relaunch(at appURL: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", appURL.path]
        try? process.run()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApp.terminate(nil)
        }
    }

    private static func findApp(in directory: URL) -> URL? {
        let items = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        return items?.first { $0.pathExtension.lowercased() == "app" }
    }

    private static func mountDMG(_ dmgURL: URL) async throws -> URL {
        let output = try await runProcess(
            executable: "/usr/bin/hdiutil",
            arguments: ["attach", dmgURL.path, "-nobrowse", "-noautoopen", "-plist"]
        )

        guard let data = output.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let entities = plist["system-entities"] as? [[String: Any]] else {
            throw AppUpdateInstallError.mountFailed("Couldn't read the disk image.")
        }

        for entity in entities {
            if let mountPointString = entity["mount-point"] as? String {
                return URL(fileURLWithPath: mountPointString, isDirectory: true)
            }
        }

        throw AppUpdateInstallError.mountFailed("The disk image didn't mount.")
    }

    private static func unmountDMG(_ mountPoint: URL) async throws {
        _ = try await runProcess(executable: "/usr/bin/hdiutil", arguments: ["detach", mountPoint.path, "-quiet"])
    }

    private static func unzip(_ zipURL: URL, to destination: URL) async throws {
        _ = try await runProcess(executable: "/usr/bin/ditto", arguments: ["-x", "-k", zipURL.path, destination.path])
    }

    @discardableResult
    private static func runProcess(executable: String, arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let stdout = Pipe()
            let stderr = Pipe()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = stdout
            process.standardError = stderr

            process.terminationHandler = { process in
                let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
                let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8) ?? ""

                if process.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    let message = String(data: errorData, encoding: .utf8) ?? ""
                    continuation.resume(throwing: AppUpdateInstallError.installFailed(message))
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
