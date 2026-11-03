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
        }
        .frame(height: 46)
        .clipped()
        .background {
            GeometryReader { geometry in
                HorizontalScrollCapture(onDelta: { delta in
                    revealedID = id
                    offset = bounded(offset + delta)
                }, onEnd: settle)
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .contextMenu { Button("Remove from History", role: .destructive, action: onRemove) }
        .accessibilityAction(named: Text("Remove from History"), onRemove)
        .onChange(of: revealedID) { _, value in
            if value != id { animate { offset = 0 } }
        }
    }

    private func bounded(_ value: CGFloat) -> CGFloat { min(0, max(-actionWidth, value)) }
    private func settle() {
        let reveal = offset < -actionWidth / 3
        animate { offset = reveal ? -actionWidth : 0 }
        revealedID = reveal ? id : nil
    }
    private func animate(_ action: () -> Void) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.86), action)
    }
}

/// Handle horizontal input before SwiftUI context menus and popover dragging consume it.
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
        private var endTimer: Timer?
        private var tracking = false
        private var mouseOrigin: NSPoint?
        private var previousMouseX: CGFloat = 0
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stop()
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
                guard let self, event.window === self.window else { return event }
                let inside = self.bounds.contains(self.convert(event.locationInWindow, from: nil)); fflush(stdout)
                if event.type == .leftMouseDown {
                    self.mouseOrigin = inside ? event.locationInWindow : nil
                    self.previousMouseX = event.locationInWindow.x
                    return event
                }
                if event.type == .leftMouseDragged, let origin = self.mouseOrigin {
                    let point = event.locationInWindow
                    if !self.tracking {
                        guard abs(point.x - origin.x) > 8,
                              abs(point.x - origin.x) > abs(point.y - origin.y) else { return event }
                        self.tracking = true
                    }
                    self.onDelta?(point.x - self.previousMouseX)
                    self.previousMouseX = point.x
                    return nil
                }
                if event.type == .leftMouseUp {
                    self.mouseOrigin = nil
                    if self.tracking {
                        self.tracking = false
                        self.onEnd?()
                        return nil
                    }
                    return event
                }
                guard event.type == .scrollWheel else { return event }
                if self.tracking && (event.phase.contains(.ended) || event.phase.contains(.cancelled)) {
                    self.tracking = false
                    self.onEnd?()
                    return nil
                }
                guard inside, event.momentumPhase.isEmpty,
                      abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) else { return event }
                self.tracking = true
                self.onDelta?(event.scrollingDeltaX)
                self.endTimer?.invalidate()
                if event.phase.isEmpty {
                    // Mouse wheels and some trackpads send several small unphased events.
                    let timer = Timer(timeInterval: 0.15, repeats: false) { [weak self] _ in
                        MainActor.assumeIsolated {
                            self?.tracking = false
                            self?.onEnd?()
                        }
                    }
                    self.endTimer = timer
                    RunLoop.main.add(timer, forMode: .common)
                }
                return nil
            }
        }
        func stop() {
            endTimer?.invalidate()
            endTimer = nil
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            tracking = false
        }
        deinit { if let monitor { NSEvent.removeMonitor(monitor) } }
    }
}
