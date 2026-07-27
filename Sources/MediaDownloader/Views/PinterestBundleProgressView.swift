import SwiftUI

/// Shown while a Pinterest board/Idea Pin is being downloaded and saved — this can take
/// a while (several items in sequence), so it makes the activity impossible to miss.
struct PinterestBundleProgressView: View {
    let status: PinterestBundleStatus

    private var title: String {
        switch status.phase {
        case .downloading: return "Downloading \(status.title)"
        case .converting: return "Converting images…"
        case .finishing: return status.saveMode == .zip ? "Bundling into a zip…" : "Saving files…"
        }
    }

    private var subtitle: String {
        switch status.phase {
        case .downloading: return "Downloading \(status.completed) of \(status.total) items…"
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
