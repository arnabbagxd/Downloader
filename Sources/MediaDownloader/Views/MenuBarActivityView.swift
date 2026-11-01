import AppKit
import SwiftUI

struct MenuBarActivityView: View {
    @ObservedObject var model: AppModel
    let onOpenApp: () -> Void
    let onSettings: () -> Void
    @State private var clipboardFeedback: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Download It", systemImage: "arrow.down.circle.fill")
                    .font(.headline)
                Spacer()
                Button(action: onSettings) { Image(systemName: "gearshape") }
                    .buttonStyle(.borderless)
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
                    .disabled(model.isBusy || !ToolManager.isReady)
                Spacer()
                Button("Open App", action: onOpenApp)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: [])
            }

            Divider()
            HStack {
                Text("RECENT FILES").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Button(action: model.revealDownloadFolder) { Image(systemName: "folder") }
                    .buttonStyle(.borderless).help("Open download folder")
                    .accessibilityLabel("Open download folder")
            }
            if model.history.isEmpty {
                Text("Your completed downloads will appear here.")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                ForEach(Array(model.history.prefix(3))) { item in
                    recentFile(item)
                }
            }
            Button("Open Library", action: model.showLibrary)
            Toggle("Completion notifications", isOn: Binding(get: { model.notificationsEnabled }, set: model.setNotifications))
                .toggleStyle(.checkbox).font(.caption)
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
        .background(Color(nsColor: .windowBackgroundColor))
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
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }

    private func recentFile(_ item: DownloadItem) -> some View {
        let exists = FileManager.default.fileExists(atPath: item.filePath)
        return HStack(spacing: 10) {
            Image(systemName: item.isZipFile ? "archivebox" : item.isImageFile ? "photo" : "film")
                .foregroundStyle(.secondary).frame(width: 20).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName).font(.callout).lineLimit(1).help(item.displayName)
                Text(exists ? item.sourceName : "File moved or removed")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button { model.copyFile(item) } label: { Image(systemName: "doc.on.doc") }
                .buttonStyle(.borderless).disabled(!exists)
                .help("Copy file").accessibilityLabel("Copy \(item.displayName)")
            Button { model.revealInFinder(item) } label: { Image(systemName: "folder") }
                .buttonStyle(.borderless).disabled(!exists)
                .help("Show in Finder").accessibilityLabel("Show \(item.displayName) in Finder")
        }
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
