import AppKit
import SwiftUI

/// Swipe reveals an explicit action; it never deletes a file from disk.
struct SwipeToRemoveRow<Content: View>: View {
    let id: UUID
    @Binding var revealedID: UUID?
    let onRemove: () -> Void
    @ViewBuilder let content: () -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset: CGFloat = 0
    @State private var dragOrigin: CGFloat?
    private let actionWidth: CGFloat = 76

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(role: .destructive, action: onRemove) {
                VStack(spacing: 3) {
                    Image(systemName: "trash")
                    Text("Remove").font(.caption2)
                }
                .foregroundStyle(.white)
                .frame(width: actionWidth - 6, height: 46)
                .background(Color.red, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .opacity(offset < -8 ? 1 : 0)
            .allowsHitTesting(offset < -8)
            .accessibilityHidden(offset >= -8)
            .help("Remove from history. The file stays on your Mac.")
            content()
                .frame(maxWidth: .infinity, minHeight: 46)
                .offset(x: offset)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        if dragOrigin == nil { dragOrigin = offset; revealedID = id }
                        offset = bounded((dragOrigin ?? 0) + value.translation.width)
                    }
                    .onEnded { _ in settle() })
        }
        .frame(height: 46)
        .clipped()
        .background(HorizontalScrollCapture(onDelta: { delta in
            revealedID = id
            offset = bounded(offset + delta)
        }, onEnd: settle))
        .contextMenu { Button("Remove from History", role: .destructive, action: onRemove) }
        .accessibilityAction(named: Text("Remove from History"), onRemove)
        .onChange(of: revealedID) { _, value in
            if value != id { animate { offset = 0; dragOrigin = nil } }
        }
    }

    private func bounded(_ value: CGFloat) -> CGFloat { min(0, max(-actionWidth, value)) }
    private func settle() {
        let reveal = offset < -actionWidth / 3
        animate { offset = reveal ? -actionWidth : 0; dragOrigin = nil }
        revealedID = reveal ? id : nil
    }
    private func animate(_ action: () -> Void) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.86), action)
    }
}

/// SwiftUI drag gestures cover a mouse; native scroll events cover two-finger trackpad swipes.
private struct HorizontalScrollCapture: NSViewRepresentable {
    let onDelta: (CGFloat) -> Void
    let onEnd: () -> Void
    func makeNSView(context: Context) -> ScrollView { ScrollView() }
    func updateNSView(_ view: ScrollView, context: Context) {
        view.onDelta = onDelta
        view.onEnd = onEnd
    }
    static func dismantleNSView(_ view: ScrollView, coordinator: ()) { view.stop() }

    final class ScrollView: NSView {
        var onDelta: ((CGFloat) -> Void)?
        var onEnd: (() -> Void)?
        private var monitor: Any?
        private var tracking = false
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stop()
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, event.window === self.window else { return event }
                let inside = self.bounds.contains(self.convert(event.locationInWindow, from: nil))
                if self.tracking && (event.phase.contains(.ended) || event.phase.contains(.cancelled)) {
                    self.tracking = false
                    self.onEnd?()
                    return nil
                }
                guard inside, event.momentumPhase.isEmpty,
                      abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) else { return event }
                self.tracking = true
                self.onDelta?(event.scrollingDeltaX)
                if event.phase.isEmpty { self.tracking = false; self.onEnd?() }
                return nil
            }
        }
        func stop() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            tracking = false
        }
        deinit { if let monitor { NSEvent.removeMonitor(monitor) } }
    }
}
