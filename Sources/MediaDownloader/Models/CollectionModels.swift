import Foundation

/// Which site a multi-item collection (board, profile, etc.) came from — drives labels
/// like "Pinterest board" / "Instagram profile" in the picker and progress UI.
enum CollectionSource: Equatable {
    case pinterest
    case instagram

    var displayName: String {
        switch self {
        case .pinterest: return "Pinterest"
        case .instagram: return "Instagram"
        }
    }
}

/// One item inside a multi-item collection (a Pinterest board/Idea Pin, or an Instagram
/// profile) — either a video or an image.
struct CollectionItem: Equatable {
    let webpageURL: String
    let title: String?
    /// Available video heights (highest first); empty when this item has no video.
    let heights: [Int]
    /// Full-resolution image URL, used when there's no video.
    let imageURL: String?

    var isImage: Bool { heights.isEmpty }
}

/// The result of probing a collection link: an overall title plus every item found.
struct CollectionProbeResult {
    let title: String?
    let items: [CollectionItem]
}

/// How to save a multi-item collection once it's downloaded.
enum CollectionSaveMode: String, CaseIterable, Identifiable {
    case zip
    case individual

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .zip: return "Zip File"
        case .individual: return "Separate Files"
        }
    }

    var subtitle: String {
        switch self {
        case .zip: return "Everything in one .zip"
        case .individual: return "Each item saved on its own"
        }
    }
}

/// Shown after probing a board/Idea Pin/profile with more than one item: lets the user
/// choose zip vs. separate files, and a target image format, before anything downloads.
struct CollectionDownloadPrompt: Equatable {
    let source: CollectionSource
    let sourceURL: String
    let title: String
    let items: [CollectionItem]

    var videoCount: Int { items.filter { !$0.isImage }.count }
    var imageCount: Int { items.filter(\.isImage).count }
}

/// Live progress while a collection is being downloaded and bundled, shown as a dedicated
/// card so it's obvious the app is working (this can take a while).
struct CollectionBundleStatus: Equatable {
    enum Phase: Equatable { case downloading, converting, finishing }

    let source: CollectionSource
    let phase: Phase
    let completed: Int
    let total: Int
    let title: String
    let saveMode: CollectionSaveMode
    /// The title of the item currently being downloaded, when known.
    let currentItemTitle: String?

    var fraction: Double {
        total > 0 ? Double(completed) / Double(total) : 0
    }
}
