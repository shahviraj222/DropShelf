# Milestones 0–1 feasibility report

Owner follow-up, 2026-11-24: owner reports functionality working and VS Code, email, and ChatGPT integration checked without problems. This supersedes pending status for those owner-performed integration checks and the earlier inability to launch from the agent environment. Exact app versions and byte-comparison observations were not supplied; no independent agent observation or performance measurement is implied. Full-screen/multiple-display coverage was not individually specified.

2026-11-24. macOS 27.2.1, arm64; active SelfDrop scheme, macOS 27.2 SDK/deployment target. Shell xcodebuild is unavailable because xcode-select points to CommandLineTools; builds use Xcode BuildProject. No third-party dependencies.

## Architecture and APIs

SelfDropApp is an AppKit entry point and delegate. ShelfWindowController owns one nonactivating NSPanel, anchored to its screen's visibleFrame right edge. It observes display configuration changes, falling back to a surviving screen; it does not follow pointer movement. canJoinAllSpaces plus canJoinAllApplications requests cross-app floating behavior. Apple's documentation describes eligibility, not universal full-screen overlay guarantees. No private APIs or global input monitoring.

FileDragView is deliberately a small milestone-1 harness, not the milestone-2 production store. It reads NSURL objects with urlReadingFileURLsOnly, registers session-only references, and balances successful security-scope starts at shutdown. It avoids synchronous filesystem checks and icon queries. Cmd-click selects multiple rows; dragging starts after four points of movement. Each selected URL creates one NSDraggingItem with NSURL as pasteboard writer. Copy-only mask; retained URL snapshot until terminal callback. No original contents read/copied/deleted, no upload success claim. The originating view remains alive.

Spike limitations: nine visible references, explicit whole-batch refusal above limit, URL-only deduplication, no rename resolution, unavailable-file validation, long press, removal, thumbnails, screenshot monitor, persistence, clipboard materialization or quick gestures. Registration means a typed reference was staged, not that the referenced bytes were verified readable. These limitations must be resolved at milestone 2 before product acceptance.

## Actual results

- Initial BuildProject failed: configured account login rejected and no Mac Development certificate. Changed target to Manual / Sign to Run Locally / empty development team. Sandbox and user-selected read-only access retained; no broad entitlements added. Distribution signing remains unresolved.
- Milestone 0 BuildProject passed (2.586 s).
- Milestone 1 first compile found an Int/CGFloat drawing-coordinate mismatch; corrected. BuildProject passed (3.158 s).
- RunCodeSnippet in FileDragView.swift passed assertions: two NSURL file URL objects round-trip with two typed pasteboard items; plain-text path rejected; panel is floating and nonactivating; collapsed/expanded widths 30/300 pt; right edge equals visibleFrame.maxX.
- GetTestList reports zero tests in existing scheme. Snippet assertions are runtime checks, not a Swift Testing suite or cross-app integration tests.
- Final BuildProject passed (3.587 s). Launch attempt via open on Xcode's Debug product failed with NSOSStatusErrorDomain -10827, kLSNoExecutableErr (executable missing). Full-app launch is unverified; runtime snippet execution is the only observed runtime result.
- Existing brief files were being copied as resources by the starter project's folder membership. Excluded Markdown and shelf-wireframe.svg from target build inputs; retained source brief in repository.
- Release physical-footprint, idle CPU, soak and transient peak measurements NOT RUN. No 100 MB compliance claim.

## Physical-Mac checks — all pending

Run SelfDrop in Xcode. Drop disposable files on the collapsed tab, click it to expand, Cmd-click rows and drag selected rows. Click header to collapse. Cmd-Q quits while shelf has keyboard focus; Dock Quit is also available.

| Check | Procedure and evidence required | Result |
|---|---|---|
| I01–I02 | Finder -> collapsed tab -> disposable Finder folder. Compare bytes using cmp or shasum; verify originals remain. Repeat with multiple files and a folder. | Pending |
| I03–I04 | One then five saved screenshots -> ChatGPT composer. Inspect actual attachment previews; compare direct Finder baseline. Do not send. | Pending |
| I05–I06 | Drop image onto VS Code Explorer folder; confirm physical file and byte equality. Drop folder onto supported target; compare Finder baseline. | Pending |
| I08 | Escape during drag and rejecting target; references retained and no success message. | Pending |
| I14 | Ordinary, maximized, green-button full-screen apps; switch Spaces and drag in each. Record app and OS behavior, focus theft and limitations. | Pending |
| I15 | Stage Manager, second display, disconnect and sleep/wake; verify placement and single-panel lifetime. | Pending |
| I13 | Quit/relaunch; empty shelf and unchanged originals. | Pending |

Milestones are implementation/build checkpoints only. Native manual gates remain open; do not proceed to elaborate UI or claim release acceptance from these checks.

## Repeatable runtime check

Run the following with Xcode RunCodeSnippet in FileDragView.swift:

```swift
let board = NSPasteboard.withUniqueName()
defer { board.releaseGlobally() }
let urls = [URL(fileURLWithPath: "/tmp/A.png"), URL(fileURLWithPath: "/tmp/B.pdf")]
assert(board.writeObjects(urls.map { $0 as NSURL }))
assert(FileDragView.fileURLs(from: board) == urls)
assert(board.pasteboardItems?.count == 2)
assert(board.pasteboardItems?.allSatisfy { $0.types.contains(.fileURL) } == true)
board.clearContents()
board.setString("/tmp/A.png", forType: .string)
assert(FileDragView.fileURLs(from: board).isEmpty)
let controller = ShelfWindowController()
defer { controller.close() }
assert(controller.window?.styleMask.contains(.nonactivatingPanel) == true)
assert(controller.window?.level == .floating)
assert(controller.window?.frame.width == 30)
controller.toggle()
assert(controller.window?.frame.width == 300)
if let window = controller.window, let screen = window.screen ?? NSScreen.main {
    assert(abs(window.frame.maxX - screen.visibleFrame.maxX) < 1)
}
print("PASS: typed payload, text rejection, panel geometry")
```
