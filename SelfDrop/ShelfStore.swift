import Foundation

enum ReferenceAvailability: Sendable { case checking, available, unavailable }

struct ReferenceResult: Sendable {
    let url: URL
    let bookmark: Data?
    let identity: Data?
    let available: Bool
}

enum ReferenceResolver {
    nonisolated static func resolve(_ url: URL, bookmark: Data?) -> ReferenceResult {
        var resolved = url
        if let bookmark {
            var stale = false
            if let value = try? URL(resolvingBookmarkData: bookmark,
                options: [.withoutUI, .withoutMounting], relativeTo: nil,
                bookmarkDataIsStale: &stale) { resolved = value }
        }
        // URLs cache metadata; discard it so deleted files cannot remain available.
        resolved.removeAllCachedResourceValues()
        do {
            let values = try resolved.resourceValues(forKeys: [.fileResourceIdentifierKey,
                .volumeIdentifierKey, .isReadableKey, .isDirectoryKey])
            var identity: Data?
            if let file = values.fileResourceIdentifier, let volume = values.volumeIdentifier {
                identity = try? NSKeyedArchiver.archivedData(withRootObject: [volume, file],
                                                            requiringSecureCoding: false)
            }
            let data = (try? resolved.bookmarkData(options: .minimalBookmark,
                includingResourceValuesForKeys: nil, relativeTo: nil)).flatMap {
                    $0.count <= 65_536 ? $0 : nil
                }
            return ReferenceResult(url: resolved, bookmark: data, identity: identity,
                                   available: values.isReadable == true)
        } catch {
            return ReferenceResult(url: url, bookmark: bookmark, identity: nil, available: false)
        }
    }
}

/// The owner of a scope remains alive while either shelf membership or a drag needs it.
final class ReferenceAccess {
    let url: URL
    private let accessing: Bool
    init(_ url: URL) {
        self.url = url
        accessing = url.startAccessingSecurityScopedResource()
    }
    deinit { if accessing { url.stopAccessingSecurityScopedResource() } }
}

struct ShelfItem: Identifiable {
    let id: UUID
    var url: URL
    var bookmark: Data?
    var identity: Data?
    var availability: ReferenceAvailability = .checking
    var checkedAt: Date?
    var generation = UUID()
    var screenshotDate: Date?
    let access: ReferenceAccess
}

struct TextClip: Identifiable {
    let id = UUID()
    let text: String

    var preview: String {
        String(text.prefix(80)).split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
}

enum TextRegistrationResult: Equatable {
    case added, duplicate, empty, tooLarge, full
}

@MainActor
final class ShelfStore {
    private(set) var items: [ShelfItem] = []
    private(set) var textClips: [TextClip] = []
    var selectedTextID: UUID?
    let textLimit = 50
    let textByteLimit = 65_536

    @discardableResult
    func registerText(_ text: String) -> TextRegistrationResult {
        guard !stopped else { return .full }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .empty }
        guard text.utf8.count <= textByteLimit else { return .tooLarge }
        if let existing = textClips.first(where: { $0.text == text }) {
            selectedTextID = existing.id
            changed?()
            return .duplicate
        }
        guard textClips.count < textLimit else { return .full }
        let clip = TextClip(text: text)
        textClips.insert(clip, at: 0)
        selectedTextID = clip.id
        changed?()
        return .added
    }

    var selectedText: TextClip? { textClips.first { $0.id == selectedTextID } }

    func removeSelectedText() {
        textClips.removeAll { $0.id == selectedTextID }
        selectedTextID = nil
        changed?()
    }

    func clear() {
        items.removeAll()
        queue.removeAll()
        selection.removeAll()
        selectionAnchor = nil
        textClips.removeAll()
        selectedTextID = nil
        scheduleExpiry()
        changed?()
    }
    private var selectionAnchor: UUID?
    var selection: Set<UUID> = []

    /// The Files section's visible order, including items reached by scrolling.
    func selectFile(_ id: UUID, extendingRange: Bool = false, toggling: Bool = false) {
        let ordered = (manualItems + screenshots).map(\.id)
        guard let target = ordered.firstIndex(of: id) else { return }
        if extendingRange, let anchor = selectionAnchor,
           let start = ordered.firstIndex(of: anchor) {
            let range = Set(ordered[min(start, target)...max(start, target)])
            selection = toggling ? selection.union(range) : range
        } else {
            if toggling {
                if !selection.insert(id).inserted { selection.remove(id) }
            } else if !selection.contains(id) {
                selection = [id]
            }
            selectionAnchor = id
        }
    }
    var changed: (() -> Void)?
    private var queue: [UUID] = []
    private var worker: Task<Void, Never>?
    private var stopped = false
    let limit = 500
    private let now: () -> Date
    private let schedulesExpiry: Bool
    private var expiryTask: Task<Void, Never>?

    init(now: @escaping () -> Date = Date.init, schedulesExpiry: Bool = true) {
        self.now = now
        self.schedulesExpiry = schedulesExpiry
    }

    var manualItems: [ShelfItem] { items.filter { $0.screenshotDate == nil } }
    var screenshots: [ShelfItem] {
        items.filter { $0.screenshotDate != nil }.sorted {
            ($0.screenshotDate ?? .distantPast) > ($1.screenshotDate ?? .distantPast)
        }
    }

    func addScreenshot(_ url: URL, capturedAt: Date) {
        prune()
        guard !stopped, url.isFileURL, capturedAt > now().addingTimeInterval(-3600),
              !items.contains(where: { $0.url.standardizedFileURL == url.standardizedFileURL }) else { return }
        var item = ShelfItem(id: UUID(), url: url, access: ReferenceAccess(url))
        item.screenshotDate = capturedAt
        items.append(item)
        queue.append(item.id)
        remove(Set(screenshots.dropFirst(10).map(\.id)))
        scheduleExpiry()
        changed?()
        startWorker()
    }

    func prune() {
        let expired = items.filter {
            guard let date = $0.screenshotDate else { return false }
            return now() >= date.addingTimeInterval(3600)
        }
        if !expired.isEmpty { remove(Set(expired.map(\.id))) }
        scheduleExpiry()
    }

    private func scheduleExpiry() {
        expiryTask?.cancel()
        guard schedulesExpiry, !stopped,
              let first = screenshots.compactMap(\.screenshotDate).min() else { return }
        let delay = max(0.01, first.addingTimeInterval(3600).timeIntervalSince(now()))
        expiryTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(delay)) } catch { return }
            self?.prune()
        }
    }

    @discardableResult
    func register(_ urls: [URL]) -> Bool {
        guard !stopped, !urls.isEmpty, urls.allSatisfy(\.isFileURL) else { return false }
        prune()
        let promotions = items.filter { item in
            item.screenshotDate != nil && urls.contains {
                $0.standardizedFileURL == item.url.standardizedFileURL
            }
        }
        var seen = Set(items.map { $0.url.standardizedFileURL })
        let unique = urls.filter { seen.insert($0.standardizedFileURL).inserted }
        guard manualItems.count + promotions.count + unique.count <= limit else { return false }
        let promotedIDs = Set(promotions.map(\.id))
        for index in items.indices where promotedIDs.contains(items[index].id) {
            items[index].screenshotDate = nil
        }
        scheduleExpiry()
        for url in unique {
            let item = ShelfItem(id: UUID(), url: url, access: ReferenceAccess(url))
            items.append(item)
            queue.append(item.id)
        }
        changed?()
        startWorker()
        return true
    }

    func refresh(_ ids: Set<UUID>) {
        for index in items.indices where ids.contains(items[index].id) {
            guard !queue.contains(items[index].id), items[index].availability != .checking else { continue }
            items[index].generation = UUID()
            items[index].availability = .checking
            queue.append(items[index].id)
        }
        changed?()
        startWorker()
    }

    private func startWorker() {
        guard worker == nil, !queue.isEmpty else { return }
        worker = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, !self.stopped, !self.queue.isEmpty else { break }
                let id = self.queue.removeFirst()
                guard let item = self.items.first(where: { $0.id == id }) else { continue }
                // One metadata operation at a time; no file bytes or directory traversal.
                let result = await Task.detached(priority: .utility) {
                    ReferenceResolver.resolve(item.url, bookmark: item.bookmark)
                }.value
                guard !Task.isCancelled, !self.stopped else { break }
                self.apply(result, id: id, generation: item.generation)
            }
            self?.worker = nil
        }
    }

    func apply(_ result: ReferenceResult, id: UUID, generation: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id && $0.generation == generation }) else { return }
        if let identity = result.identity,
           let duplicate = items.firstIndex(where: { $0.id != id && $0.identity == identity }) {
            // Explicit manual staging wins over automatic screenshot membership.
            if items[index].screenshotDate == nil { items[duplicate].screenshotDate = nil }
            remove([id])
            return
        }
        items[index].checkedAt = Date()
        items[index].url = result.url
        items[index].bookmark = result.bookmark
        items[index].identity = result.identity
        items[index].availability = result.available ? .available : .unavailable
        changed?()
    }

    func remove(_ ids: Set<UUID>) {
        items.removeAll { ids.contains($0.id) }
        queue.removeAll { ids.contains($0) }
        selection.subtract(ids)
        if let selectionAnchor, ids.contains(selectionAnchor) { self.selectionAnchor = nil }
        scheduleExpiry()
        changed?()
    }

    func snapshot() -> [ShelfItem]? {
        prune()
        let chosen = items.filter { selection.contains($0.id) }
        guard !chosen.isEmpty, chosen.allSatisfy({ $0.availability == .available && Date().timeIntervalSince($0.checkedAt ?? .distantPast) < 5 }) else { return nil }
        return chosen
    }

    func shutdown() {
        stopped = true
        textClips.removeAll()
        selectedTextID = nil
        expiryTask?.cancel()
        worker?.cancel()
        queue.removeAll()
        items.removeAll()
        selection.removeAll()
        selectionAnchor = nil
        changed = nil
    }
}
