import SwiftUI

/// Shown while a Pinterest board/Idea Pin is being downloaded and zipped — this can take
/// a while (several items in sequence), so it makes the activity impossible to miss.
struct PinterestBundleProgressView: View {
    let status: PinterestBundleStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)

                VStack(alignment: .leading, spacing: 2) {
                    Text(status.phase == .zipping ? "Bundling into a zip…" : "Bundling \(status.title)")
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(status.phase == .zipping
                         ? "Packing \(status.total) items…"
                         : "Downloading \(status.completed) of \(status.total) items…")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            ProgressView(value: status.phase == .zipping ? 1 : status.fraction)
                .tint(.appAccent)
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
