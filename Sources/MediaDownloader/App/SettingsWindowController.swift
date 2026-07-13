import AppKit

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let preferences: PreferencesStore
    private let onCheckForUpdates: () -> Void

    init(preferences: PreferencesStore, onCheckForUpdates: @escaping () -> Void) {
        self.preferences = preferences
        self.onCheckForUpdates = onCheckForUpdates

        let contentSize = NSSize(width: 540, height: 430)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.minSize = contentSize
        window.maxSize = contentSize
        window.collectionBehavior = [.moveToActiveSpace]
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        super.init(window: window)

        window.delegate = self
        let viewController = NSViewController()
        viewController.view = SettingsRootView(
            frame: NSRect(origin: .zero, size: contentSize),
            preferences: preferences,
            onCheckForUpdates: onCheckForUpdates
        )
        window.contentViewController = viewController
    }

    required init?(coder: NSCoder) {
        nil
    }

    func show() {
        guard let window else { return }
        if !window.isVisible {
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        window?.makeFirstResponder(nil)
    }
}

private enum SettingsColors {
    static let cardFill = NSColor.white.withAlphaComponent(0.05)
    static let cardBorder = NSColor.white.withAlphaComponent(0.09)
    static let separator = NSColor.white.withAlphaComponent(0.07)
    static let controlFill = NSColor.white.withAlphaComponent(0.08)
    static let controlFillHover = NSColor.white.withAlphaComponent(0.14)
    static let controlBorder = NSColor.white.withAlphaComponent(0.11)
}

private final class SettingsRootView: NSView {
    private enum Metrics {
        static let leading: CGFloat = 28
        static let top: CGFloat = 46
    }

    init(frame: NSRect, preferences: PreferencesStore, onCheckForUpdates: @escaping () -> Void) {
        super.init(frame: frame)

        // Frosted background to match the rest of the app.
        let background = NSVisualEffectView()
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.translatesAutoresizingMaskIntoConstraints = false
        addSubview(background)

        let generalTitle = sectionTitle("General")
        let generalCard = GeneralSettingsCard(onCheckForUpdates: onCheckForUpdates)
        let shortcutsTitle = sectionTitle("Shortcuts")
        let shortcutsCard = ShortcutSettingsCard(preferences: preferences)

        [generalTitle, generalCard, shortcutsTitle, shortcutsCard].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: leadingAnchor),
            background.trailingAnchor.constraint(equalTo: trailingAnchor),
            background.topAnchor.constraint(equalTo: topAnchor),
            background.bottomAnchor.constraint(equalTo: bottomAnchor),

            generalTitle.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Metrics.leading + 2),
            generalTitle.topAnchor.constraint(equalTo: topAnchor, constant: Metrics.top),

            generalCard.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Metrics.leading),
            generalCard.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Metrics.leading),
            generalCard.topAnchor.constraint(equalTo: generalTitle.bottomAnchor, constant: 12),
            generalCard.heightAnchor.constraint(equalToConstant: 92),

            shortcutsTitle.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Metrics.leading + 2),
            shortcutsTitle.topAnchor.constraint(equalTo: generalCard.bottomAnchor, constant: 28),

            shortcutsCard.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Metrics.leading),
            shortcutsCard.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Metrics.leading),
            shortcutsCard.topAnchor.constraint(equalTo: shortcutsTitle.bottomAnchor, constant: 12),
            shortcutsCard.heightAnchor.constraint(equalToConstant: 150)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func sectionTitle(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title.uppercased())
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .tertiaryLabelColor
        // A touch of tracking makes the small-caps header feel intentional.
        label.attributedStringValue = NSAttributedString(
            string: title.uppercased(),
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: NSColor.tertiaryLabelColor,
                .kern: 0.6
            ]
        )
        return label
    }
}

private final class GeneralSettingsCard: NSView {
    private let onCheckForUpdates: () -> Void

    init(onCheckForUpdates: @escaping () -> Void) {
        self.onCheckForUpdates = onCheckForUpdates
        super.init(frame: .zero)
        setupCardLayer()

        let icon = NSImageView()
        icon.image = NSImage(named: NSImage.applicationIconName)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "Download It")
        title.font = .systemFont(ofSize: 16, weight: .semibold)
        title.textColor = .labelColor
        title.translatesAutoresizingMaskIntoConstraints = false

        let subtitle = NSTextField(labelWithString: "Version \(Self.versionText)")
        subtitle.font = .systemFont(ofSize: 12, weight: .regular)
        subtitle.textColor = .secondaryLabelColor
        subtitle.translatesAutoresizingMaskIntoConstraints = false

        let updateButton = SettingsButton(title: "Check for Updates", accent: true)
        updateButton.target = self
        updateButton.action = #selector(checkForUpdates)
        updateButton.translatesAutoresizingMaskIntoConstraints = false

        [icon, title, subtitle, updateButton].forEach(addSubview)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 54),
            icon.heightAnchor.constraint(equalToConstant: 54),

            title.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 15),
            title.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -10),

            subtitle.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 3),

            updateButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            updateButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            updateButton.heightAnchor.constraint(equalToConstant: 30)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    @objc private func checkForUpdates() {
        onCheckForUpdates()
    }

    private static var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let normalizedVersion = version?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let normalizedVersion, !normalizedVersion.isEmpty else {
            return "1.0.0"
        }

        return normalizedVersion.lowercased().hasPrefix("v")
            ? String(normalizedVersion.dropFirst())
            : normalizedVersion
    }
}

private final class ShortcutSettingsCard: NSView {
    init(preferences: PreferencesStore) {
        super.init(frame: .zero)
        setupCardLayer()

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        for (index, action) in HotKeyAction.allCases.enumerated() {
            stack.addArrangedSubview(ShortcutSettingsRow(
                action: action,
                shortcut: preferences.hotKeyShortcut(for: action),
                showsSeparator: index < HotKeyAction.allCases.count - 1,
                onRecord: { shortcut in
                    preferences.setHotKeyShortcut(shortcut, for: action)
                }
            ))
        }
    }

    required init?(coder: NSCoder) {
        nil
    }
}

private final class ShortcutSettingsRow: NSView {
    init(
        action: HotKeyAction,
        shortcut: HotKeyShortcut,
        showsSeparator: Bool,
        onRecord: @escaping (HotKeyShortcut) -> Void
    ) {
        super.init(frame: .zero)

        let title = NSTextField(labelWithString: action.title.replacingOccurrences(of: ":", with: ""))
        title.font = .systemFont(ofSize: 13, weight: .regular)
        title.textColor = .labelColor
        title.translatesAutoresizingMaskIntoConstraints = false

        let recorder = HotKeyRecorderButton(shortcut: shortcut, onRecord: onRecord)
        recorder.translatesAutoresizingMaskIntoConstraints = false

        addSubview(title)
        addSubview(recorder)

        var constraints: [NSLayoutConstraint] = [
            heightAnchor.constraint(equalToConstant: 50),
            title.leadingAnchor.constraint(equalTo: leadingAnchor),
            title.centerYAnchor.constraint(equalTo: centerYAnchor),

            recorder.trailingAnchor.constraint(equalTo: trailingAnchor),
            recorder.centerYAnchor.constraint(equalTo: centerYAnchor),
            recorder.widthAnchor.constraint(equalToConstant: 132),
            recorder.heightAnchor.constraint(equalToConstant: 28)
        ]

        if showsSeparator {
            let separator = NSView()
            separator.wantsLayer = true
            separator.layer?.backgroundColor = SettingsColors.separator.cgColor
            separator.translatesAutoresizingMaskIntoConstraints = false
            addSubview(separator)
            constraints.append(contentsOf: [
                separator.leadingAnchor.constraint(equalTo: leadingAnchor),
                separator.trailingAnchor.constraint(equalTo: trailingAnchor),
                separator.bottomAnchor.constraint(equalTo: bottomAnchor),
                separator.heightAnchor.constraint(equalToConstant: 1)
            ])
        }

        NSLayoutConstraint.activate(constraints)
    }

    required init?(coder: NSCoder) {
        nil
    }
}

/// A button that tracks hover so subclasses can react.
private class HoverButton: NSButton {
    private(set) var isHovered = false
    private var hoverTrackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea { removeTrackingArea(hoverTrackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        hoverChanged()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        hoverChanged()
    }

    func hoverChanged() {}
}

private final class SettingsButton: HoverButton {
    private let accent: Bool

    init(title: String, accent: Bool = false) {
        self.accent = accent
        super.init(frame: .zero)
        isBordered = false
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        focusRingType = .none
        setButtonType(.momentaryChange)
        contentTintColor = nil
        attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: accent ? NSColor.white : NSColor.labelColor.withAlphaComponent(0.9)
            ]
        )
        // Give the label a bit of horizontal breathing room.
        if let cell = cell as? NSButtonCell {
            cell.imagePosition = .noImage
        }
        widthAnchorPadding()
        hoverChanged()
    }

    required init?(coder: NSCoder) { nil }

    private func widthAnchorPadding() {
        // Size to fit the title plus padding.
        let width = (attributedTitle.size().width) + 34
        widthAnchor.constraint(equalToConstant: width).isActive = true
    }

    override func hoverChanged() {
        let fill: NSColor
        let border: NSColor
        if accent {
            fill = NSColor.appAccent.withAlphaComponent(isHovered ? 1.0 : 0.9)
            border = NSColor.appAccent.withAlphaComponent(isHovered ? 1.0 : 0.9)
        } else {
            fill = isHovered ? SettingsColors.controlFillHover : SettingsColors.controlFill
            border = SettingsColors.controlBorder
        }
        layer?.backgroundColor = fill.cgColor
        layer?.borderColor = border.cgColor
    }
}

private final class HotKeyRecorderButton: HoverButton {
    private var shortcut: HotKeyShortcut
    private let onRecord: (HotKeyShortcut) -> Void
    private var isRecordingShortcut = false
    private var keyMonitor: Any?
    private let shortcutLabel = NSTextField(labelWithString: "")
    private let closeImageView = NSImageView()

    init(shortcut: HotKeyShortcut, onRecord: @escaping (HotKeyShortcut) -> Void) {
        self.shortcut = shortcut
        self.onRecord = onRecord
        super.init(frame: .zero)
        title = ""
        attributedTitle = NSAttributedString(string: "")
        isBordered = false
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
        focusRingType = .none
        setButtonType(.momentaryChange)
        target = self
        action = #selector(startRecording)
        setupContent()
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        removeKeyMonitor()
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func hoverChanged() {
        updateAppearance()
    }

    private func setupContent() {
        shortcutLabel.alignment = .center
        shortcutLabel.translatesAutoresizingMaskIntoConstraints = false
        shortcutLabel.isEditable = false
        shortcutLabel.isSelectable = false
        shortcutLabel.backgroundColor = .clear

        closeImageView.image = LucideIconStore.menuImage("x", pointSize: 12)
        closeImageView.contentTintColor = NSColor.labelColor.withAlphaComponent(0.55)
        closeImageView.imageScaling = .scaleProportionallyDown
        closeImageView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(shortcutLabel)
        addSubview(closeImageView)

        NSLayoutConstraint.activate([
            shortcutLabel.centerXAnchor.constraint(equalTo: centerXAnchor, constant: -6),
            shortcutLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            shortcutLabel.widthAnchor.constraint(equalToConstant: 86),

            closeImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -9),
            closeImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeImageView.widthAnchor.constraint(equalToConstant: 12),
            closeImageView.heightAnchor.constraint(equalToConstant: 12)
        ])
    }

    @objc private func startRecording() {
        isRecordingShortcut = true
        updateAppearance()
        window?.makeFirstResponder(self)
        installKeyMonitor()
    }

    override func keyDown(with event: NSEvent) {
        guard isRecordingShortcut else {
            super.keyDown(with: event)
            return
        }

        capture(event)
    }

    private func capture(_ event: NSEvent) {
        if event.keyCode == 53 {
            stopRecording()
            return
        }

        guard !Self.modifierOnlyKeyCodes.contains(event.keyCode) else {
            return
        }

        shortcut = HotKeyShortcut(keyCode: event.keyCode, modifiers: event.modifierFlags)
        stopRecording()
        onRecord(shortcut)
    }

    private func updateAppearance() {
        let text = isRecordingShortcut ? "Recording…" : shortcut.displayText
        let font = NSFont.systemFont(ofSize: isRecordingShortcut ? 12 : 13, weight: .medium)
        let color = isRecordingShortcut
            ? NSColor.appAccent
            : NSColor.labelColor.withAlphaComponent(0.9)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        shortcutLabel.attributedStringValue = NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]
        )
        closeImageView.isHidden = isRecordingShortcut

        let fill: NSColor
        let border: NSColor
        if isRecordingShortcut {
            fill = NSColor.appAccent.withAlphaComponent(0.16)
            border = NSColor.appAccent.withAlphaComponent(0.5)
        } else {
            fill = isHovered ? SettingsColors.controlFillHover : SettingsColors.controlFill
            border = SettingsColors.controlBorder
        }
        layer?.backgroundColor = fill.cgColor
        layer?.borderColor = border.cgColor
        layer?.borderWidth = 1
    }

    private func stopRecording() {
        isRecordingShortcut = false
        removeKeyMonitor()
        updateAppearance()
    }

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, isRecordingShortcut else {
                return event
            }

            capture(event)
            return nil
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private static let modifierOnlyKeyCodes: Set<UInt16> = [
        54, 55, 56, 57, 58, 59, 60, 61, 62
    ]
}

private extension NSView {
    func setupCardLayer() {
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.masksToBounds = true
        layer?.backgroundColor = SettingsColors.cardFill.cgColor
        layer?.borderColor = SettingsColors.cardBorder.cgColor
        layer?.borderWidth = 1
    }
}
