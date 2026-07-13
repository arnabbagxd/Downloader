import Foundation

/// A target image format the user can convert to.
enum ImageFormat: String, CaseIterable, Identifiable {
    case jpg
    case png
    case webp

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .jpg: return "JPG"
        case .png: return "PNG"
        case .webp: return "WebP"
        }
    }

    var fileExtension: String { rawValue }

    /// Lossy formats respect the quality slider; PNG is lossless.
    var isLossy: Bool {
        switch self {
        case .jpg, .webp: return true
        case .png: return false
        }
    }

    var subtitle: String {
        switch self {
        case .jpg: return "Small, universal"
        case .png: return "Lossless"
        case .webp: return "Smallest"
        }
    }

    /// ffmpeg output-encoding arguments for this format at the given quality (0–100).
    func ffmpegArguments(quality: Int) -> [String] {
        let clampedQuality = min(max(quality, 1), 100)
        switch self {
        case .webp:
            // libwebp takes quality directly, 0–100.
            return ["-c:v", "libwebp", "-quality", "\(clampedQuality)"]
        case .jpg:
            // mjpeg quality is -q:v 2 (best) … 31 (worst); map 100→2, 0→31.
            let qscale = Int((Double(100 - clampedQuality) / 100.0 * 29.0).rounded()) + 2
            return ["-q:v", "\(qscale)"]
        case .png:
            // Lossless; just squeeze the file a bit. Quality slider is ignored.
            return ["-compression_level", "9"]
        }
    }
}

/// A pending conversion, shown as the format picker before converting.
struct ConversionPrompt: Equatable {
    enum Source: Equatable {
        case localFiles([URL])        // images dragged in from disk
        case remoteImages([String])   // image URLs to download, then convert
    }

    let source: Source
    let title: String
    /// Remote images can be kept in their original format; local files are already saved somewhere.
    let allowsOriginal: Bool

    var count: Int {
        switch source {
        case .localFiles(let urls): return urls.count
        case .remoteImages(let urls): return urls.count
        }
    }
}
