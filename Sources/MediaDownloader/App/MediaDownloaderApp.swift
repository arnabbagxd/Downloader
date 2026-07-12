import AppKit
import SwiftUI

@main
enum MediaDownloaderApp {
    private static var delegate: AppDelegate?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        Self.delegate = delegate
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private let preferences = PreferencesStore()
    private var window: SpotlightWindow?
    private var setupWindow: SpotlightWindow?
    private var setupModel: ToolSetupModel?
    private lazy var activationHotKey = GlobalHotKeyManager { [weak self] in
        self?.presentReadyWindow(activate: true)
    }
    private var hotKeyObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        activationHotKey.registerActivationHotKey(preferences.hotKeyShortcut(for: .activateApp))
        hotKeyObserver = NotificationCenter.default.addObserver(
            forName: .mediaDownloaderHotKeysDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard notification.object as? HotKeyAction == .activateApp else { return }

            Task { @MainActor [weak self] in
                self?.updateActivationHotKey()
            }
        }
        presentReadyWindow(activate: true)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        presentReadyWindow(activate: false)
    }

    func applicationDidResignActive(_ notification: Notification) {
        window?.orderOut(nil)
        setupWindow?.orderOut(nil)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        presentReadyWindow(activate: true)
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func presentReadyWindow(activate: Bool) {
        if ToolManager.isReady {
            setupWindow?.orderOut(nil)
            presentWindow(activate: activate)
        } else {
            window?.orderOut(nil)
            presentSetupWindow(activate: activate)
        }
    }

    private func presentWindow(activate: Bool) {
        let window = makeWindowIfNeeded()
        centerWindowOnCurrentDisplay(window)
        window.makeKeyAndOrderFront(nil)

        if activate {
            NSApp.activate(ignoringOtherApps: true)
        }

        model.checkForUpdates(manual: false)
        Task { await self.maybeUpdateYtDlp() }
    }

    private func presentSetupWindow(activate: Bool) {
        let window = makeSetupWindowIfNeeded()
        // Build the setup content once so re-showing the window can't restart the download.
        if setupModel == nil {
            window.contentView = makeSetupContentView()
        }
        centerWindowOnCurrentDisplay(window)
        window.makeKeyAndOrderFront(nil)

        if activate {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    /// Keeps the managed yt-dlp current, at most once per day, in the background.
    private func maybeUpdateYtDlp() async {
        let key = "lastYtDlpUpdateCheck"
        let now = Date()
        if let last = UserDefaults.standard.object(forKey: key) as? Date,
           now.timeIntervalSince(last) < 86_400 {
            return
        }
        UserDefaults.standard.set(now, forKey: key)
        await ToolManager.updateYtDlpIfManaged()
    }

    private func makeWindowIfNeeded() -> SpotlightWindow {
        if let window {
            return window
        }

        let windowSize = preferredWindowSize(for: currentDisplayVisibleFrame())

        let contentView = NSHostingView(
            rootView: ContentView(model: model)
                .frame(width: windowSize.width, height: windowSize.height)
                .tint(.appAccent)
        )

        let window = SpotlightWindow(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.contentView = contentView
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isMovableByWindowBackground = false
        window.level = .normal
        window.collectionBehavior = [.moveToActiveSpace]
        window.title = "Download It"
        centerWindowOnCurrentDisplay(window)

        self.window = window
        return window
    }

    private func makeSetupWindowIfNeeded() -> SpotlightWindow {
        if let setupWindow {
            return setupWindow
        }

        let window = SpotlightWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 360),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isMovableByWindowBackground = true
        window.level = .normal
        window.collectionBehavior = [.moveToActiveSpace]
        window.title = "Download It Setup"

        self.setupWindow = window
        return window
    }

    private func makeSetupContentView() -> NSView {
        let model = ToolSetupModel(onReady: { [weak self] in
            self?.presentReadyWindow(activate: true)
        })
        setupModel = model

        return NSHostingView(
            rootView: ToolSetupView(model: model)
                .frame(width: 520, height: 360)
                .tint(.appAccent)
        )
    }

    private func centerWindowOnCurrentDisplay(_ window: NSWindow) {
        let visibleFrame = currentDisplayVisibleFrame()
        let windowSize = window.frame.size
        window.setFrameOrigin(NSPoint(
            x: visibleFrame.midX - windowSize.width / 2,
            y: visibleFrame.midY - windowSize.height / 2
        ))
    }

    private func currentDisplayVisibleFrame() -> NSRect {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? NSScreen.main
        return screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 900, height: 1060)
    }

    private func preferredWindowSize(for visibleFrame: NSRect) -> NSSize {
        NSSize(
            width: min(860, max(760, visibleFrame.width - 32)),
            height: min(1060, max(760, visibleFrame.height - 24))
        )
    }

    private func updateActivationHotKey() {
        activationHotKey.registerActivationHotKey(preferences.hotKeyShortcut(for: .activateApp))
    }
}

final class SpotlightWindow: NSWindow {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, KeyboardEventRouter.shared.handle(event) {
            return
        }

        super.sendEvent(event)
    }
}
