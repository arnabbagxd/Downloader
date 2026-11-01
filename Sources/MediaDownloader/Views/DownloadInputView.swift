import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct DownloadInputView: View {
    @Binding var text: String
    let isDownloading: Bool
    let progress: Double
    let folderName: String
    let onSubmit: () -> Void
    let onPaste: () -> Void
    let onPasteFiles: ([URL]) -> Bool
    let onChooseFolder: () -> Void
    let onClearHistory: () -> Void
    let onOpenSettings: () -> Void
    let onFocusHistory: () -> Void

    @State private var clipboardFeedback: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Download or convert").font(.title2.weight(.semibold))
            Text("Paste a media link, or add images and PDFs to convert.")
                .font(.callout).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Image(systemName: "link").foregroundStyle(.secondary).accessibilityHidden(true)
                PasteAwareTextField(
                    text: $text,
                    placeholder: "Paste a video or image link",
                    onSubmit: onSubmit,
                    onPaste: onPaste,
                    onPasteFiles: onPasteFiles,
                    onTab: onFocusHistory
                ).frame(height: 32).disabled(isDownloading)
                if isDownloading {
                    ProgressView(value: progress > 0 ? progress : nil).frame(width: 28)
                } else {
                    Button(action: onSubmit) { Image(systemName: "arrow.right") }
                        .buttonStyle(.borderedProminent).buttonBorderShape(.circle)
                        .disabled(!URLValidator.looksLikeWebURL(text))
                        .help("Review download options").accessibilityLabel("Review download options")
                }
            }
            .padding(12).nativeGlass(radius: 16)
            HStack(spacing: 10) {
                Button {
                    if let link = NSPasteboard.general.string(forType: .string), URLValidator.looksLikeWebURL(link) {
                        clipboardFeedback = nil
                        text = link
                        onPaste()
                    } else {
                        clipboardFeedback = "Copy a web link first, then choose Paste Link."
                    }
                } label: { Label("Paste Link", systemImage: "doc.on.clipboard") }
                Button(action: addFiles) { Label("Add Files…", systemImage: "plus") }
                Spacer()
                Text("You choose options before saving.").font(.caption).foregroundStyle(.secondary)
            }.controlSize(.large).disabled(isDownloading)
            if let clipboardFeedback {
                Text(clipboardFeedback).font(.callout).foregroundStyle(.secondary)
            }
        }.frame(width: 680, alignment: .leading)
    }

    private func addFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image, .pdf]
        panel.prompt = "Add Files"
        if panel.runModal() == .OK { _ = onPasteFiles(panel.urls) }
    }
}

/// A "buffering" circle: an empty ring while the download is starting, that fills in
/// like a pie chart — no percentage text, just how much of the circle is colored in.
private struct CircularDownloadIndicator: View {
    let progress: Double
    @State private var rotation: Double = 0

    // Below this we don't have a real percentage yet, so show the spinning arc.
    private var isIndeterminate: Bool { progress < 0.001 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.12), lineWidth: 2.6)

            if isIndeterminate {
                Circle()
                    .trim(from: 0.08, to: 0.74)
                    .stroke(
                        Color.primary.opacity(0.72),
                        style: StrokeStyle(lineWidth: 2.6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(rotation))
            } else {
                PieSlice(progress: progress)
                    .fill(Color.appAccent)
                    .padding(4)
                    .animation(.easeOut(duration: 0.25), value: progress)
            }
        }
        .padding(3)
        .onAppear {
            withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

/// A filled pie-chart wedge growing clockwise from the top, from 0% (empty) to 100%
/// (a full circle) — the "how much of the circle is colored in" fill the ring uses.
private struct PieSlice: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let clampedProgress = min(max(progress, 0), 1)

        var path = Path()
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + 360 * clampedProgress),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}
