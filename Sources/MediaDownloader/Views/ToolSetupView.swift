import SwiftUI

/// Drives the one-time first-run download of yt-dlp + ffmpeg.
@MainActor
final class ToolSetupModel: ObservableObject {
    enum Phase: Equatable {
        case installing
        case failed(String)
    }

    @Published private(set) var phase: Phase = .installing
    @Published private(set) var status: String = "Getting things ready…"

    private let onReady: () -> Void
    private var isRunning = false

    init(onReady: @escaping () -> Void) {
        self.onReady = onReady
    }

    func start() {
        // Guard against the window re-appearing and firing onAppear again mid-download.
        guard !isRunning else { return }
        isRunning = true
        phase = .installing
        status = "Getting things ready…"

        Task { [weak self] in
            do {
                try await ToolManager.ensureInstalled { message in
                    Task { @MainActor in self?.status = message }
                }
                self?.isRunning = false
                self?.onReady()
            } catch {
                self?.isRunning = false
                self?.phase = .failed(error.localizedDescription)
            }
        }
    }
}

struct ToolSetupView: View {
    @ObservedObject var model: ToolSetupModel

    var body: some View {
        ZStack {
            VStack(spacing: 18) {
                LucideIcon(name: "download", size: 42, lineWidth: 1.6)
                    .foregroundStyle(Color.appAccent)

                Text("Setting up Download It")
                    .font(.system(size: 20, weight: .semibold))

                switch model.phase {
                case .installing:
                    ProgressView()
                        .controlSize(.small)

                    Text(model.status)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)

                    Text("Downloading the tools it needs (about 60 MB). This happens only once.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                case .failed(let message):
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(action: model.start) {
                        Text("Try Again")
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 140, height: 26)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(30)
            .frame(width: 420)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(.white.opacity(0.16), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.24), radius: 28, x: 0, y: 18)
        }
        .frame(width: 520, height: 360)
        .onAppear(perform: model.start)
    }
}
