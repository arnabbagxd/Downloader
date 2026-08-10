import SwiftUI

/// Shown while a multi-item collection (Pinterest board/Idea Pin, or an Instagram
/// profile) is being downloaded and saved — this can take a while (several items in
/// sequence), so it makes the activity impossible to miss and shows what's happening now.
struct CollectionBundleProgressView: View {
    let status: CollectionBundleStatus

    private var title: String {
        switch status.phase {
        case .downloading: return "Downloading \(status.title)"
        case .converting: return "Converting images…"
        case .finishing: return status.saveMode == .zip ? "Bundling into a zip…" : "Saving files…"
        }
    }

    private var subtitle: String {
        switch status.phase {
        case .downloading:
            let position = "Downloading \(status.completed) of \(status.total) items"
            guard let currentItemTitle = status.currentItemTitle, !currentItemTitle.isEmpty else {
                return "\(position)…"
            }
            return "\(position): \(currentItemTitle)"
        case .converting: return "Converting \(status.total) images…"
        case .finishing: return status.saveMode == .zip ? "Packing \(status.total) items…" : "Saving \(status.total) items…"
        }
    }

    private var fraction: Double {
        status.phase == .downloading ? status.fraction : 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
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

            ProgressView(value: fraction)
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
