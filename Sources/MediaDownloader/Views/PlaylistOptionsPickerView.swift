import SwiftUI

/// Shown when a pasted link turns out to be a playlist or channel with more than one
/// video: lets the user confirm downloading every entry before anything starts.
struct PlaylistOptionsPickerView: View {
    let prompt: PlaylistDownloadPrompt
    let onConfirm: (Set<Int>) -> Void
    let onCancel: () -> Void

    @State private var selected = Set<Int>()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(prompt.title)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text("This is a playlist with \(prompt.entries.count) video\(prompt.entries.count == 1 ? "" : "s")")
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

            Text("Up to 50 entries are loaded per playlist.").font(.caption).foregroundStyle(.secondary)
            BatchSelectionView(titles: prompt.entries.map { $0.title ?? $0.webpageURL }, selected: $selected)

            Button {
                onConfirm(selected)
            } label: {
                Text("Download \(selected.count) Videos")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
            }
            .buttonStyle(.plain)
            .disabled(selected.isEmpty)
            .background(Color.appAccent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .onAppear { selected = Set(0..<prompt.entries.count) }
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
