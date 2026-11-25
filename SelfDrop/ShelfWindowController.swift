import AppKit

@MainActor
final class ShelfPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class ShelfWindowController: NSWindowController {
    private let tab = FileDragView(frame: .zero)
    private(set) var expanded = false
    private var screenObserver: NSObjectProtocol?

    init() {
        let panel = ShelfPanel(contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        super.init(window: panel)
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

    func reposition() {
        guard let window, let screen = window.screen ?? NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        let size = NSSize(width: expanded ? 320 : 30, height: expanded ? min(tab.preferredHeight, visible.height) : 60)
        window.setFrame(NSRect(x: visible.maxX - size.width, y: visible.midY - size.height / 2,
                               width: size.width, height: size.height), display: true)
    }

    override func close() {
        tab.shutdown()
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        screenObserver = nil
        super.close()
    }
}
