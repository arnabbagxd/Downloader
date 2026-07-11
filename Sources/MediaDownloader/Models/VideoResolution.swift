import Foundation

/// A single resolution the user can pick for a specific video, derived from what the video
/// actually offers. `height == nil` means "best available" (used when a probe finds no heights).
struct VideoResolution: Identifiable, Equatable {
    let height: Int?

    var id: Int { height ?? -1 }

    var label: String {
        guard let height else { return "Best" }
        switch height {
        case 4320...: return "8K"
        case 2160..<4320: return "4K"
        case 1440..<2160: return "1440p"
        default: return "\(height)p"
        }
    }

    var subtitle: String? {
        guard let height else { return "Highest available" }
        switch height {
        case 2160...: return "Ultra HD"
        case 1440..<2160: return "QHD"
        case 1080..<1440: return "Full HD"
        case 720..<1080: return "HD"
        default: return nil
        }
    }

    /// yt-dlp `-f` selector that caps the download at this height, or nil for best available.
    var formatSelector: String? {
        guard let height else { return nil }
        // `<=?` is non-strict so formats without a known height still qualify.
        return "bv*[height<=?\(height)]+ba/b[height<=?\(height)]"
    }

    /// Turns a set of raw video heights into a clean, de-duplicated list of options
    /// (highest first, capped so the picker stays tidy).
    static func options(from heights: [Int]) -> [VideoResolution] {
        guard !heights.isEmpty else { return [VideoResolution(height: nil)] }

        var seenLabels = Set<String>()
        var result: [VideoResolution] = []
        for height in heights.sorted(by: >) {
            let resolution = VideoResolution(height: height)
            if seenLabels.insert(resolution.label).inserted {
                result.append(resolution)
            }
            if result.count >= 5 { break }
        }
        return result
    }
}

/// The result of probing a link: its title (if any) and available video heights.
struct VideoProbe: Equatable {
    let title: String?
    let heights: [Int]
}

/// A pending resolution choice for a pasted link, shown as boxes before downloading.
struct ResolutionPrompt: Equatable {
    let sourceURL: String
    let title: String?
    let options: [VideoResolution]

    /// What to show as the card's subtitle: the video title, falling back to the link.
    var subtitle: String {
        if let title, !title.isEmpty { return title }
        return sourceURL
    }
}
