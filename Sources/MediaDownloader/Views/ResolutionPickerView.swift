import SwiftUI

/// Shows the resolutions a pasted video offers as selectable boxes. Tapping one starts the download.
struct ResolutionPickerView: View {
    let prompt: ResolutionPrompt
    var isRefining: Bool = false
    let onSelect: (VideoResolution) -> Void
    let onCancel: () -> Void

    @AppStorage("preferredVideoHeight") private var preferredHeight = -1
    @State private var selected: VideoResolution?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 7) {
                        Text("Choose quality")
                            .font(.system(size: 16, weight: .semibold))
                        if isRefining {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.7)
                        }
                    }
                    Text(isRefining ? "Checking exact qualities…" : prompt.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
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

            if let thumbnail = prompt.thumbnailURL, let url = URL(string: thumbnail) { MediaPreview(url: url) }
            HStack(spacing: 10) {
                ForEach(prompt.options) { option in
                    QualityBox(resolution: option) { selected = option }
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected == option ? Color.accentColor : .clear, lineWidth: 2))
                        .accessibilityAddTraits(selected == option ? .isSelected : [])
                }
            }
            HStack {
                Text(selected.map { "Selected: \($0.label)" } ?? "Choose a quality above")
                    .font(.callout).foregroundStyle(.secondary)
                Spacer()
                Button("Download") {
                    if let selected { preferredHeight = selected.id; onSelect(selected) }
                }
                .buttonStyle(.borderedProminent).disabled(selected == nil)
                .keyboardShortcut(.return, modifiers: [])
            }
        }
        .onAppear { selected = prompt.options.first { $0.id == preferredHeight } ?? prompt.options.first }
        .onChange(of: prompt.options) { _, options in
            if !options.contains(where: { $0 == selected }) { selected = options.first }
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

private struct QualityBox: View {
    let resolution: VideoResolution
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(resolution.label)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isHovering ? Color.appAccent : .primary)

                if let subtitle = resolution.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isHovering ? Color.appAccent.opacity(0.16) : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isHovering ? Color.appAccent : Color.white.opacity(0.08), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering ? 1.03 : 1)
        .onHover { isHovering = $0 }
        .animation(.spring(response: 0.28, dampingFraction: 0.7), value: isHovering)
    }
}

/// Placeholder card shown while the app is checking a link — what it says changes
/// depending on what's being checked (a playlist, an Instagram profile, a Pinterest
/// board, or just a video's available resolutions), so it's always clear what's happening.
struct ProbingCard: View {
    var message = "Finding available resolutions…"

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .frame(width: 680, height: 72)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 24, x: 0, y: 14)
    }
}
