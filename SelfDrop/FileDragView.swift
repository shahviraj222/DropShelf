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

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
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
    private var pendingDragEvent: NSEvent?
    private var pressedSelection: Set<UUID> = []
    private var longPressTask: Task<Void, Never>?
    private var feedbackTask: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?
    private var multiSelect = false
    private var offset = 0
    private var textOffset = 0
    private var textStatus = "Save clipboard · select a tile · Copy to paste later"
    private var showingText: Bool { sectionControl.selectedSegment == 1 }
    private let sectionControl = NSSegmentedControl(labels: ["Files", "Text"],
        trackingMode: .selectOne, target: nil, action: nil)
    private let saveTextButton = NSButton(title: "Save clipboard", target: nil, action: nil)
    private let copyTextButton = NSButton(title: "Copy", target: nil, action: nil)
    private var hover = false
    private var accepted = false
    private var monitor: ScreenshotMonitor?
    private var monitorToken = UUID()
    private var monitoring = false
    private var screenshotFolder: URL?
    static var defaultScreenshotFolder: URL? {
        FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
    }
    private var screenshotStatus = "Choose your screenshot save folder to start"
    private var message = "Drop files here"
    private let decoder = PreviewDecoder()
    private var cache: [URL: NSImage] = [:]
    private var cacheOrder: [URL] = []
    private var lastChecking: Set<UUID> = []
    private let folderButton = NSButton(title: "Choose screenshot folder…", target: nil, action: nil)
    private let removeButton = NSButton(title: "Remove selected", target: nil, action: nil)
    private let clearButton = NSButton(title: "Clear all", target: nil, action: nil)
    private let headerButton = ShelfMoveHandle(title: "", target: nil, action: nil)
    private let stopButton = NSButton(title: "Stop", target: nil, action: nil)
    private let retryButton = NSButton(title: "Retry", target: nil, action: nil)
    private var wakeObserver: NSObjectProtocol?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL, .string, .URL])
        setAccessibilityLabel("DropShelf")
        for (button, action) in [(folderButton, #selector(chooseFolder)),
            (removeButton, #selector(removeSelected)), (clearButton, #selector(clearAll)),
            (headerButton, #selector(closeShelf)),
            (stopButton, #selector(stopMonitoring)),
            (retryButton, #selector(retry)), (saveTextButton, #selector(saveClipboard)),
            (copyTextButton, #selector(copySelectedText))] {
            button.target = self
            button.action = action
            button.bezelStyle = .rounded
            button.font = .systemFont(ofSize: 11)
        }
        sectionControl.target = self
        sectionControl.action = #selector(changeSection)
        sectionControl.selectedSegment = 0
        sectionControl.setAccessibilityLabel("Shelf content")
        headerButton.isTransparent = true
        headerButton.identifier = NSUserInterfaceItemIdentifier("collapseShelfHeader")
        headerButton.setAccessibilityLabel("Collapse DropShelf")
        headerButton.toolTip = "Click to collapse · hold 0.7 seconds to move"
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
            if self.downPoint != nil || !self.dragSnapshot.isEmpty {
                // Keep the clicked tile alive through validation and native drag tracking.
                self.subviews.forEach { $0.needsDisplay = true }
                self.needsDisplay = true
                self.resumePendingDrag()
            } else {
                self.reload()
            }
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor [weak self] in
            self?.store.prune()
            self?.monitor?.reconcile()
        }}
        if let desktop = Self.defaultScreenshotFolder {
            startMonitoring(desktop)
        } else {
            reload()
        }
    }
    required init?(coder: NSCoder) { nil }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        if !expanded { headerButton.frame = bounds }
    }

    static func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
        (pasteboard.readObjects(forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []).filter(\.isFileURL)
    }

    func reload() {
        guard downPoint == nil, dragSnapshot.isEmpty else {
            needsDisplay = true
            return
        }
        previewTask?.cancel()
        subviews.forEach { $0.removeFromSuperview() }
        offset = min(offset, max(0, store.manualItems.count - 4))
        textOffset = min(textOffset, max(0, store.textClips.count - 4))
        if expanded {
            for button in [folderButton, removeButton, clearButton, headerButton, stopButton, retryButton] {
                addSubview(button)
            }
            addSubview(sectionControl)
            sectionControl.frame = NSRect(x: 14, y: 44, width: 192, height: 24)
            retryButton.isHidden = showingText
            if showingText {
                addSubview(saveTextButton)
                addSubview(copyTextButton)
                copyTextButton.frame = NSRect(x: 146, y: 218, width: 55, height: 24)
                copyTextButton.isEnabled = store.selectedText != nil
                saveTextButton.frame = NSRect(x: 205, y: 218, width: 101, height: 24)
            }
            headerButton.frame = NSRect(x: 8, y: 6, width: 224, height: 34)
            clearButton.frame = NSRect(x: 236, y: 10, width: 68, height: 24)
            removeButton.frame = NSRect(x: 14, y: 218, width: 128, height: 24)
            removeButton.isEnabled = showingText ? store.selectedText != nil : !store.selection.isEmpty
            retryButton.frame = NSRect(x: 146, y: 218, width: 55, height: 24)
            folderButton.frame = NSRect(x: 12, y: preferredHeight - 40, width: 238, height: 26)
            stopButton.frame = NSRect(x: 254, y: preferredHeight - 40, width: 52, height: 26)
            stopButton.isEnabled = monitoring
            var tiles: [ShelfTile] = []
            if showingText {
                for (index, clip) in store.textClips.dropFirst(textOffset).prefix(4).enumerated() {
                    let tile = NSButton(title: clip.preview, target: self, action: #selector(selectText(_:)))
                    tile.identifier = NSUserInterfaceItemIdentifier(clip.id.uuidString)
                    tile.frame = NSRect(x: 14 + (index % 2) * 147, y: 76 + (index / 2) * 66,
                                        width: 139, height: 60)
                    tile.setButtonType(.pushOnPushOff)
                    tile.bezelStyle = .regularSquare
                    tile.state = store.selectedTextID == clip.id ? .on : .off
                    tile.font = .systemFont(ofSize: 11)
                    tile.lineBreakMode = .byTruncatingTail
                    tile.image = NSImage(systemSymbolName: "text.alignleft", accessibilityDescription: nil)
                    tile.imagePosition = .imageAbove
                    tile.setAccessibilityLabel("Saved text: " + clip.preview)
                    tile.toolTip = "Select, then Copy to paste in another app"
                    addSubview(tile)
                }
            } else {
                for (index, item) in store.manualItems.dropFirst(offset).prefix(4).enumerated() {
                    let tile = ShelfTile(item: item, shelf: self,
                        frame: NSRect(x: 14 + (index % 2) * 147, y: 76 + (index / 2) * 66,
                                      width: 139, height: 60))
                    addSubview(tile)
                    tiles.append(tile)
                }
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
            headerButton.frame = bounds
            headerButton.toolTip = "Click to open · hold 0.7 seconds to move"
            addSubview(headerButton)
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
        NSImage(named: NSImage.applicationIconName)?.draw(
            in: NSRect(x: 12, y: 9, width: 28, height: 28), from: .zero,
            operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        text("DropShelf", x: 45, y: 13, size: 17, bold: true)
        text(showingText ? "\(store.textClips.count)/50" : "\(store.manualItems.count)",
             x: 270, y: 48, size: 11, color: .secondaryLabelColor)
        if showingText ? store.textClips.isEmpty : store.manualItems.isEmpty {
            text(showingText ? "Save copied text here" : "Drop files here",
                 x: showingText ? 85 : 105, y: 116, size: 12, color: .secondaryLabelColor)
        }
        text("Recent screenshots", x: 14, y: 251, size: 12, bold: true)
        text("\(store.screenshots.count)/10", x: 267, y: 251, size: 11, color: .secondaryLabelColor)
        if store.screenshots.isEmpty {
            text(monitoring ? "Waiting for a new saved screenshot" : "Automatic collection is off",
                 x: 14, y: 278, size: 11, color: .secondaryLabelColor)
        }
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        ((showingText ? textStatus : screenshotStatus) as NSString).draw(
            in: NSRect(x: 14, y: preferredHeight - 88, width: 292, height: 16),
            withAttributes: [.font: NSFont.systemFont(ofSize: 10),
                .foregroundColor: NSColor.secondaryLabelColor, .paragraphStyle: paragraph])
        let selectionCount = showingText ? (store.selectedText == nil ? 0 : 1) : store.selection.count
        text("\(selectionCount) selected · screenshots expire after 1 hour",
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
        picker.directoryURL = screenshotFolder ?? Self.defaultScreenshotFolder
        picker.canChooseFiles = false
        picker.canChooseDirectories = true
        picker.allowsMultipleSelection = false
        picker.prompt = "Watch screenshots"
        picker.message = "Select the folder where macOS saves screenshots. Only new screenshots are collected."
        picker.begin { [weak self] response in
            Task { @MainActor [weak self] in
                guard response == .OK, let url = picker.url, let self else { return }
                self.startMonitoring(url)
            }
        }
    }

    private func startMonitoring(_ url: URL) {
        screenshotFolder = url
        screenshotStatus = "Starting screenshot collection in " + url.lastPathComponent
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
                        if status.hasPrefix("Cannot"),
                           url.standardizedFileURL == Self.defaultScreenshotFolder?.standardizedFileURL {
                            self.folderButton.title = "Allow Desktop access…"
                            self.screenshotStatus = "Select Desktop to grant access, or choose another folder"
                        }
                        self.monitor?.stop()
                        self.monitor = nil
                    }
                }
                self.reload()
            }
        }
        reload()
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
    @objc private func removeSelected() {
        if showingText { store.removeSelectedText() }
        else { store.remove(store.selection) }
    }
    @objc private func clearAll() { store.clear() }

    @objc private func changeSection() { reload() }

    @objc private func selectText(_ sender: NSButton) {
        guard let value = sender.identifier?.rawValue, let id = UUID(uuidString: value) else { return }
        store.selectedTextID = id
        window?.makeFirstResponder(self)
        reload()
    }

    @objc private func saveClipboard() { pasteClipboard(.general) }

    func pasteClipboard(_ pasteboard: NSPasteboard) {
        // Finder may also publish a textual filename; prefer the native file objects.
        let urls = Self.fileURLs(from: pasteboard)
        if !urls.isEmpty {
            sectionControl.selectedSegment = 0
            message = store.register(urls) ? "Files added" : "Cannot add files. Manual limit is 500."
            reload()
            return
        }
        guard let value = pasteboard.string(forType: .string)
            ?? pasteboard.string(forType: .URL) else {
            textStatus = "Clipboard has no plain text or URL"
            sectionControl.selectedSegment = 1
            reload()
            return
        }
        _ = saveText(value)
    }

    @discardableResult
    func saveText(_ value: String) -> Bool {
        sectionControl.selectedSegment = 1
        let result = store.registerText(value)
        switch result {
        case .added: textStatus = "Text saved · select a tile, then Copy"
        case .duplicate: textStatus = "Already saved · existing tile selected"
        case .empty: textStatus = "Nothing to save"
        case .tooLarge: textStatus = "Text is too large · maximum 64 KB per entry"
        case .full: textStatus = "Text shelf is full · remove entries first (50 maximum)"
        }
        textOffset = 0
        if result == .added || result == .duplicate {
            accepted = true
            feedbackTask?.cancel()
            feedbackTask = Task { @MainActor [weak self] in
                do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
                self?.accepted = false
                self?.needsDisplay = true
            }
        }
        reload()
        return result == .added || result == .duplicate
    }

    static func writeText(_ value: String, to pasteboard: NSPasteboard) -> Bool {
        pasteboard.clearContents()
        return pasteboard.setString(value, forType: .string)
    }

    @objc private func copySelectedText() {
        guard let clip = store.selectedText else { return }
        textStatus = Self.writeText(clip.text, to: .general)
            ? "Copied · paste into your destination with ⌘V"
            : "Could not write to the clipboard"
        needsDisplay = true
    }
    @objc private func closeShelf() { toggle?() }
    @objc private func retry() { store.refresh(store.selection) }

    func select(_ item: ShelfItem, event: NSEvent) {
        sectionControl.selectedSegment = 0
        store.selectedTextID = nil
        pendingDragEvent = nil
        window?.makeFirstResponder(self)
        if event.modifierFlags.contains(.command) || multiSelect {
            if !store.selection.insert(item.id).inserted { store.selection.remove(item.id) }
        } else if !store.selection.contains(item.id) { store.selection = [item.id] }
        pressedSelection = store.selection
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

    func endPress() {
        downPoint = nil
        pendingDragEvent = nil
        pressedSelection.removeAll()
        longPressTask?.cancel()
        reload()
    }
    override func mouseDown(with event: NSEvent) { if !expanded { toggle?() } }
    override func scrollWheel(with event: NSEvent) {
        if showingText {
            textOffset = max(0, min(max(0, store.textClips.count - 4),
                textOffset + (event.scrollingDeltaY < 0 ? 2 : -2)))
            reload()
            return
        }
        offset = max(0, min(max(0, store.manualItems.count - 4),
                           offset + (event.scrollingDeltaY < 0 ? 2 : -2)))
        reload()
    }
    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "v" {
            saveClipboard()
            return
        }
        if showingText, event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "c" {
            copySelectedText()
            return
        }
        if event.keyCode == 51 { removeSelected() }
        else if event.keyCode == 53 { multiSelect = false; store.selection.removeAll(); toggle?() }
        else if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "a" {
            if !showingText { store.selection = Set(store.items.map(\.id)); reload() }
        } else { super.keyDown(with: event) }
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        hover = sender.draggingSourceOperationMask.contains(.copy) &&
            (sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self],
                options: [.urlReadingFileURLsOnly: true]) ||
             sender.draggingPasteboard.availableType(from: [.string, .URL]) != nil)
        needsDisplay = true
        return hover ? .copy : []
    }
    override func draggingExited(_ sender: (any NSDraggingInfo)?) { hover = false; needsDisplay = true }
    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        hover = false
        guard sender.draggingSourceOperationMask.contains(.copy) else { return false }
        let urls = Self.fileURLs(from: sender.draggingPasteboard)
        if urls.isEmpty {
            guard let value = sender.draggingPasteboard.string(forType: .string)
                ?? sender.draggingPasteboard.string(forType: .URL) else { return false }
            return saveText(value)
        }
        guard store.register(urls) else {
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
        longPressTask?.cancel()
        let alreadyWaiting = pendingDragEvent != nil
        pendingDragEvent = event
        if let snapshot = store.snapshot(), store.selection == pressedSelection {
            beginPreparedDrag(snapshot, event: event)
        } else if !alreadyWaiting {
            message = "Checking selected files… keep holding to drag."
            store.refresh(store.selection)
        }
    }

    private func resumePendingDrag() {
        guard let event = pendingDragEvent, downPoint != nil, dragSnapshot.isEmpty else { return }
        guard NSEvent.pressedMouseButtons & 1 != 0 else {
            endPress()
            return
        }
        guard let snapshot = store.snapshot(), store.selection == pressedSelection else { return }
        beginPreparedDrag(snapshot, event: event)
    }

    // Keep the URL writer native: AppKit supplies file-transfer representations/access.
    static func fileWriter(for url: URL) -> NSURL { url as NSURL }

    private func beginPreparedDrag(_ snapshot: [ShelfItem], event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        pendingDragEvent = nil
        downPoint = nil
        longPressTask?.cancel()
        dragSnapshot = snapshot
        let items = snapshot.map { reference in
            let item = NSDraggingItem(pasteboardWriter: Self.fileWriter(for: reference.url))
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
        endPress()
        message = operation.isEmpty ? "Drag cancelled · items retained" : "OS drag ended · items retained"
    }

    func shutdown() {
        headerButton.cancelPress()
        stopMonitoring()
        feedbackTask?.cancel()
        previewTask?.cancel()
        longPressTask?.cancel()
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
        wakeObserver = nil
        store.shutdown()
    }
}
