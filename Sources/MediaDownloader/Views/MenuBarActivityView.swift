import AppKit
import SwiftUI

struct MenuBarActivityView: View {
    @ObservedObject var model: AppModel
    let onOpenApp: () -> Void
    let onSettings: () -> Void
    let onOpenLibrary: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var clipboardFeedback: String?

    private var maxContentHeight: CGFloat {
        min(560, max(320, (NSScreen.main?.visibleFrame.height ?? 720) - 120))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    currentActivity
                    primaryActions
                    recentFiles
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            }
            .frame(maxHeight: maxContentHeight)
        }
        .frame(width: 360)
        .background(.regularMaterial)
        .tint(.appAccent)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: model.activity?.state)
    }

    private var header: some View {
        HStack(spacing: 9) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color.appAccent)
                .accessibilityHidden(true)
            Text("Download It").font(.system(size: 15, weight: .semibold))
            Spacer()
            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 15))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Settings")
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 16)
    }

    @ViewBuilder private var currentActivity: some View {
        if model.isProbing || model.isRefiningResolutions {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 24, height: 24)
                        .accessibilityLabel("Checking link")
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Checking link").font(.system(size: 14, weight: .semibold))
                        Text(model.isProbing ? model.probingMessage : "Checking exact qualities…")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                if model.canCancel {
                    Button(model.isCancelling ? "Cancelling…" : "Cancel Task", action: model.cancelActivity)
                        .buttonStyle(.borderless)
                        .font(.system(size: 12, weight: .medium))
                        .disabled(model.isCancelling)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .activitySurface()
        } else if let activity = model.activity {
            activityCard(activity)
        } else {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 21))
                    .foregroundStyle(Color.appAccent)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Save media from a link").font(.system(size: 15, weight: .semibold))
                    Text("Paste a link, or open the app to convert a file.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .activitySurface()
        }
    }

    private func activityCard(_ activity: AppActivity) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                activityMark(activity)
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(activity.isRunning ? activity.title : resultTitle(activity))
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(2)
                        .help(activity.isRunning ? activity.title : resultTitle(activity))
                    Text(model.activityDetail)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if activity.isRunning, let progress = model.activityProgress {
                    Text("\(Int((progress * 100).rounded()))%")
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Color.appAccent)
                } else if !activity.isRunning {
                    Button(action: model.dismissActivity) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Dismiss result")
                    .accessibilityLabel("Dismiss result")
                }
            }
            if activity.isRunning {
                if let progress = model.activityProgress {
                    ProgressView(value: progress)
                        .tint(.appAccent)
                        .accessibilityLabel("Task progress")
                        .accessibilityValue("\(Int((progress * 100).rounded())) percent")
                        .padding(.top, 14)
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if let detail = model.transferDetail {
                        Text(detail).lineLimit(1).help(detail)
                    } else if model.activityProgress == nil {
                        Text("In progress")
                    }
                    Spacer(minLength: 0)
                    Text("Elapsed")
                    Text(activity.startedAt, style: .timer)
                }
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            }
            if model.canCancel || (model.canRetry && !model.isBusy) || activity.state == .failed {
                HStack(spacing: 12) {
                    if activity.state == .failed {
                        Button("Copy Error Details", action: copyErrorDetails)
                            .buttonStyle(.plain)
                    }
                    Spacer(minLength: 0)
                    if model.canCancel {
                        Button(model.isCancelling ? "Cancelling…" : "Cancel Task", action: model.cancelActivity)
                            .disabled(model.isCancelling)
                    } else if model.canRetry && !model.isBusy {
                        Button("Retry Task", action: model.retryActivity)
                    }
                }
                .buttonStyle(.borderless)
                .font(.system(size: 12, weight: .medium))
                .padding(.top, 12)
            }
        }
        .activitySurface()
    }

    @ViewBuilder private func activityMark(_ activity: AppActivity) -> some View {
        if activity.isRunning, let progress = model.activityProgress {
            ZStack {
                Circle().stroke(Color.primary.opacity(0.14), lineWidth: 2.5)
                Circle()
                    .trim(from: 0, to: CGFloat(min(max(progress, 0), 1)))
                    .stroke(Color.appAccent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        } else if activity.isRunning {
            ProgressView().controlSize(.small)
        } else {
            Image(systemName: activity.state == .failed ? "exclamationmark.circle.fill" : activity.state == .cancelled ? "stop.circle" : "checkmark.circle.fill")
                .font(.system(size: 21))
                .foregroundStyle(activity.state == .failed ? Color.red : activity.state == .cancelled ? Color.secondary : Color.appAccent)
        }
    }

    private func resultTitle(_ activity: AppActivity) -> String {
        switch activity.state {
        case .running: activity.title
        case .succeeded: "Finished"
        case .failed: "Needs attention"
        case .cancelled: "Cancelled"
        }
    }

    private var primaryActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button(action: pasteLink) {
                    Label("Paste Link", systemImage: "link")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(model.isBusy || !ToolManager.isReady)
                Button(action: onOpenApp) {
                    Text("Open App").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])
            }
            .controlSize(.regular)
            .buttonBorderShape(.roundedRectangle)
            if let clipboardFeedback {
                Text(clipboardFeedback)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .padding(.top, 16)
    }

    private var recentFiles: some View {
        let available = model.history.filter { FileManager.default.fileExists(atPath: $0.filePath) }
        let missingCount = model.history.count - available.count
        let recent = Array(available.prefix(3))
        return VStack(alignment: .leading, spacing: 0) {
            Divider().padding(.bottom, 16)
            HStack(spacing: 8) {
                Text("Recent Files").font(.system(size: 13, weight: .semibold))
                Spacer(minLength: 0)
                if !model.removedHistory.isEmpty {
                    Button("Undo", action: model.undoHistoryRemoval)
                        .buttonStyle(.borderless)
                        .font(.system(size: 11, weight: .medium))
                        .help("Restore removed history")
                }
                Button(action: model.revealDownloadFolder) {
                    Image(systemName: "folder")
                        .font(.system(size: 14))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Open download folder")
                .accessibilityLabel("Open download folder")
            }
            .padding(.bottom, 6)
            if model.history.isEmpty {
                Text("Completed files will appear here.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 18)
            } else if recent.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No recent files available")
                        .font(.system(size: 12, weight: .medium))
                    Text("\(missingCount) saved \(missingCount == 1 ? "entry points" : "entries point") to files that were moved or removed. Review them in Library.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                .padding(.vertical, 8)
            } else {
                ForEach(recent) { item in
                    recentFile(item)
                    if item.id != recent.last?.id {
                        Divider().padding(.leading, 46)
                    }
                }
            }
            Button(action: onOpenLibrary) {
                HStack {
                    Text("Show All Files")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .font(.system(size: 12, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.appAccent)
            .accessibilityLabel("Show All Files in Library")
        }
        .padding(.top, 20)
    }

    private func recentFile(_ item: DownloadItem) -> some View {
        let exists = FileManager.default.fileExists(atPath: item.filePath)
        return HStack(spacing: 8) {
            recentThumbnail(item).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(item.displayName)
                Text(exists ? item.sourceName : "File moved or removed")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button { model.copyFile(item) } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 13))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(!exists)
            .help("Copy file")
            .accessibilityLabel("Copy \(item.displayName)")
            Menu {
                Button { model.revealInFinder(item) } label: {
                    Label("Show in Finder", systemImage: "folder")
                }
                .disabled(!exists)
                Button { model.openSourceURL(item) } label: {
                    Label("Open Source", systemImage: "arrow.up.right.square")
                }
                Divider()
                Button(role: .destructive) {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                        model.deleteHistoryItem(item)
                    }
                } label: {
                    Label("Remove from History", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .foregroundStyle(.secondary)
            .help("More actions")
            .accessibilityLabel("More actions for \(item.displayName)")
        }
        .frame(height: 56)
        .contextMenu {
            Button("Copy File") { model.copyFile(item) }.disabled(!exists)
            Button("Show in Finder") { model.revealInFinder(item) }.disabled(!exists)
            Button("Open Source") { model.openSourceURL(item) }
            Divider()
            Button("Remove from History", role: .destructive) { model.deleteHistoryItem(item) }
        }
    }

    private func recentThumbnail(_ item: DownloadItem) -> some View {
        let image = item.thumbnailPath.flatMap { NSImage(contentsOfFile: $0) }
            ?? (item.isImageFile ? NSImage(contentsOfFile: item.filePath) : nil)
        return ZStack {
            RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05))
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 38, height: 38)
            } else {
                Image(systemName: item.isZipFile ? "archivebox" : item.isImageFile ? "photo" : "film")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 38, height: 38)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Divider()
            HStack {
                Text("Completion notifications").font(.system(size: 12))
                Spacer()
                Toggle("Completion notifications", isOn: Binding(
                    get: { model.notificationsEnabled },
                    set: model.setNotifications
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
            }
            HStack {
                Text(model.isBusy ? "Working in the background" : "Files stay on your Mac")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.borderless)
                    .font(.system(size: 11))
                    .disabled(model.isBusy)
                    .help(model.isBusy ? "Wait for the current task to finish before quitting" : "Quit Download It")
            }
        }
        .padding(.top, 8)
    }

    private func copyErrorDetails() {
        guard let activity = model.activity else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(activity.detail, forType: .string)
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

private struct ActivitySurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
    }
}

private extension View {
    func activitySurface() -> some View { modifier(ActivitySurface()) }
}
