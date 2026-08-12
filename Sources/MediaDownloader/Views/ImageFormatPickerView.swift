import SwiftUI

/// Shows target-format boxes + a quality slider. Clicking a box converts at the current quality.
struct ImageFormatPickerView: View {
    let prompt: ConversionPrompt
    let onSelect: (ImageFormat?, Int) -> Void   // format == nil means "Original" (remote only)
    let onCancel: () -> Void

    @State private var quality: Double = 80

    private var heading: String {
        prompt.count > 1 ? "Convert \(prompt.count) images" : "Convert image"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
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
                .help("Cancel")
            }

            // Quality slider — only meaningful for lossy formats.
            VStack(alignment: .leading, spacing: 4) {
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
                Text("Applies to JPG, WebP & AVIF — PNG is always lossless.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                if prompt.allowsOriginal {
                    FormatBox(title: "Original", subtitle: "Keep as-is") {
                        onSelect(nil, Int(quality))
                    }
                }
                ForEach(ImageFormat.allCases) { format in
                    FormatBox(title: format.displayName, subtitle: format.subtitle) {
                        onSelect(format, Int(quality))
                    }
                }
            }
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
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isHovering ? Color.appAccent : .primary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
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
