import SwiftUI

/// Lets the user choose how to save a multi-item collection (Pinterest board/Idea Pin,
/// or an Instagram profile): zip vs. separate files, plus a target format (and quality)
/// for any images inside it.
struct CollectionOptionsPickerView: View {
    let prompt: CollectionDownloadPrompt
    let onConfirm: (CollectionSaveMode, ImageFormat?, Int, Set<Int>) -> Void
    let onCancel: () -> Void

    @State private var saveMode: CollectionSaveMode = .zip
    @State private var imageFormat: ImageFormat? = nil // nil == keep original
    @State private var quality: Double = 80

    private var countSummary: String {
        var parts: [String] = []
        if prompt.videoCount > 0 { parts.append("\(prompt.videoCount) video\(prompt.videoCount == 1 ? "" : "s")") }
        if prompt.imageCount > 0 { parts.append("\(prompt.imageCount) image\(prompt.imageCount == 1 ? "" : "s")") }
        return parts.joined(separator: ", ")
    }

    @State private var selected = Set<Int>()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(prompt.title)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text("\(prompt.source.displayName) — \(prompt.items.count) items found — \(countSummary)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
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
                .help("Cancel")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Save as")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    ForEach(CollectionSaveMode.allCases) { mode in
                        ChoiceBox(
                            title: mode.displayName,
                            subtitle: mode.subtitle,
                            isSelected: saveMode == mode
                        ) {
                            saveMode = mode
                        }
                    }
                }
            }

            if prompt.imageCount > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Image format")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        ChoiceBox(title: "Original", subtitle: "Keep as-is", isSelected: imageFormat == nil) {
                            imageFormat = nil
                        }
                        ForEach(ImageFormat.allCases) { format in
                            ChoiceBox(title: format.displayName, subtitle: format.subtitle, isSelected: imageFormat == format) {
                                imageFormat = format
                            }
                        }
                    }

                    if let imageFormat, imageFormat.isLossy {
                        HStack(spacing: 12) {
                            Text("Quality")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                            Slider(value: $quality, in: 10...100, step: 5)
                                .tint(.appAccent)
                            Text("\(Int(quality))%")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .frame(width: 44, alignment: .trailing)
                        }
                        .padding(.top, 2)
                    }
                }
            }

            Text("Profiles and boards load up to 30 items at a time.").font(.caption).foregroundStyle(.secondary)
            BatchSelectionView(titles: prompt.items.map { $0.title ?? $0.webpageURL }, selected: $selected)

            Button {
                onConfirm(saveMode, imageFormat, Int(quality), selected)
            } label: {
                Text("Download")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
            }
            .buttonStyle(.plain)
            .disabled(selected.isEmpty)
            .background(Color.appAccent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .onAppear { selected = Set(0..<prompt.items.count) }
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

private struct ChoiceBox: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.appAccent : .primary)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.appAccent.opacity(0.16) : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? Color.appAccent : Color.white.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering ? 1.02 : 1)
        .onHover { isHovering = $0 }
        .animation(.spring(response: 0.28, dampingFraction: 0.7), value: isHovering)
        .animation(.easeOut(duration: 0.12), value: isSelected)
    }
}
