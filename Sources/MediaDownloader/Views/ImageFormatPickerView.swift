import SwiftUI

struct ImageFormatPickerView: View {
    let prompt: ConversionPrompt
    let onSelect: (ImageFormat?, Int, Set<Int>) -> Void
    let onCancel: () -> Void
    @AppStorage("preferredImageFormat") private var format = "jpg"
    @AppStorage("preferredImageQuality") private var quality = 80.0
    @State private var selected = Set<Int>()

    private var urls: [URL] {
        switch prompt.source {
        case .localFiles(let urls): return urls
        case .remoteImages(let urls): return urls.compactMap(URL.init(string:))
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(prompt.title).font(.headline).lineLimit(2)
                Spacer()
                Button("Cancel", action: onCancel).keyboardShortcut(.escape, modifiers: [])
            }
            if let url = urls.first {
                MediaPreview(url: url)
            }
            if prompt.count > 1 {
                BatchSelectionView(titles: urls.map(\.lastPathComponent), selected: $selected)
            }
            Picker("Output format", selection: $format) {
                if prompt.allowsOriginal { Text("Original").tag("original") }
                ForEach(ImageFormat.allCases) { Text($0.displayName).tag($0.rawValue) }
            }.pickerStyle(.segmented)
            if let choice = ImageFormat(rawValue: format), choice.isLossy {
                HStack {
                    Text("Quality \(Int(quality))%")
                    Slider(value: $quality, in: 10...100, step: 5).accessibilityLabel("Output quality")
                }
            }
            HStack {
                Text("\(selected.count) of \(prompt.count) selected").foregroundStyle(.secondary)
                Spacer()
                Button(prompt.allowsOriginal ? "Download" : "Convert") {
                    onSelect(ImageFormat(rawValue: format), Int(quality), selected)
                }.buttonStyle(.borderedProminent).disabled(selected.isEmpty)
                    .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(20).frame(width: 680)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 20))
        .onAppear {
            selected = Set(0..<prompt.count)
            if !prompt.allowsOriginal && format == "original" { format = "jpg" }
        }
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
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(selected.count) of \(titles.count) selected").font(.caption)
                Spacer()
                Button("Select All") { selected = Set(titles.indices) }
                Button("Clear") { selected = [] }
            }
            ScrollView {
                VStack(alignment: .leading) {
                    ForEach(titles.indices, id: \.self) { index in
                        Toggle(titles[index].isEmpty ? "Item \(index + 1)" : titles[index], isOn: Binding(
                            get: { selected.contains(index) },
                            set: { if $0 { selected.insert(index) } else { selected.remove(index) } }
                        )).toggleStyle(.checkbox).lineLimit(1)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.frame(maxHeight: 120)
        }
    }
}
