import AppKit
import ImageIO

actor PreviewDecoder {
    func image(_ url: URL) -> CGImage? {
        guard !Task.isCancelled else { return nil }
        guard let source = CGImageSourceCreateWithURL(url as CFURL,
            [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 160,
            kCGImageSourceCreateThumbnailWithTransform: true
        ] as CFDictionary)
    }
}

@MainActor
private final class ShelfTile: NSView {
    let item: ShelfItem
    weak var shelf: FileDragView?
    var preview: NSImage? { didSet { needsDisplay = true } }
    override var isFlipped: Bool { true }

    init(item: ShelfItem, shelf: FileDragView, frame: NSRect) {
        self.item = item
        self.shelf = shelf
        super.init(frame: frame)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(item.url.lastPathComponent)
        toolTip = item.url.lastPathComponent
    }
    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        let selected = shelf?.store.selection.contains(item.id) == true
        (selected ? NSColor.selectedContentBackgroundColor : .controlBackgroundColor).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 7, yRadius: 7).fill()
        let image = preview ?? NSImage(systemSymbolName: item.screenshotDate == nil ? "doc.fill" : "photo",
                                     accessibilityDescription: nil)
        image?.draw(in: NSRect(x: 8, y: 6, width: bounds.width - 16, height: bounds.height - 29),
                    from: .zero, operation: .sourceOver, fraction: 1,
                    respectFlipped: true, hints: nil)
        let suffix = item.availability == .unavailable ? " ⚠" :
            (item.availability == .checking ? " …" : "")
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingMiddle
        (item.url.lastPathComponent + suffix as NSString).draw(
            in: NSRect(x: 6, y: bounds.height - 21, width: bounds.width - 12, height: 18),
            withAttributes: [.font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: selected ? NSColor.white : .labelColor,
                .paragraphStyle: paragraph])
    }

    override func mouseDown(with event: NSEvent) { shelf?.select(item, event: event) }
    override func mouseDragged(with event: NSEvent) { shelf?.startDrag(event) }
    override func mouseUp(with event: NSEvent) { shelf?.endPress() }
    override func accessibilityPerformPress() -> Bool {
        shelf?.store.selection = [item.id]
        shelf?.reload()
        return true
    }
    override func scrollWheel(with event: NSEvent) { shelf?.scrollWheel(with: event) }
}

@MainActor
final class FileDragView: NSView, NSDraggingSource {
    let store = ShelfStore()
    var toggle: (() -> Void)?
    var sizeChanged: (() -> Void)?
    var expanded = false {
        didSet {
            store.prune()
            if expanded { store.refresh(Set(store.items.map(\.id))) }
            reload()
        }
    }
    var preferredHeight: CGFloat { max(400, 375 + CGFloat((store.screenshots.count + 2) / 3) * 67) }
    private var dragSnapshot: [ShelfItem] = []
    private var downPoint: NSPoint?
    private var longPressTask: Task<Void, Never>?
    private var feedbackTask: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?
    private var multiSelect = false
    private var offset = 0
    private var hover = false
    private var accepted = false
    private var monitor: ScreenshotMonitor?
    private var monitorToken = UUID()
    private var monitoring = false
    private var screenshotStatus = "Choose your screenshot save folder to start"
    private var message = "Drop files here"
    private let decoder = PreviewDecoder()
    private var cache: [URL: NSImage] = [:]
    private var cacheOrder: [URL] = []
    private var lastChecking: Set<UUID> = []
    private let folderButton = NSButton(title: "Choose screenshot folder…", target: nil, action: nil)
    private let removeButton = NSButton(title: "Remove selected", target: nil, action: nil)
    private let clearButton = NSButton(title: "Clear all", target: nil, action: nil)
    private let closeButton = NSButton(title: "×", target: nil, action: nil)
    private let stopButton = NSButton(title: "Stop", target: nil, action: nil)
    private let retryButton = NSButton(title: "Retry", target: nil, action: nil)
    private var wakeObserver: NSObjectProtocol?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
        setAccessibilityLabel("DropShelf")
        for (button, action) in [(folderButton, #selector(chooseFolder)),
            (removeButton, #selector(removeSelected)), (clearButton, #selector(clearAll)),
            (closeButton, #selector(closeShelf)), (stopButton, #selector(stopMonitoring)),
            (retryButton, #selector(retry))] {
            button.target = self
            button.action = action
            button.bezelStyle = .rounded
            button.font = .systemFont(ofSize: 11)
        }
        closeButton.setAccessibilityLabel("Close shelf")
        clearButton.toolTip = "Remove all shelf references. Original files stay untouched."
        removeButton.toolTip = "Remove selected references, not the original files."
        store.changed = { [weak self] in
            guard let self else { return }
            let checking = Set(self.store.items.filter { $0.availability == .checking }.map(\.id))
            let newlyAvailable = self.store.items.contains {
                self.lastChecking.contains($0.id) && $0.availability == .available
            }
            self.lastChecking = checking
            if newlyAvailable {
                self.accepted = true
                self.feedbackTask?.cancel()
                self.feedbackTask = Task { @MainActor [weak self] in
                    do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
                    self?.accepted = false
                    self?.needsDisplay = true
                }
            }
            self.reload()
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor [weak self] in
            self?.store.prune()
            self?.monitor?.reconcile()
        }}
        reload()
    }
    required init?(coder: NSCoder) { nil }

    static func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
        (pasteboard.readObjects(forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []).filter(\.isFileURL)
    }

    func reload() {
        previewTask?.cancel()
        subviews.forEach { $0.removeFromSuperview() }
        offset = min(offset, max(0, store.manualItems.count - 4))
        if expanded {
            for button in [folderButton, removeButton, clearButton, closeButton, stopButton, retryButton] {
                addSubview(button)
            }
            closeButton.frame = NSRect(x: 278, y: 10, width: 26, height: 24)
            clearButton.frame = NSRect(x: 205, y: 10, width: 68, height: 24)
            removeButton.frame = NSRect(x: 14, y: 218, width: 128, height: 24)
            removeButton.isEnabled = !store.selection.isEmpty
            retryButton.frame = NSRect(x: 146, y: 218, width: 55, height: 24)
            folderButton.frame = NSRect(x: 12, y: preferredHeight - 40, width: 238, height: 26)
            stopButton.frame = NSRect(x: 254, y: preferredHeight - 40, width: 52, height: 26)
            stopButton.isEnabled = monitoring
            var tiles: [ShelfTile] = []
            for (index, item) in store.manualItems.dropFirst(offset).prefix(4).enumerated() {
                let tile = ShelfTile(item: item, shelf: self,
                    frame: NSRect(x: 14 + (index % 2) * 147, y: 76 + (index / 2) * 66,
                                  width: 139, height: 60))
                addSubview(tile)
                tiles.append(tile)
            }
            for (index, item) in store.screenshots.enumerated() {
                let tile = ShelfTile(item: item, shelf: self,
                    frame: NSRect(x: 14 + (index % 3) * 98, y: 275 + (index / 3) * 67,
                                  width: 90, height: 61))
                addSubview(tile)
                tiles.append(tile)
            }
            for tile in tiles { tile.preview = cache[tile.item.url] }
            previewTask = Task { @MainActor [weak self] in
                for tile in tiles {
                    guard let self, !Task.isCancelled else { return }
                    let url = tile.item.url
                    guard tile.preview == nil, tile.item.availability == .available,
                        ["png", "jpg", "jpeg", "heic", "tiff"].contains(url.pathExtension.lowercased()) else { continue }
                    let image = await self.decoder.image(url)
                    guard !Task.isCancelled else { return }
                    if let image {
                        let preview = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
                        self.cache[url] = preview
                        self.cacheOrder.removeAll { $0 == url }
                        self.cacheOrder.append(url)
                        while self.cacheOrder.count > 16 {
                            self.cache.removeValue(forKey: self.cacheOrder.removeFirst())
                        }
                        tile.preview = preview
                    }
                }
            }
        } else {
            cache.removeAll()
            cacheOrder.removeAll()
        }
        needsDisplay = true
        sizeChanged?()
    }

    override func draw(_ dirtyRect: NSRect) {
        (expanded ? NSColor.windowBackgroundColor : (hover ? .selectedControlColor : .systemBlue)).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: expanded ? 12 : 10, yRadius: expanded ? 12 : 10).fill()
        guard expanded else {
            text(accepted ? "✓" : (hover ? "↓" : "‹"), x: 9, y: 19, size: 17, color: .white)
            return
        }
        text("DropShelf", x: 14, y: 13, size: 17, bold: true)
        text("Manually added", x: 14, y: 48, size: 12, bold: true)
        text("\(store.manualItems.count)", x: 274, y: 48, size: 11, color: .secondaryLabelColor)
        if store.manualItems.isEmpty {
            text("Drop files here", x: 105, y: 116, size: 12, color: .secondaryLabelColor)
        }
        text("Recent screenshots", x: 14, y: 251, size: 12, bold: true)
        text("\(store.screenshots.count)/10", x: 267, y: 251, size: 11, color: .secondaryLabelColor)
        if store.screenshots.isEmpty {
            text(monitoring ? "Waiting for a new saved screenshot" : "Automatic collection is off",
                 x: 14, y: 278, size: 11, color: .secondaryLabelColor)
        }
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        (screenshotStatus as NSString).draw(
            in: NSRect(x: 14, y: preferredHeight - 88, width: 292, height: 16),
            withAttributes: [.font: NSFont.systemFont(ofSize: 10),
                .foregroundColor: NSColor.secondaryLabelColor, .paragraphStyle: paragraph])
        text("\(store.selection.count) selected · screenshots expire after 1 hour",
             x: 14, y: preferredHeight - 68, size: 10, color: .secondaryLabelColor)
        toolTip = message + "\n" + screenshotStatus
    }

    private func text(_ value: String, x: CGFloat, y: CGFloat, size: CGFloat,
                      bold: Bool = false, color: NSColor = .labelColor) {
        (value as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [
            .font: bold ? NSFont.boldSystemFont(ofSize: size) : .systemFont(ofSize: size),
            .foregroundColor: color])
    }

    @objc private func chooseFolder() {
        let picker = NSOpenPanel()
        picker.canChooseFiles = false
        picker.canChooseDirectories = true
        picker.allowsMultipleSelection = false
        picker.prompt = "Watch screenshots"
        picker.message = "Select the folder where macOS saves screenshots. Only new screenshots are collected."
        picker.begin { [weak self] response in
            Task { @MainActor [weak self] in
                guard response == .OK, let url = picker.url, let self else { return }
                self.monitor?.stop()
                let token = UUID()
                self.monitorToken = token
                self.monitoring = true
                self.folderButton.title = "Folder: " + url.lastPathComponent
                self.monitor = ScreenshotMonitor(folder: url) { [weak self] candidates, status in
                    Task { @MainActor [weak self] in
                        guard let self, self.monitorToken == token else { return }
                        for candidate in candidates {
                            self.store.addScreenshot(candidate.url, capturedAt: candidate.capturedAt)
                        }
                        if let status {
                            self.screenshotStatus = status
                            if status.hasPrefix("Cannot") || status.contains("unavailable") || status.contains("exceeds") {
                                self.monitoring = false
                                self.monitor?.stop()
                                self.monitor = nil
                            }
                        }
                        self.reload()
                    }
                }
                self.reload()
            }
        }
    }

    @objc private func stopMonitoring() {
        monitorToken = UUID()
        monitor?.stop()
        monitor = nil
        monitoring = false
        folderButton.title = "Choose screenshot folder…"
        screenshotStatus = "Automatic collection stopped"
        reload()
    }
    @objc private func removeSelected() { store.remove(store.selection) }
    @objc private func clearAll() { store.remove(Set(store.items.map(\.id))) }
    @objc private func closeShelf() { toggle?() }
    @objc private func retry() { store.refresh(store.selection) }

    func select(_ item: ShelfItem, event: NSEvent) {
        window?.makeFirstResponder(self)
        if event.modifierFlags.contains(.command) || multiSelect {
            if !store.selection.insert(item.id).inserted { store.selection.remove(item.id) }
        } else if !store.selection.contains(item.id) { store.selection = [item.id] }
        downPoint = convert(event.locationInWindow, from: nil)
        longPressTask?.cancel()
        longPressTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .milliseconds(700)) } catch { return }
            self?.multiSelect = true
        }
        // Do not replace the mouse-tracking source tile during a gesture.
        subviews.forEach { $0.needsDisplay = true }
        removeButton.isEnabled = !store.selection.isEmpty
        needsDisplay = true
    }

    func endPress() { downPoint = nil; longPressTask?.cancel() }
    override func mouseDown(with event: NSEvent) { if !expanded { toggle?() } }
    override func scrollWheel(with event: NSEvent) {
        offset = max(0, min(max(0, store.manualItems.count - 4),
                           offset + (event.scrollingDeltaY < 0 ? 2 : -2)))
        reload()
    }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 51 { removeSelected() }
        else if event.keyCode == 53 { multiSelect = false; store.selection.removeAll(); toggle?() }
        else if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "a" {
            store.selection = Set(store.items.map(\.id)); reload()
        } else { super.keyDown(with: event) }
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        hover = sender.draggingSourceOperationMask.contains(.copy) &&
            sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self],
                options: [.urlReadingFileURLsOnly: true])
        needsDisplay = true
        return hover ? .copy : []
    }
    override func draggingExited(_ sender: (any NSDraggingInfo)?) { hover = false; needsDisplay = true }
    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        hover = false
        guard sender.draggingSourceOperationMask.contains(.copy),
              store.register(Self.fileURLs(from: sender.draggingPasteboard)) else {
            message = "Cannot add files. Manual limit is 500."
            needsDisplay = true
            return false
        }
        return true
    }

    func startDrag(_ event: NSEvent) {
        guard let downPoint, dragSnapshot.isEmpty else { return }
        let point = convert(event.locationInWindow, from: nil)
        guard hypot(point.x - downPoint.x, point.y - downPoint.y) >= 4 else { return }
        endPress()
        guard let snapshot = store.snapshot() else {
            message = "Selection is checking or unavailable. Retry when ready."
            store.refresh(store.selection)
            return
        }
        dragSnapshot = snapshot
        let items = snapshot.map { reference in
            let item = NSDraggingItem(pasteboardWriter: reference.url as NSURL)
            let image = cache[reference.url] ?? NSImage(systemSymbolName: "doc", accessibilityDescription: nil)
                ?? NSImage(size: NSSize(width: 24, height: 24))
            item.setDraggingFrame(NSRect(origin: point, size: NSSize(width: 40, height: 32)), contents: image)
            return item
        }
        beginDraggingSession(with: items, event: event, source: self)
    }
    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .copy }
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint,
                         operation: NSDragOperation) {
        dragSnapshot.removeAll()
        message = operation.isEmpty ? "Drag cancelled · items retained" : "OS drag ended · items retained"
    }

    func shutdown() {
        stopMonitoring()
        feedbackTask?.cancel()
        previewTask?.cancel()
        longPressTask?.cancel()
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
        wakeObserver = nil
        store.shutdown()
    }
}
