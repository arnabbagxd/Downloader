import AppKit
import SwiftUI

struct DownloadInputView: View {
    @Binding var text: String
    let isDownloading: Bool
    let progress: Double
    let folderName: String
    let onSubmit: () -> Void
    let onPaste: () -> Void
    let onChooseFolder: () -> Void
    let onClearHistory: () -> Void
    let onOpenSettings: () -> Void
    let onFocusHistory: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            LucideIcon(name: "link", size: 18)
                .foregroundStyle(Color.primary.opacity(0.4))

            PasteAwareTextField(
                text: $text,
                placeholder: "Paste Instagram, X, or YouTube URL",
                onSubmit: onSubmit,
                onPaste: onPaste,
                onTab: onFocusHistory
            )
            .frame(height: 36)

            if isDownloading {
                CircularDownloadIndicator(progress: progress)
                    .frame(width: 30, height: 30)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            InputSettingsButton(
                folderName: folderName,
                onChooseFolder: onChooseFolder,
                onClearHistory: onClearHistory,
                onOpenSettings: onOpenSettings
            )
            .opacity(isHovering ? 1 : 0)
            .allowsHitTesting(isHovering)
            .animation(.easeOut(duration: 0.14), value: isHovering)
        }
        .padding(.leading, 20)
        .padding(.trailing, 12)
        .frame(width: 680, height: 64)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(.white.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.22), radius: 28, x: 0, y: 18)
        .onHover { isHovering = $0 }
    }
}

private struct InputSettingsButton: View {
    let folderName: String
    let onChooseFolder: () -> Void
    let onClearHistory: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        Button(action: showMenu) {
            LucideIcon(name: "settings", size: 17)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.primary.opacity(0.58))
        .help("Download folder: \(folderName)")
    }

    private func showMenu() {
        guard let contentView = NSApp.keyWindow?.contentView else {
            return
        }

        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(actionItem(title: "Settings", iconName: "settings", action: onOpenSettings))
        menu.addItem(actionItem(title: "Change Folder", iconName: "folder", action: onChooseFolder))
        menu.addItem(.separator())
        menu.addItem(actionItem(title: "Clear History", iconName: "trash-2", action: onClearHistory))

        let pointInWindow = NSPoint(
            x: NSEvent.mouseLocation.x - contentView.window!.frame.minX,
            y: NSEvent.mouseLocation.y - contentView.window!.frame.minY
        )
        let pointInView = contentView.convert(pointInWindow, from: nil)
        menu.popUp(positioning: nil, at: pointInView, in: contentView)
    }

    private func actionItem(title: String, iconName: String, action: @escaping () -> Void) -> NSMenuItem {
        let target = InputMenuActionTarget(action)
        let item = NSMenuItem(title: title, action: #selector(InputMenuActionTarget.performAction), keyEquivalent: "")
        item.target = target
        item.representedObject = target
        item.image = LucideIconStore.menuImage(iconName)
        return item
    }
}

private final class InputMenuActionTarget: NSObject {
    private let action: () -> Void

    init(_ action: @escaping () -> Void) {
        self.action = action
    }

    @objc func performAction() {
        action()
    }
}

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
                Circle()
                    .trim(from: 0, to: max(0.02, progress))
                    .stroke(
                        Color.appAccent,
                        style: StrokeStyle(lineWidth: 2.6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.25), value: progress)

                Text("\(Int((progress * 100).rounded()))")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.85))
                    .monospacedDigit()
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
