import AppKit
import Combine
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    private let model: AppModel
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var observation: AnyCancellable?
    var isShowingPopover: Bool { popover.isShown }

    init(model: AppModel, onOpenApp: @escaping () -> Void) {
        self.model = model
        super.init()
        popover.behavior = .transient
        popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        popover.contentViewController = NSHostingController(rootView: MenuBarActivityView(
            model: model,
            onOpenApp: { [weak self] in
                self?.popover.performClose(nil)
                onOpenApp()
            },
            onSettings: { [weak self] in
                self?.popover.performClose(nil)
                model.showSettings()
            },
            onOpenLibrary: { [weak self] in
                self?.popover.performClose(nil)
                // Let the popover relinquish its key window before presenting Library.
                DispatchQueue.main.async { model.showLibrary() }
            }
        ))
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover)
            button.imagePosition = .imageLeading
        }
        // Published values emit before mutation; refresh on the next main-loop turn.
        observation = model.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.refresh() }
        }
        refresh()
    }

    func showActivity() {
        if !popover.isShown { togglePopover() }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func refresh() {
        guard let button = statusItem.button else { return }
        let busy = model.isBusy || model.isRefiningResolutions
        let failed = !busy && model.activity?.state == .failed
        let symbol = failed ? "exclamationmark.circle" : busy ? "arrow.triangle.2.circlepath" : "arrow.down.circle"
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        button.image?.isTemplate = true
        var progressText = ""
        if let fraction = model.activityProgress, busy {
            button.image = Self.progressImage(fraction: fraction)
            if let playlist = model.playlistDownloadStatus {
                progressText = " \(playlist.completed)/\(playlist.total)"
            } else if let collection = model.collectionBundleStatus {
                progressText = " \(collection.completed)/\(collection.total)"
            } else {
                progressText = " \(Int(fraction * 100))%"
            }
        }
        button.title = progressText
        let detail = model.isProbing ? model.probingMessage : model.isRefiningResolutions ? "Checking exact qualities…" : model.activityDetail
        button.toolTip = "Download It — \(detail)"
        button.setAccessibilityLabel("Download It. \(detail)\(progressText)")
    }

    private static func progressImage(fraction: Double) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            let rect = NSRect(x: 2, y: 2, width: 14, height: 14)
            NSColor.labelColor.withAlphaComponent(0.25).setStroke()
            let track = NSBezierPath(ovalIn: rect)
            track.lineWidth = 2
            track.stroke()
            NSColor.labelColor.setStroke()
            let arc = NSBezierPath()
            arc.lineWidth = 2
            arc.lineCapStyle = .round
            arc.appendArc(withCenter: NSPoint(x: 9, y: 9), radius: 7,
                          startAngle: 90, endAngle: 90 - CGFloat(min(max(fraction, 0), 1)) * 360,
                          clockwise: true)
            arc.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }
}
