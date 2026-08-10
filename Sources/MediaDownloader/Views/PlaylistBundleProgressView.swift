import SwiftUI

/// Shown while a playlist/channel is being downloaded video by video.
struct PlaylistBundleProgressView: View {
    let status: PlaylistDownloadStatus

    private var subtitle: String {
        let position = "Downloading \(status.completed + 1) of \(status.total)"
        guard let currentItemTitle = status.currentItemTitle, !currentItemTitle.isEmpty else {
            return "\(position)…"
        }
        return "\(position): \(currentItemTitle)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Downloading \(status.title)")
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 0)
            }

            ProgressView(value: status.fraction)
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
