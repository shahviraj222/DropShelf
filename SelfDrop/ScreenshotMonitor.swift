import Foundation
import CoreServices
import Darwin

struct ScreenshotCandidate: Sendable {
    let url: URL
    let capturedAt: Date
}

/// Watches one selected directory, never recursively. All IO is on a serial utility queue.
nonisolated final class ScreenshotMonitor: @unchecked Sendable {
    private let queue = DispatchQueue(label: "DropShelf.screenshots", qos: .utility)
    private var source: (any DispatchSourceFileSystemObject)?
    private var scheduled: DispatchWorkItem?
    private var scheduledDeadline: DispatchTime?
    private var scheduleToken = UUID()
    private var nextAttempt: [URL: Date] = [:]
    private var known: Set<URL> = []
    private var pending: [URL: Int] = [:]
    private var sizes: [URL: Int] = [:]
    private var stopped = false
    private let folder: URL
    private let startedAt = Date()
    private let report: @Sendable ([ScreenshotCandidate], String?) -> Void
    private var scope = false

    init(folder: URL, report: @escaping @Sendable ([ScreenshotCandidate], String?) -> Void) {
        self.folder = folder
        self.report = report
        queue.async { [self] in start() }
    }

    private func start() {
        scope = folder.startAccessingSecurityScopedResource()
        let descriptor = open(folder.path, O_EVTONLY)
        guard descriptor >= 0 else {
            report([], "Cannot access screenshot folder. Choose it again.")
            if scope { folder.stopAccessingSecurityScopedResource(); scope = false }
            return
        }
        let watcher = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor,
            eventMask: [.write, .rename, .delete, .revoke], queue: queue)
        watcher.setCancelHandler { [folder, scope] in
            Darwin.close(descriptor)
            if scope { folder.stopAccessingSecurityScopedResource() }
        }
        watcher.setEventHandler { [weak self, weak watcher] in
            guard let self, let watcher else { return }
            if !watcher.data.intersection([.rename, .delete, .revoke]).isEmpty {
                self.report([], "Screenshot folder unavailable. Choose it again.")
                self.stopOnQueue()
            } else { self.schedule() }
        }
        source = watcher
        watcher.activate()
        scan(baseline: true)
    }

    private func schedule(after delay: TimeInterval = 0.05) {
        guard !stopped else { return }
        let deadline = DispatchTime.now() + max(0, delay)
        // Keep the earliest deadline: directory activity must not postpone discovery.
        if let scheduledDeadline, scheduledDeadline.uptimeNanoseconds <= deadline.uptimeNanoseconds { return }
        scheduled?.cancel()
        let token = UUID()
        scheduleToken = token
        scheduledDeadline = deadline
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.scheduleToken == token, !self.stopped else { return }
            self.scheduled = nil
            self.scheduledDeadline = nil
            self.scan(baseline: false)
        }
        scheduled = work
        queue.asyncAfter(deadline: deadline, execute: work)
    }

    private func scan(baseline: Bool) {
        guard !stopped else { return }
        guard let enumerator = FileManager.default.enumerator(at: folder,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants],
            errorHandler: { [report] _, _ in
                report([], "Cannot read screenshot folder.")
                return false
            }) else { report([], "Cannot read screenshot folder."); return }
        var current: Set<URL> = []
        var accepted: [ScreenshotCandidate] = []
        for case let url as URL in enumerator {
            guard current.count < 4096 else {
                report([], "Folder exceeds 4,096 entries. Choose a smaller screenshot folder.")
                stopOnQueue()
                return
            }
            current.insert(url)
            guard !known.contains(url) || pending[url] != nil else { continue }
            guard ["png", "jpg", "jpeg", "heic", "tiff"].contains(url.pathExtension.lowercased()) else { continue }
            if let due = nextAttempt[url], due > Date() { continue }
            var freshURL = url
            freshURL.removeAllCachedResourceValues()
            let values = try? freshURL.resourceValues(forKeys: [.creationDateKey, .isRegularFileKey, .fileSizeKey])
            // Subscription precedes baseline. Creation time excludes old files and startup races.
            guard values?.isRegularFile == true, let created = values?.creationDate,
                  created >= startedAt else {
                // A vanished/unreadable candidate must not leave a past-due retry spinning.
                pending.removeValue(forKey: url)
                nextAttempt.removeValue(forKey: url)
                continue
            }
            guard pending.count < 64 || pending[url] != nil else {
                report([], "Screenshot burst limit reached; some files were not collected.")
                continue
            }
            let size = values?.fileSize ?? 0
            let stable = sizes[url] == size && size > 0
            sizes[url] = size
            let item = MDItemCreate(kCFAllocatorDefault, url.path as CFString)
            let marker = item.flatMap { MDItemCopyAttribute($0, "kMDItemIsScreenCapture" as CFString) } as? Bool
            if (marker == true || Self.hasScreenshotAttribute(url)), stable {
                accepted.append(ScreenshotCandidate(url: url, capturedAt: created))
                pending.removeValue(forKey: url)
                nextAttempt.removeValue(forKey: url)
            } else {
                let attempt = (pending[url] ?? 0) + 1
                if attempt < 4 {
                    pending[url] = attempt
                    // Fast readiness recheck, then a bounded window for delayed metadata.
                    let delays: [TimeInterval] = [0.15, 0.75, 2.0]
                    nextAttempt[url] = Date().addingTimeInterval(delays[attempt - 1])
                } else {
                    pending.removeValue(forKey: url)
                    nextAttempt.removeValue(forKey: url)
                }
            }
        }
        known = current
        sizes = sizes.filter { pending[$0.key] != nil }
        pending = pending.filter { current.contains($0.key) }
        if !accepted.isEmpty { report(accepted.sorted { $0.capturedAt < $1.capturedAt }, nil) }
        nextAttempt = nextAttempt.filter { pending[$0.key] != nil }
        if let due = nextAttempt.values.min() { schedule(after: max(0, due.timeIntervalSinceNow)) }
        if baseline { report([], "Watching new screenshots · originals stay in your folder") }
    }

    private static func hasScreenshotAttribute(_ url: URL) -> Bool {
        let name = "com.apple.metadata:kMDItemIsScreenCapture"
        let size = getxattr(url.path, name, nil, 0, 0, 0)
        guard size > 0, size <= 1024 else { return false }
        var data = Data(count: size)
        let read = data.withUnsafeMutableBytes {
            getxattr(url.path, name, $0.baseAddress, size, 0, 0)
        }
        guard read == size,
              let value = try? PropertyListSerialization.propertyList(from: data, format: nil) else { return false }
        return (value as? Bool) == true || (value as? String) == "1"
    }

    func reconcile() { queue.async { [weak self] in self?.schedule() } }

    func stop() { queue.async { [weak self] in self?.stopOnQueue() } }

    private func stopOnQueue() {
        stopped = true
        scheduled?.cancel()
        scheduled = nil
        scheduledDeadline = nil
        scheduleToken = UUID()
        source?.cancel()
        source = nil
        pending.removeAll()
        nextAttempt.removeAll()
        sizes.removeAll()
        known.removeAll()
    }

    deinit {
        scheduled?.cancel()
        source?.cancel()
    }
}
