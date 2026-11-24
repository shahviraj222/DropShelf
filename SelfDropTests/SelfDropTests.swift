import Foundation
import Testing

@MainActor
struct SelfDropTests {
    private func result(_ item: ShelfItem, available: Bool = true, identity: Data? = nil) -> ReferenceResult {
        ReferenceResult(url: item.url, bookmark: nil, identity: identity, available: available)
    }

    @Test func screenshotFIFOExpiryPromotionAndClear() throws {
        var now = Date(timeIntervalSince1970: 100_000)
        let store = ShelfStore(now: { now }, schedulesExpiry: false)
        defer { store.shutdown() }
        let manual = URL(fileURLWithPath: "/tmp/manual")
        store.register([manual])
        for index in 0..<1000 {
            store.addScreenshot(URL(fileURLWithPath: "/tmp/screenshot-\(index).png"),
                capturedAt: now.addingTimeInterval(Double(index) / 1000))
        }
        #expect(store.screenshots.count == 10)
        #expect(store.screenshots.first?.url.lastPathComponent == "screenshot-999.png")
        #expect(store.screenshots.last?.url.lastPathComponent == "screenshot-990.png")
        #expect(store.manualItems.count == 1)
        let promoted = try #require(store.screenshots.first)
        store.register([promoted.url])
        #expect(store.manualItems.count == 2)
        #expect(store.screenshots.count == 9)
        now = now.addingTimeInterval(3601)
        store.prune()
        #expect(store.screenshots.isEmpty)
        #expect(store.manualItems.count == 2)
        store.remove(Set(store.items.map(\.id)))
        #expect(store.items.isEmpty)
    }

    @Test func screenshotExpiryBoundaryAndDuplicateEvents() {
        var now = Date(timeIntervalSince1970: 100_000)
        let store = ShelfStore(now: { now }, schedulesExpiry: false)
        defer { store.shutdown() }
        let url = URL(fileURLWithPath: "/tmp/screenshot-boundary.png")
        store.addScreenshot(url, capturedAt: now)
        store.addScreenshot(url, capturedAt: now)
        #expect(store.screenshots.count == 1)
        now = now.addingTimeInterval(3599)
        store.prune()
        #expect(store.screenshots.count == 1)
        now = now.addingTimeInterval(1)
        store.prune()
        #expect(store.items.isEmpty)
    }

    @Test func duplicateURLsAndCapacityAreAtomic() {
        let store = ShelfStore()
        defer { store.shutdown() }
        let a = URL(fileURLWithPath: "/tmp/shelf-a")
        #expect(store.register([a, a]))
        #expect(store.items.count == 1)
        let excess = (0..<500).map { URL(fileURLWithPath: "/tmp/shelf-\($0)") }
        #expect(!store.register(excess))
        #expect(store.items.count == 1)
        #expect(!store.register([URL(string: "https://example.com")].compactMap { $0 }))
    }

    @Test func staleResultsCannotResurrectRemovedItems() throws {
        let store = ShelfStore()
        defer { store.shutdown() }
        store.register([URL(fileURLWithPath: "/tmp/removed")])
        let item = try #require(store.items.first)
        store.selection = [item.id]
        store.remove([item.id])
        store.apply(result(item), id: item.id, generation: item.generation)
        #expect(store.items.isEmpty)
        #expect(store.selection.isEmpty)
    }

    @Test func snapshotSurvivesMembershipRemovalAndRejectsUnavailableSubset() throws {
        let store = ShelfStore()
        defer { store.shutdown() }
        store.register([URL(fileURLWithPath: "/tmp/a"), URL(fileURLWithPath: "/tmp/b")])
        for item in store.items { store.apply(result(item), id: item.id, generation: item.generation) }
        store.selection = Set(store.items.map(\.id))
        let snapshot = try #require(store.snapshot())
        #expect(snapshot.count == 2)
        let first = try #require(store.items.first)
        store.apply(result(first, available: false), id: first.id, generation: first.generation)
        #expect(store.snapshot() == nil)
        store.remove(store.selection)
        #expect(snapshot.count == 2)
        #expect(snapshot.first?.url == URL(fileURLWithPath: "/tmp/a"))
    }

    @Test func realFileValidationDoesNotReadOrDeleteContents() async throws {
        let fixture = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let bytes = Data("DropShelf disposable fixture".utf8)
        try bytes.write(to: fixture)
        defer { try? FileManager.default.removeItem(at: fixture) }
        let resolved = await Task.detached { ReferenceResolver.resolve(fixture, bookmark: nil) }.value
        #expect(resolved.available)
        #expect(try Data(contentsOf: fixture) == bytes)
        try FileManager.default.removeItem(at: fixture)
        let missing = await Task.detached { ReferenceResolver.resolve(fixture, bookmark: nil) }.value
        #expect(!missing.available)
    }

    @Test func resourceIdentityDedupAndGenerationGuard() throws {
        let store = ShelfStore()
        defer { store.shutdown() }
        store.register([URL(fileURLWithPath: "/tmp/a"), URL(fileURLWithPath: "/tmp/b")])
        let initial = store.items
        for item in initial {
            store.apply(result(item, identity: Data([1, 2])), id: item.id, generation: item.generation)
        }
        #expect(store.items.count == 1)
        let remaining = try #require(store.items.first)
        store.apply(result(remaining, available: false), id: remaining.id, generation: UUID())
        #expect(store.items.first?.availability == .available)
        #expect(ShelfStore().items.isEmpty)
    }
}
