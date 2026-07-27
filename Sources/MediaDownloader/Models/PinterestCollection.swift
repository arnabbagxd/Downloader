import Foundation

/// One item inside a Pinterest pin, Idea Pin, or board — either a video or an image.
struct PinterestCollectionItem: Equatable {
    let webpageURL: String
    let title: String?
    /// Available video heights (highest first); empty when this item has no video.
    let heights: [Int]
    /// Full-resolution image URL, used when there's no video.
    let imageURL: String?

    var isImage: Bool { heights.isEmpty }
}

/// The result of probing a Pinterest pin, Idea Pin, or board: an overall title plus every
/// item found (one item for a plain pin, several for a multi-page pin or a board).
struct PinterestCollectionResult {
    let title: String?
    let items: [PinterestCollectionItem]
}

/// Live progress while a Pinterest board/Idea Pin is being downloaded and bundled,
/// shown as a dedicated card so it's obvious the app is working (this can take a while).
struct PinterestBundleStatus: Equatable {
    enum Phase: Equatable { case downloading, zipping }

    let phase: Phase
    let completed: Int
    let total: Int
    let title: String

    var fraction: Double {
        total > 0 ? Double(completed) / Double(total) : 0
    }
}
