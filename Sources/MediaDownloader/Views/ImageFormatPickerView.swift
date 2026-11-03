import SwiftUI
import ImageIO

/// Compact format cards with optional batch selection and explicit confirmation.
struct ImageFormatPickerView: View {
    let prompt: ConversionPrompt
    let onSelect: (ImageFormat?, Int, Set<Int>) -> Void
    let onCancel: () -> Void

    @AppStorage("preferredImageFormat") private var format = "jpg"
    @AppStorage("preferredImageQuality") private var quality = 90.0
    @AppStorage("uses90PercentImageQualityDefault") private var uses90PercentDefault = false
    @State private var selected = Set<Int>()

    private var urls: [URL] {
        switch prompt.source {
        case .localFiles(let urls): return urls
        case .remoteImages(let urls): return urls.compactMap(URL.init(string:))
        }
    }

    private var heading: String {
        prompt.count > 1 ? "Convert \(prompt.count) images" : "Convert image"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                if prompt.count == 1, let url = urls.first {
                    SelectionThumbnail(url: url)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(heading)
                        .font(.system(size: 16, weight: .semibold))
                    Text(prompt.title)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 12)

                Button(action: onCancel) {
                    LucideIcon(name: "x", size: 15)
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                        .background(Color.primary.opacity(0.06), in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Cancel").accessibilityLabel("Cancel conversion")
                .keyboardShortcut(.escape, modifiers: [])
            }

            if prompt.count > 1 {
                DisclosureGroup("Choose images · \(selected.count) of \(prompt.count) selected") {
                    BatchSelectionView(titles: urls.map(\.lastPathComponent), selected: $selected, thumbnailURLs: urls)
                        .padding(.top, 8)
                }.font(.callout)
            }

            // PNG remains lossless; lossy output uses the selected quality.
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Text("Quality")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    Slider(value: $quality, in: 10...100, step: 5)
                        .tint(.appAccent).accessibilityLabel("Output quality")
                    Text("\(Int(quality))%")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                }
                Text("Applies to JPG, WebP & AVIF — PNG is always lossless.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                if prompt.allowsOriginal {
                    FormatBox(title: "Original", subtitle: "Keep as-is", isSelected: format == "original") {
                        format = "original"
                    }
                }
                ForEach(ImageFormat.allCases) { format in
                    FormatBox(title: format.displayName, subtitle: format.subtitle, isSelected: self.format == format.rawValue) {
                        self.format = format.rawValue
                    }
                }
            }
            HStack {
                Text(prompt.count == 1 ? "1 image" : "\(selected.count) images selected")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(prompt.allowsOriginal ? "Download" : "Convert") {
                    onSelect(ImageFormat(rawValue: format), Int(quality), selected)
                }
                .buttonStyle(.borderedProminent).disabled(selected.isEmpty)
                .keyboardShortcut(.return, modifiers: [])
            }
        }
        .onAppear {
            selected = Set(0..<prompt.count)
            if !prompt.allowsOriginal && format == "original" { format = "jpg" }
            // Apply the requested new default to existing installations once as well.
            if !uses90PercentDefault { quality = 90; uses90PercentDefault = true }
        }
        .padding(20)
        .frame(width: 680)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 24, x: 0, y: 14)
    }
}

private struct FormatBox: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle((isSelected || isHovering) ? Color.appAccent : .primary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill((isSelected || isHovering) ? Color.appAccent.opacity(0.16) : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder((isSelected || isHovering) ? Color.appAccent : Color.white.opacity(0.08), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .scaleEffect(isHovering && !reduceMotion ? 1.03 : 1)
        .onHover { isHovering = $0 }
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.7), value: isHovering)
    }
}

struct MediaPreview: View {
    let url: URL
    var body: some View {
        Group {
            if url.isFileURL, let image = NSImage(contentsOf: url) {
                Image(nsImage: image).resizable().scaledToFit()
            } else {
                AsyncImage(url: url) { image in image.resizable().scaledToFit() } placeholder: {
                    Label("Image preview", systemImage: "photo").foregroundStyle(.secondary)
                }
            }
        }.frame(maxWidth: .infinity).frame(height: 100)
            .accessibilityLabel("Preview of \(url.lastPathComponent)")
    }
}

struct BatchSelectionView: View {
    let titles: [String]
    @Binding var selected: Set<Int>
    var thumbnailURLs: [URL] = []
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(selected.count) of \(titles.count) selected").font(.caption)
                Spacer()
                Button("Select All") { selected = Set(titles.indices) }
                Button("Clear") { selected = [] }
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(titles.indices, id: \.self) { index in
                        Toggle(isOn: Binding(
                            get: { selected.contains(index) },
                            set: { if $0 { selected.insert(index) } else { selected.remove(index) } }
                        )) {
                            HStack(spacing: 7) {
                                if thumbnailURLs.indices.contains(index) {
                                    SelectionThumbnail(url: thumbnailURLs[index])
                                }
                                Text(titles[index].isEmpty ? "Item \(index + 1)" : titles[index])
                                    .lineLimit(1).truncationMode(.middle)
                            }
                        }.toggleStyle(.checkbox)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.frame(maxHeight: 120)
        }
    }
}


/// Decode only a tiny preview, rather than loading every full-resolution image in a batch.
private struct SelectionThumbnail: View {
    let url: URL
    @State private var localImage: NSImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.06))
            if url.isFileURL {
                if let localImage {
                    Image(nsImage: localImage).resizable().scaledToFill()
                } else {
                    Image(systemName: "photo").font(.caption).foregroundStyle(.secondary)
                }
            } else {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "photo").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 24, height: 24)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .accessibilityHidden(true)
        .task(id: url) {
            localImage = nil
            guard url.isFileURL else { return }
            let work = Task.detached(priority: .utility) { () -> CGImage? in
                guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
                return CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 64,
                    kCGImageSourceShouldCacheImmediately: true
                ] as CFDictionary)
            }
            let image = await withTaskCancellationHandler(operation: { await work.value }, onCancel: { work.cancel() })
            guard !Task.isCancelled else { return }
            if let image { localImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height)) }
        }
    }
}
