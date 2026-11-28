import AppKit

@MainActor
final class ShelfPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// A short click keeps the existing action; a held press hands movement to Window Server.
@MainActor
final class ShelfMoveHandle: NSButton {
    private var holdTask: Task<Void, Never>?
    private var press: NSEvent?
    private var cancelledClick = false

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {
        cancelPress()
        press = event
        cancelledClick = false
        holdTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .milliseconds(700)) } catch { return }
            guard let self, let event = self.press, NSEvent.pressedMouseButtons & 1 != 0 else { return }
            // performDrag returns immediately and may consume mouse-up, so clear first.
            self.press = nil
            self.cancelledClick = true
            self.window?.performDrag(with: event)
        }
    }
    override func mouseDragged(with event: NSEvent) {
        guard let press else { return }
        if hypot(event.locationInWindow.x - press.locationInWindow.x,
                 event.locationInWindow.y - press.locationInWindow.y) > 4 {
            cancelledClick = true
            holdTask?.cancel()
        }
    }
    override func mouseUp(with event: NSEvent) {
        let click = press != nil && !cancelledClick && bounds.contains(convert(event.locationInWindow, from: nil))
        cancelPress()
        if click, let action { _ = sendAction(action, to: target) }
    }
    func cancelPress() {
        holdTask?.cancel()
        holdTask = nil
        press = nil
    }
}

@MainActor
final class ShelfWindowController: NSWindowController, NSWindowDelegate {
    private let tab = FileDragView(frame: .zero)
    private(set) var expanded = false
    private var screenObserver: NSObjectProtocol?
    private var userCenter: NSPoint?
    private var applyingLayout = false

    init() {
        let panel = ShelfPanel(contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        super.init(window: panel)
        panel.delegate = self
        panel.title = "DropShelf"
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications]
        panel.backgroundColor = .clear
        panel.contentView = tab
        tab.toggle = { [weak self] in self?.toggle() }
        tab.sizeChanged = { [weak self] in self?.reposition() }
        reposition()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.reposition() }
        }
    }

    required init?(coder: NSCoder) { nil }

    func openShelf() {
        if !expanded { toggle() }
        showWindow(nil)
    }

    @objc func toggle() {
        expanded.toggle()
        tab.expanded = expanded
        reposition()
    }

    static func fittedFrame(center: NSPoint, size: NSSize, visible: NSRect) -> NSRect {
        let size = NSSize(width: min(size.width, visible.width), height: min(size.height, visible.height))
        return NSRect(x: min(max(center.x - size.width / 2, visible.minX), visible.maxX - size.width),
                      y: min(max(center.y - size.height / 2, visible.minY), visible.maxY - size.height),
                      width: size.width, height: size.height)
    }

    func windowDidMove(_ notification: Notification) {
        guard !applyingLayout, let window else { return }
        userCenter = NSPoint(x: window.frame.midX, y: window.frame.midY)
    }

    func reposition() {
        guard let window else { return }
        let screen = userCenter.flatMap { center in
            NSScreen.screens.min { lhs, rhs in
                func distance(_ screen: NSScreen) -> CGFloat {
                    let rect = screen.visibleFrame
                    let dx = max(rect.minX - center.x, 0, center.x - rect.maxX)
                    let dy = max(rect.minY - center.y, 0, center.y - rect.maxY)
                    return dx * dx + dy * dy
                }
                return distance(lhs) < distance(rhs)
            }
        } ?? window.screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        let visible = screen.visibleFrame
        let size = NSSize(width: expanded ? 320 : 30, height: expanded ? tab.preferredHeight : 60)
        let center = userCenter ?? NSPoint(x: visible.maxX - 15, y: visible.midY)
        let frame = Self.fittedFrame(center: center, size: size, visible: visible)
        applyingLayout = true
        window.setFrame(frame, display: true)
        applyingLayout = false
        // Recover an off-screen anchor after display removal, without losing the user's
        // collapsed-tab position just because the expanded panel had to fit near an edge.
        if userCenter != nil {
            userCenter = NSPoint(x: min(max(center.x, visible.minX + 15), visible.maxX - 15),
                                 y: min(max(center.y, visible.minY + 30), visible.maxY - 30))
        }
    }

    override func close() {
        window?.delegate = nil
        tab.shutdown()
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        screenObserver = nil
        super.close()
    }
}
