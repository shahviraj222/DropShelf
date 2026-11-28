// Run with Xcode RunCodeSnippet in SelfDrop/SelfDrop/ScreenshotMonitor.swift.
actor Observations {
 var candidates: [ScreenshotCandidate] = []
 var baseline = false
 var arrivals: [URL: Date] = [:]
 func record(_ values: [ScreenshotCandidate], _ status: String?) {
  candidates += values
  for value in values { arrivals[value.url] = Date() }
  if status?.hasPrefix("Watching") == true { baseline = true }
 }
}
func markScreenshot(_ url: URL) throws {
 let data = try PropertyListSerialization.data(fromPropertyList: true, format: .binary, options: 0)
 let result = data.withUnsafeBytes { setxattr(url.path, "com.apple.metadata:kMDItemIsScreenCapture", $0.baseAddress, data.count, 0, 0) }
 assert(result == 0)
}
let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
defer { try? FileManager.default.removeItem(at: folder) }
let bytes = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a1mQAAAAASUVORK5CYII=") ?? Data([1])
let old = folder.appendingPathComponent("old.png")
try bytes.write(to: old)
try markScreenshot(old)
let observations = Observations()
let monitor = ScreenshotMonitor(folder: folder) { values, status in Task { await observations.record(values, status) } }
defer { monitor.stop() }
for _ in 0..<100 { if await observations.baseline { break }; try await Task.sleep(for: .milliseconds(20)) }
let baselined = await observations.baseline
assert(baselined)
let immediate = folder.appendingPathComponent("ready.png")
let delayed = folder.appendingPathComponent("delayed.png")
let unrelated = folder.appendingPathComponent("unrelated.png")
let transient = folder.appendingPathComponent("deleted-pending.png")
let start = Date()
try bytes.write(to: immediate); try markScreenshot(immediate)
try bytes.write(to: delayed)
try bytes.write(to: unrelated)
try bytes.write(to: transient)
for i in 0..<50 {
 if i == 5 { try FileManager.default.removeItem(at: transient) }
 try Data([1]).write(to: folder.appendingPathComponent("noise-\(i).txt"))
 try await Task.sleep(for: .milliseconds(20))
}
try markScreenshot(delayed)
for _ in 0..<200 { if await observations.candidates.count >= 2 { break }; try await Task.sleep(for: .milliseconds(20)) }
let accepted = await observations.candidates.map(\.url)
let arrivals = await observations.arrivals
assert(Set(accepted) == Set([immediate, delayed]))
assert(accepted.count == 2)
let latency = arrivals[immediate]?.timeIntervalSince(start) ?? 999
assert(latency < 0.8)
print("PASS: new marked PNG collected during directory activity in \(String(format: "%.3f", latency)) seconds; delayed metadata collected; old/unrelated ignored; no duplicates")
monitor.stop()
try await Task.sleep(for: .milliseconds(100))
let stopped = folder.appendingPathComponent("after-stop.png")
try bytes.write(to: stopped); try markScreenshot(stopped)
try await Task.sleep(for: .milliseconds(300))
let finalCount = await observations.candidates.count
assert(finalCount == 2)
print("PASS: Stop prevents subsequent collection")
