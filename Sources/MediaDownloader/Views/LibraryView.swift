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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let categories = ["All", "Videos", "Images", "Archives"]
    private let symbols = ["All": "square.stack.3d.up", "Videos": "film", "Images": "photo", "Archives": "archivebox"]
    var body: some View {
        NavigationSplitView {
            List(selection: $kind) {
                Section("Library") {
                    ForEach(categories, id: \.self) { category in
                        Label(category == "All" ? "All Files" : category, systemImage: symbols[category] ?? "folder")
                            .tag(category)
                            .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 190, max: 230)
            .safeAreaInset(edge: .bottom) {
                Button(action: model.revealDownloadFolder) {
                    Label("Downloads Folder", systemImage: "folder")
                }.buttonStyle(.borderless).padding(16)
            }
        } detail: {
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(kind == "All" ? "All Files" : kind).font(.largeTitle.weight(.bold))
                        Text("\(items.count) item\(items.count == 1 ? "" : "s")")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !model.removedHistory.isEmpty {
                        Button("Undo Removal", action: model.undoHistoryRemoval).keyboardShortcut("z")
                    }
                }.padding(24)
                if items.isEmpty {
                    ContentUnavailableView(query.isEmpty ? "Your library starts here" : "No matching files", systemImage: query.isEmpty ? "tray" : "magnifyingglass", description: Text(query.isEmpty ? "Downloaded and converted files appear here." : "Try another title or file type."))
                        .frame(maxHeight: .infinity)
                } else {
                    List(items) { item in
                        LibraryFileRow(item: item, model: model)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                    }.listStyle(.inset).scrollContentBackground(.hidden)
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .navigationTitle("Download It — Library")
            .searchable(text: $query, prompt: "Search files")
            .toolbar {
                ToolbarItem {
                    Button(action: model.revealDownloadFolder) { Label("Open Downloads", systemImage: "folder") }
                        .help("Open download folder")
                }
            }
            .animation(reduceMotion ? nil : .smooth(duration: 0.22), value: kind)
        }
        .onChange(of: model.libraryPresentationID) { _, _ in
            query = ""
            kind = "All"
        }
        .frame(minWidth: 640, minHeight: 400)
    }
}

private struct LibraryFileRow: View {
    let item: DownloadItem
    @ObservedObject var model: AppModel
    @State private var metadata = ""
    private var exists: Bool { FileManager.default.fileExists(atPath: item.filePath) }
    var body: some View {
        HStack(spacing: 16) {
            if let path = item.thumbnailPath, let image = NSImage(contentsOfFile: path) {
                Image(nsImage: image).resizable().scaledToFit().frame(width: 64, height: 56).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10)).clipShape(RoundedRectangle(cornerRadius: 10)).accessibilityHidden(true)
            } else {
                Image(systemName: item.isZipFile ? "archivebox" : item.isImageFile ? "photo" : "film").frame(width: 64, height: 56).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10)).clipShape(RoundedRectangle(cornerRadius: 10)).accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayName).font(.body.weight(.medium)).lineLimit(1)
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
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().frame(width: 30, height: 30).accessibilityLabel("Actions for \(item.displayName)")
        }
        .padding(12)
        .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 16))
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
