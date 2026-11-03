import AppKit
import SwiftUI

struct PasteAwareTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onSubmit: () -> Void
    let onPaste: () -> Void
    /// Called instead of `onPaste` when the clipboard holds one or more local files
    /// (e.g. a PDF or image copied in Finder) rather than plain text. Returns whether
    /// any of the files were something this app knows how to handle.
    let onPasteFiles: ([URL]) -> Bool
    let onTab: () -> Void

    func makeNSView(context: Context) -> PastingTextField {
        let textField = PastingTextField()
        textField.delegate = context.coordinator
        textField.focusRingType = .none
        textField.isBordered = false
        textField.isBezeled = false
        textField.drawsBackground = false
        textField.setAccessibilityLabel("Media link")
        textField.isEditable = true
        textField.isSelectable = true
        textField.font = .systemFont(ofSize: 21, weight: .regular)
        textField.textColor = .labelColor
        textField.setAdaptivePlaceholder(placeholder)
        textField.lineBreakMode = .byTruncatingMiddle
        textField.usesSingleLineMode = true
        textField.onPaste = onPaste
        textField.onPasteFiles = onPasteFiles

        DispatchQueue.main.async {
            textField.window?.makeFirstResponder(textField)
        }

        return textField
    }

    func updateNSView(_ nsView: PastingTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }

        nsView.onPaste = onPaste
        nsView.onPasteFiles = onPasteFiles
        nsView.setAdaptivePlaceholder(placeholder)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit, onTab: onTab)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding private var text: String
        private let onSubmit: () -> Void
        private let onTab: () -> Void

        init(text: Binding<String>, onSubmit: @escaping () -> Void, onTab: @escaping () -> Void) {
            _text = text
            self.onSubmit = onSubmit
            self.onTab = onTab
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            text = textField.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                onSubmit()
                return true
            }

            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                return false
            }

            return false
        }
    }
}

final class PastingTextField: NSTextField {
    var onPaste: (() -> Void)?
    var onPasteFiles: (([URL]) -> Bool)?
    private var adaptivePlaceholder = ""

    override var acceptsFirstResponder: Bool {
        true
    }

    override var allowsVibrancy: Bool {
        true
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .iBeam)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            window.makeKey()
            window.makeFirstResponder(self)
        }
    }

    func setAdaptivePlaceholder(_ value: String) {
        adaptivePlaceholder = value
        placeholderAttributedString = NSAttributedString(
            string: value,
            attributes: [
                .foregroundColor: NSColor.labelColor.withAlphaComponent(0.62),
                .font: NSFont.systemFont(ofSize: 21, weight: .regular)
            ]
        )
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()

        if !adaptivePlaceholder.isEmpty {
            setAdaptivePlaceholder(adaptivePlaceholder)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let vKeyCode: UInt16 = 9
        let isPasteShortcut = event.modifierFlags.contains(.command)
            && event.keyCode == vKeyCode

        guard isPasteShortcut else {
            return super.performKeyEquivalent(with: event)
        }

        // A file copied in Finder (e.g. a PDF or image) has no plain-text representation
        // to paste into the field — hand it to the file-conversion flow instead of
        // silently doing nothing.
        let fileURLs = (NSPasteboard.general.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL]) ?? []

        if !fileURLs.isEmpty, onPasteFiles?(fileURLs) == true {
            return true
        }

        if let editor = currentEditor() {
            editor.paste(self)
        } else if let pastedText = NSPasteboard.general.string(forType: .string) {
            stringValue = pastedText
            delegate?.controlTextDidChange?(Notification(name: NSControl.textDidChangeNotification, object: self))
        }

        DispatchQueue.main.async { [weak self] in
            self?.onPaste?()
        }

        return true
    }
}
