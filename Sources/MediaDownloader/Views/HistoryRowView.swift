import AppKit
import SwiftUI

struct HistoryRowView: View {
    let item: DownloadItem
    let isKeyboardSelected: Bool
    let copySucceeded: Bool
    let suppressHoverHighlight: Bool
    let onCopy: () -> Void
    let onMarkCopied: () -> Void
    let onReveal: () -> Void
    let onOpenSource: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void
    let onHoverChange: (Bool) -> Void
    @State private var isHovering = false
    @State private var dragOffset: CGFloat = 0

    // Swipe left past this distance to delete the row.
    private let deleteThreshold: CGFloat = 96

    var body: some View {
        ZStack(alignment: .trailing) {
            deleteReveal
            rowContent
                .offset(x: dragOffset)
                .gesture(swipeGesture)
        }
        .frame(height: 74)
    }

    private var rowContent: some View {
        HStack(spacing: 14) {
            ThumbnailView(path: item.thumbnailPath, isZip: item.isZipFile)
                .frame(width: 72, height: 54)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayName)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(item.sourceName)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 14)

            HStack(spacing: 4) {
                IconButton(iconName: "scissors", help: "Edit trim", action: onEdit)
                IconButton(
                    iconName: copySucceeded ? "check" : "copy",
                    help: "Copy file",
                    tint: copySucceeded ? .appAccent : .secondary,
                    action: copyFile
                )
                MoreIconButton(
                    onReveal: onReveal,
                    onOpenSource: onOpenSource,
                    onDelete: onDelete
                )
            }
            .opacity(isKeyboardSelected ? 1 : 0.72)
        }
        .padding(.horizontal, 8)
        .frame(height: 74)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isKeyboardSelected ? Color.appAccent.opacity(0.14) : Color.clear)
        }
        .contentShape(Rectangle())
        // Clicking anywhere on the row reopens the video panel (buttons keep their own actions).
        .onTapGesture(perform: onEdit)
        .scaleEffect(isHovering && !suppressHoverHighlight && dragOffset == 0 ? 1.012 : 1)
        .onHover {
            isHovering = $0
            onHoverChange($0)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
        .animation(.easeOut(duration: 0.12), value: isKeyboardSelected)
    }

    private var deleteReveal: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            ZStack {
                Color.red.opacity(0.92)
                LucideIcon(name: "trash-2", size: 20)
                    .foregroundStyle(.white)
                    .opacity(revealProgress)
                    .scaleEffect(0.6 + 0.4 * revealProgress)
            }
            .frame(width: max(0, -dragOffset))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var revealProgress: Double {
        Double(min(1, max(0, -dragOffset / deleteThreshold)))
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                // Only allow leftward swipes, with a little resistance past the threshold.
                dragOffset = value.translation.width < 0 ? max(value.translation.width, -160) : 0
            }
            .onEnded { value in
                if -value.translation.width > deleteThreshold {
                    onDelete()
                    dragOffset = 0
                } else {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        dragOffset = 0
                    }
                }
            }
    }

    private func copyFile() {
        onCopy()
        onMarkCopied()
    }
}

private struct MoreIconButton: View {
    let onReveal: () -> Void
    let onOpenSource: () -> Void
    let onDelete: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: showMenu) {
            LucideIcon(name: "ellipsis", size: 16)
                .frame(width: 30, height: 30)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isHovering ? Color.appAccent.opacity(0.16) : Color.primary.opacity(0.04))
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isHovering ? Color.appAccent : Color.secondary)
        .help("More")
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.1), value: isHovering)
    }

    private func showMenu() {
        guard let contentView = NSApp.keyWindow?.contentView else {
            return
        }

        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(actionItem(title: "Open in Finder", iconName: "folder", action: onReveal))
        menu.addItem(actionItem(title: "Open Link", iconName: "external-link", action: onOpenSource))
        menu.addItem(.separator())
        menu.addItem(actionItem(title: "Delete", iconName: "trash-2", action: onDelete))

        let pointInWindow = NSPoint(
            x: NSEvent.mouseLocation.x - contentView.window!.frame.minX,
            y: NSEvent.mouseLocation.y - contentView.window!.frame.minY
        )
        let pointInView = contentView.convert(pointInWindow, from: nil)
        menu.popUp(positioning: nil, at: pointInView, in: contentView)
    }

    private func actionItem(title: String, iconName: String, action: @escaping () -> Void) -> NSMenuItem {
        let target = MenuActionTarget(action)
        let item = NSMenuItem(title: title, action: #selector(MenuActionTarget.performAction), keyEquivalent: "")
        item.target = target
        item.representedObject = target
        item.image = LucideIconStore.menuImage(iconName)
        return item
    }
}

private final class MenuActionTarget: NSObject {
    private let action: () -> Void

    init(_ action: @escaping () -> Void) {
        self.action = action
    }

    @objc func performAction() {
        action()
    }
}

private struct IconButton: View {
    let iconName: String
    let help: String
    var tint: Color = .secondary
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            LucideIcon(name: iconName, size: 16)
                .frame(width: 30, height: 30)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isHovering ? Color.appAccent.opacity(0.16) : Color.primary.opacity(0.04))
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isHovering ? Color.appAccent : tint)
        .help(help)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.1), value: isHovering)
    }
}

private struct ThumbnailView: View {
    let path: String?
    var isZip: Bool = false
    @State private var image: NSImage?

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            Group {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size.width, height: size.height)
                } else {
                    ZStack {
                        Rectangle()
                            .fill(.quaternary)

                        LucideIcon(name: isZip ? "folder" : "image", size: 22)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: size.width, height: size.height)
                }
            }
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .aspectRatio(4.0 / 3.0, contentMode: .fit)
        .task(id: path) {
            image = nil
            guard let path else { return }
            let data = await Task.detached(priority: .utility) {
                try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
            }.value
            guard !Task.isCancelled, let data else { return }
            image = NSImage(data: data)
        }
    }
}
