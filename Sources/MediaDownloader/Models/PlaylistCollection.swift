import Foundation

/// One video inside a playlist or channel, as reported by yt-dlp's flat-playlist listing.
struct PlaylistEntry: Equatable, Identifiable {
    let id: String
    let webpageURL: String
    let title: String?
}

/// The result of probing a link that turned out to be a playlist or channel: an overall
/// title plus every entry it contains (already capped to a sane maximum).
struct PlaylistProbeResult {
    let title: String?
    let entries: [PlaylistEntry]
}

/// Shown after probing a playlist/channel link with more than one video: lets the user
/// confirm downloading every entry (at their chosen quality) before anything starts.
struct PlaylistDownloadPrompt: Equatable {
    let sourceURL: String
    let title: String
    let entries: [PlaylistEntry]
}

/// Live progress while a playlist/channel is being downloaded item by item.
struct PlaylistDownloadStatus: Equatable {
    let title: String
    let completed: Int
    let total: Int
    let currentItemTitle: String?

    var fraction: Double {
        total > 0 ? Double(completed) / Double(total) : 0
    }
}
