import AppKit
import SwiftUI

struct MenuBarActivityView: View {
    @ObservedObject var model: AppModel
    let onOpenApp: () -> Void
    let onSettings: () -> Void
    let onOpenLibrary: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var clipboardFeedback: String?
    @State private var revealedRecentID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("Download It", systemImage: "arrow.down.circle.fill")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button(action: onSettings) { Image(systemName: "gearshape").frame(width: 28, height: 28) }
                    .buttonStyle(.plain).nativeGlass(radius: 16)
                    .help("Settings")
                    .accessibilityLabel("Settings")
            }

            if model.isProbing || model.isRefiningResolutions {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text(model.isProbing ? model.probingMessage : "Checking exact qualities…").font(.callout)
                }
            } else if let activity = model.activity {
                activityCard(activity)
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Ready when you are").font(.subheadline.weight(.semibold))
                    Text("Download a link or convert a file in the app.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }

            if let clipboardFeedback {
                Text(clipboardFeedback).font(.callout).foregroundStyle(.secondary)
            }
            HStack {
                Button(action: pasteLink) { Label("Paste Link", systemImage: "link") }
                    .buttonStyle(.bordered).controlSize(.large)
                    .buttonBorderShape(.capsule)
                    .disabled(model.isBusy || !ToolManager.isReady)
                Button("Open App", action: onOpenApp)
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .buttonBorderShape(.capsule)
                    .keyboardShortcut(.return, modifiers: [])
            }

            Divider()
            HStack {
                Text("Recent Files").font(.headline)
                Spacer()
                if !model.removedHistory.isEmpty {
                    Button("Undo") {
                        withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) { model.undoHistoryRemoval() }
                    }.buttonStyle(.borderless).help("Restore removed history")
                }
                Button(action: model.revealDownloadFolder) { Image(systemName: "folder") }
                    .buttonStyle(.borderless).help("Open download folder")
                    .accessibilityLabel("Open download folder")
            }
            if model.history.isEmpty {
                Text("Your completed downloads will appear here.")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                ForEach(Array(model.history.prefix(3))) { item in
                    SwipeToRemoveRow(id: item.id, revealedID: $revealedRecentID, onRemove: {
                        withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) {
                            model.deleteHistoryItem(item)
                            revealedRecentID = nil
                        }
                    }) { recentFile(item) }
                    .transition(reduceMotion ? .identity : .asymmetric(insertion: .opacity, removal: .move(edge: .leading).combined(with: .opacity)))
                }
            }
            Button(action: onOpenLibrary) {
                HStack { Text("Show All Files"); Spacer(); Image(systemName: "chevron.right").font(.caption.weight(.semibold)) }
                    .padding(.horizontal, 14).padding(.vertical, 11)
            }.buttonStyle(.plain).nativeGlass(radius: 14)
            Toggle("Completion notifications", isOn: Binding(get: { model.notificationsEnabled }, set: model.setNotifications))
                .toggleStyle(.switch).controlSize(.small).font(.callout)
            Divider()
            HStack {
                Text(model.isBusy ? "Working in the background" : "Files stay on your Mac")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.borderless)
                    .disabled(model.isBusy)
                    .help(model.isBusy ? "Wait for the current task to finish before quitting" : "Quit Download It")
            }
        }
        .padding(20)
        .frame(width: 360)
        .background(.regularMaterial)
        .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: model.activity?.state)
        .tint(.appAccent)
    }

    private func activityCard(_ activity: AppActivity) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: activity.isRunning ? "arrow.down.circle" : activity.state == .failed ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(activity.state == .failed ? Color.red : Color.appAccent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(activity.isRunning ? activity.title : activity.state == .failed ? "Needs attention" : activity.state == .cancelled ? "Cancelled" : "Finished")
                        .font(.subheadline.weight(.semibold)).lineLimit(2)
                    Text(model.activityDetail)
                        .font(.callout).foregroundStyle(.secondary)
                        .lineLimit(4).textSelection(.enabled)
                }
                Spacer(minLength: 0)
                if !activity.isRunning {
                    Button(action: model.dismissActivity) { Image(systemName: "xmark") }
                        .buttonStyle(.borderless).help("Dismiss result")
                        .accessibilityLabel("Dismiss result")
                }
            }
            if model.canCancel {
                Button(model.isCancelling ? "Cancelling…" : "Cancel Task", action: model.cancelActivity)
                    .disabled(model.isCancelling)
            }
            if model.canRetry && !model.isBusy {
                Button("Retry Task", action: model.retryActivity)
            }
            if activity.isRunning {
                if let progress = model.activityProgress {
                    ProgressView(value: progress).accessibilityLabel("Task progress")
                    Text("\(Int(progress * 100))%")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("In progress").font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let detail = model.transferDetail { Text(detail).font(.caption).monospacedDigit() }
                HStack(spacing: 4) {
                    Text("Elapsed")
                    Text(activity.startedAt, style: .timer).monospacedDigit()
                }
                .font(.caption).foregroundStyle(.secondary)
            } else if activity.state == .failed {
                Button("Copy Error Details") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(activity.detail, forType: .string)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 20))
    }

    private func recentFile(_ item: DownloadItem) -> some View {
        let exists = FileManager.default.fileExists(atPath: item.filePath)
        return HStack(spacing: 10) {
            recentThumbnail(item)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName).font(.callout).lineLimit(1).help(item.displayName)
                Text(exists ? item.sourceName : "File moved or removed")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button { model.copyFile(item) } label: { Image(systemName: "doc.on.doc") }
                .buttonStyle(.plain).foregroundStyle(.secondary).disabled(!exists)
                .help("Copy file").accessibilityLabel("Copy \(item.displayName)")
            Button { model.revealInFinder(item) } label: { Image(systemName: "folder") }
                .buttonStyle(.plain).foregroundStyle(.secondary).disabled(!exists)
                .help("Show in Finder").accessibilityLabel("Show \(item.displayName) in Finder")
        }
    }

    private func recentThumbnail(_ item: DownloadItem) -> some View {
        let image = item.thumbnailPath.flatMap { NSImage(contentsOfFile: $0) }
            ?? (item.isImageFile ? NSImage(contentsOfFile: item.filePath) : nil)
        return ZStack {
            RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05))
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 38, height: 38)
            } else {
                Image(systemName: item.isZipFile ? "archivebox" : item.isImageFile ? "photo" : "film")
                    .font(.title3).foregroundStyle(.secondary)
            }
        }
        .frame(width: 38, height: 38)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func pasteLink() {
        guard let text = NSPasteboard.general.string(forType: .string), URLValidator.looksLikeWebURL(text) else {
            clipboardFeedback = "Copy a web link first, then choose Paste Link."
            return
        }
        clipboardFeedback = nil
        model.handleDroppedText(text)
        onOpenApp()
    }
}
