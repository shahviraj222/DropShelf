# DropShelf

<img src="design/appicon.svg" width="80" height="80" alt="DropShelf app icon">

A native macOS shelf that keeps files and saved text within reach while you switch between apps. Drop files or folders onto the blue tab at the right edge, then drag them from the shelf into a supported destination.

DropShelf keeps **temporary references**, not copies of your files. Originals stay where they are, and the shelf starts empty after quitting. Text snippets are kept in memory for the current session.

## Download and install

**[Download DropShelf 1.0.3 for Apple Silicon — ZIP](https://github.com/shahviraj222/DropShelf/raw/refs/heads/main/downloads/DropShelf-1.0.3-arm64.zip)** · [SHA-256 checksum](downloads/DropShelf-1.0.3-arm64.zip.sha256)

Updated November 28, 2026: optimized Release build with the compact text shelf, Shift-click ranges, empty-space deselection, movable tab/header (0.4-second hold), faster saved-screenshot discovery and revised UI. [Build verification and provenance](verification/release-1.0.3.md). Earlier [text preview](downloads/DropShelf-1.0.2-text-preview-arm64.zip) and [1.0.2 Release](downloads/DropShelf-1.0.2-arm64.zip) downloads remain available.

Requires **macOS 27.2 or later on Apple Silicon**. This build does not support Intel Macs or older macOS versions.

1. Download and double-click the ZIP to extract **DropShelf.app**.
2. Drag the app into **Applications**, then open it.
3. Look for the blue tab on the right edge of the screen.

This is an early development build with ad hoc signing, **without Developer ID signing or notarization**. macOS may block it on another Mac. Building from source with your own signing configuration is an alternative. There is no DMG download.

## How to use it

![DropShelf: drop onto the blue tab, open the shelf, select items and drag them out](SelfDrop/DropShelf-Codex-Brief/design/shelf-wireframe.svg)

*The supplied SVG illustrates the intended interactions and feedback states. It is a concept reference, not a screenshot of the current build.*

1. **Stage files:** drag files or folders from Finder directly onto the collapsed blue tab, as shown on the left of the image. Finder **Copy → ⌘V** with the shelf focused also stages native file references (files take priority over clipboard text).
2. **Open the shelf:** click the tab. The panel opens inward from the right edge, as shown on the right.
3. **Select and drag:** press a tile and move while holding the mouse button to drag in one gesture; no release and second click is required. A click without movement selects the tile. Click the first tile, then **Shift-click** a later tile to select the inclusive range. Click empty space inside the shelf to deselect without removing items. Cmd-click toggles individual tiles; Command-Shift-click adds a range; long press enables multi-selection. Use the actual attachment area or folder, such as a ChatGPT composer or VS Code Explorer folder. Acceptance depends on the receiving app and drop zone.
4. **Collect screenshots:** Desktop is the default folder on startup. If macOS blocks access, click **Allow Desktop access…** and confirm Desktop in the folder picker. Use the folder button to choose another save location. Save a new screenshot after enabling collection. Collection responds to folder events after 50 ms and rechecks readiness after 150 ms, then uses bounded retries for delayed metadata. macOS must finish saving the file first; a floating screenshot thumbnail or clipboard-only screenshot is not yet a saved file. If nothing appears, confirm the watched folder matches the macOS screenshot save location and grant folder access when prompted. The newest 10 references appear separately and each expires after one hour. **Stop** disables collection. On restart, the app returns to Desktop; another folder must be selected again for that session.
5. **Save multiple text snippets:** copy a URL or text, open **Text → Save clipboard**, then repeat for other content. Select a compact tile and press **Copy**, then paste into another app with **⌘V**. With the shelf focused, **⌘V** saves and **⌘C** copies the selected text. Text drops are also accepted. Scroll to browse more tiles. The shelf shows four short previews at a time without growing; full text is preserved. Up to 50 entries, 64 KB of UTF-8 per entry; duplicates select the existing entry. Nothing is saved after quitting. Included in the 1.0.3 download above.
6. **Remove items:** use **Remove selected**, Delete, or **Clear all**. These remove file references or saved text, never original files. Clear all leaves monitoring enabled for future screenshots.
7. **App menu:** use **About DropShelf** for version details, **How to Use DropShelf** for the built-in guide, or **Show Shelf** (**Shift-Command-S**) to open the panel. Clicking the Dock icon also opens the shelf.
8. **Close the panel:** click the app icon/title header to return to the tab. Outgoing drags retain staged items.
9. **Move the shelf:** hold the collapsed tab or app icon/title header for 0.4 seconds, then drag to the desired position. Short clicks still open/close it. The chosen position lasts for the session, including opening/closing; restarting returns it to the right edge.

The 1.0.3 ZIP includes these November 28 changes. **Folder** and **Stop** sit below the title/selection summary; a separator leads into **Recent screenshots**, with **Remove selected** and **Retry** at the bottom. Multi-video upload into Google Drive in Chrome still needs a real integration check; typed multi-file payload verification alone does not prove upload acceptance.

Collection watches only the selected folder. It does not capture the screen, import old screenshots, intercept the clipboard, or materialize floating screenshot promises. Missing/delayed screenshot metadata can prevent automatic collection; manually dropping the saved file remains available.

## What it uses

| Technology | Purpose |
|---|---|
| Swift + AppKit | Native controls, app lifecycle, floating nonactivating NSPanel, pointer gestures |
| NSDraggingSession / NSDraggingItem / NSPasteboard | Typed file URLs, one payload per selected file, copy-only operations; explicit plain-text clipboard save/copy |
| Foundation | In-memory state/bookmarks, identity deduplication, background reference validation |
| Dispatch directory notifications + macOS metadata | Event-driven screenshot discovery without continuous polling |
| ImageIO | Downsampled previews, serial decoding and bounded cache |
| Swift Testing | Reference, store, screenshot queue and expiry checks |

No third-party runtime dependencies, server, networking, telemetry, database or persistent shelf history. Manual staging is capped at 500 references; screenshot-folder scans are nonrecursive and bounded to 4,096 entries.

## Build from source

1. Open `SelfDrop.xcodeproj` in Xcode. Project/schemes and the internal executable retain the original **SelfDrop** name.
2. Select **SelfDrop → My Mac** and press **Command-R**.
3. The project uses ad hoc signing, App Sandbox and user-selected read-only access. Configure your own signing for distribution.

Built with **Xcode 27.2 / macOS 27.2 SDK**, targeting **macOS 27.2**. The unused starter `ContentView.swift` is excluded from compilation; the app uses AppKit.

## Tests and current status

Select **SelfDropTests** and press **Command-U**. The hostless target compiles the production store through a relative symlink; preserve it when checking out the repository.

- Latest recorded app/Release builds passed and the packaged app passed deep/strict code-signature verification.
- **Twelve Swift Testing tests passed:** file capacity/deduplication, stale results, drag snapshots, missing files, screenshot FIFO/expiry, promotion/clearing, text preservation, bounds and removal, and anchored Shift-click range selection. A native snippet also verified exact clipboard round trip, four bounded previews and unchanged panel height. See [text verification](verification/text-shelf.md).
- A directory-event fixture check collected a new metadata-marked image and excluded an old file and unrelated PNG.
- The owner reported working VS Code, email and ChatGPT transfers in the earlier drag build. The redesigned UI and actual screenshot-capture path still need manual verification.

Full-screen Spaces, multiple displays, accessibility, permissions, other-Mac installation and the updated drag UI need further checking. The **100 MB Release memory budget and idle CPU targets are unvalidated**. See [verification reports](verification/), including [Shift-click](verification/shift-selection.md) and [screenshot responsiveness](verification/screenshot-responsiveness.md), for actual outcomes and pending gates.

## Code and agent guide

Start with [AGENTS.md](AGENTS.md) for the implementation map, engineering constraints, validation notes and handoff. The complete [original brief](SelfDrop/DropShelf-Codex-Brief/), [architecture](SelfDrop/DropShelf-Codex-Brief/docs/02-architecture.md), [implementation plan](SelfDrop/DropShelf-Codex-Brief/docs/07-implementation-plan.md) and [original SVG](SelfDrop/DropShelf-Codex-Brief/design/shelf-wireframe.svg) remain included.

The downloadable ZIP is tracked in [downloads/](downloads/). DMG creation was blocked by development-environment disk-image services; [failure notes](verification/dmg-packaging.md) and an experimental [script](scripts/create-dmg.sh) are retained. No working DMG is claimed.

The [owner-supplied icon SVG](design/appicon.svg) is preserved as source artwork. Native macOS icon exports are generated by `scripts/render-app-icon.swift`; the current app uses these assets in Finder, the Dock, About panel and shelf header.
