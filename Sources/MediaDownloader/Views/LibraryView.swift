import SwiftUI
import AVFoundation
import ImageIO

struct LibraryView: View {
    @ObservedObject var model: AppModel
    @State private var query = ""
    @State private var kind = "All"
    private var items: [DownloadItem] {
        model.history.filter { item in
            (query.isEmpty || item.displayName.localizedCaseInsensitiveContains(query) || item.sourceName.localizedCaseInsensitiveContains(query)) &&
            (kind == "All" || (kind == "Images" && item.isImageFile) || (kind == "Archives" && item.isZipFile) || (kind == "Videos" && !item.isImageFile && !item.isZipFile))
        }
    }
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("Search library", text: $query).textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Search library by title or source")
                Picker("File type", selection: $kind) {
                    ForEach(["All", "Images", "Videos", "Archives"], id: \.self) { Text($0) }
                }.frame(width: 150)
                if !model.removedHistory.isEmpty {
                    Button("Undo Removal", action: model.undoHistoryRemoval).keyboardShortcut("z")
                }
            }
            if items.isEmpty {
                ContentUnavailableView("No matching files", systemImage: "magnifyingglass", description: Text("Try another title or file type."))
            } else {
                List(items) { item in
                    LibraryFileRow(item: item, model: model)
                }.listStyle(.plain)
            }
        }.padding(16).frame(minWidth: 480, minHeight: 320)
    }
}

private struct LibraryFileRow: View {
    let item: DownloadItem
    @ObservedObject var model: AppModel
    @State private var metadata = ""
    private var exists: Bool { FileManager.default.fileExists(atPath: item.filePath) }
    var body: some View {
        HStack(spacing: 12) {
            if let path = item.thumbnailPath, let image = NSImage(contentsOfFile: path) {
                Image(nsImage: image).resizable().scaledToFit().frame(width: 64, height: 48).accessibilityHidden(true)
            } else {
                Image(systemName: item.isZipFile ? "archivebox" : "film").frame(width: 64, height: 48).accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayName).font(.headline).lineLimit(1)
                Text(exists ? metadata : "File moved or removed").font(.caption).foregroundStyle(.secondary)
                Text(item.createdAt, format: .dateTime.year().month().day().hour().minute()).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                Button("Open File") { NSWorkspace.shared.open(URL(fileURLWithPath: item.filePath)) }.disabled(!exists)
                Button("Copy File") { model.copyFile(item) }.disabled(!exists)
                Button("Show in Finder") { model.revealInFinder(item) }.disabled(!exists)
                Button("Open Source") { model.openSourceURL(item) }
                Divider()
                Button("Remove from History") { model.deleteHistoryItem(item) }
            } label: { Image(systemName: "ellipsis.circle") }
                .menuStyle(.borderlessButton).frame(width: 28).accessibilityLabel("Actions for \(item.displayName)")
        }
        .contextMenu {
            Button("Copy File") { model.copyFile(item) }.disabled(!exists)
            Button("Show in Finder") { model.revealInFinder(item) }.disabled(!exists)
            Button("Remove from History") { model.deleteHistoryItem(item) }
        }
        .task(id: item.filePath) {
            let url = URL(fileURLWithPath: item.filePath)
            var parts = [url.pathExtension.uppercased()]
            if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                parts.append(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
            }
            if item.isImageFile, let source = CGImageSourceCreateWithURL(url as CFURL, nil),
               let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
               let width = properties[kCGImagePropertyPixelWidth] as? Int,
               let height = properties[kCGImagePropertyPixelHeight] as? Int {
                parts.append("\(width) × \(height)")
            } else if !item.isZipFile {
                let asset = AVURLAsset(url: url)
                if let track = try? await asset.loadTracks(withMediaType: .video).first,
                   let size = try? await track.load(.naturalSize),
                   let transform = try? await track.load(.preferredTransform) {
                    let displaySize = size.applying(transform)
                    parts.append("\(Int(abs(displaySize.width))) × \(Int(abs(displaySize.height)))")
                }
            }
            metadata = parts.joined(separator: " · ")
        }
    }
}
