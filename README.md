# DropShelf

<img src="design/appicon.svg" width="80" height="80" alt="DropShelf app icon">

A native macOS shelf that keeps files within reach while you switch between apps. Drop files or folders onto the blue tab at the right edge, then drag them from the shelf into a supported destination.

DropShelf keeps **temporary references**, not copies of your files. Originals stay where they are, and the shelf starts empty after quitting.

## Download and install

**[Download DropShelf 1.0.2 for Apple Silicon — ZIP](https://github.com/shahviraj222/DropShelf/raw/refs/heads/main/downloads/DropShelf-1.0.2-arm64.zip)** · [SHA-256 checksum](downloads/DropShelf-1.0.2-arm64.zip.sha256)

Requires **macOS 27.2 or later on Apple Silicon**. This build does not support Intel Macs or older macOS versions.

1. Download and double-click the ZIP to extract **DropShelf.app**.
2. Drag the app into **Applications**, then open it.
3. Look for the blue tab on the right edge of the screen.

This is an early development build with ad hoc signing, **without Developer ID signing or notarization**. macOS may block it on another Mac. Building from source with your own signing configuration is an alternative. There is no DMG download.

## How to use it

![DropShelf: drop onto the blue tab, open the shelf, select items and drag them out](SelfDrop/DropShelf-Codex-Brief/design/shelf-wireframe.svg)

*The supplied SVG illustrates the intended interactions and feedback states. It is a concept reference, not a screenshot of the current build.*

1. **Stage files:** drag files or folders from Finder directly onto the collapsed blue tab, as shown on the left of the image.
2. **Open the shelf:** click the tab. The panel opens inward from the right edge, as shown on the right.
3. **Select and drag:** click a tile and drag it to a supported destination. Cmd-click selects multiple tiles; long press enables multi-selection. Use the actual attachment area or folder, such as a ChatGPT composer or VS Code Explorer folder. Acceptance depends on the receiving app and drop zone.
4. **Collect screenshots:** click **Choose screenshot folder…** and select the macOS screenshot save folder. Save a new screenshot after enabling collection. The newest 10 references appear separately and each expires after one hour. **Stop** disables collection. Choose the folder again after restarting the app.
5. **Remove items:** use **Remove selected**, Delete, or **Clear all**. These remove references only, never original files. Clear all leaves monitoring enabled for future screenshots.
6. **App menu:** use **About DropShelf** for version details, **How to Use DropShelf** for the built-in guide, or **Show Shelf** (**Shift-Command-S**) to open the panel. Clicking the Dock icon also opens the shelf.
7. **Close the panel:** click **×** to return to the tab. Outgoing drags retain staged items.

Collection watches only the selected folder. It does not capture the screen, import old screenshots, intercept the clipboard, or materialize floating screenshot promises. Missing/delayed screenshot metadata can prevent automatic collection; manually dropping the saved file remains available.

## What it uses

| Technology | Purpose |
|---|---|
| Swift + AppKit | Native controls, app lifecycle, floating nonactivating NSPanel, pointer gestures |
| NSDraggingSession / NSDraggingItem / NSPasteboard | Typed file URLs, one payload per selected file, copy-only operations |
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
- **Seven Swift Testing tests passed:** capacity/deduplication, stale results, drag snapshots, missing files, screenshot FIFO, expiry boundaries, promotion and clearing.
- A directory-event fixture check collected a new metadata-marked image and excluded an old file and unrelated PNG.
- The owner reported working VS Code, email and ChatGPT transfers in the earlier drag build. The redesigned UI and actual screenshot-capture path still need manual verification.

Full-screen Spaces, multiple displays, accessibility, permissions, other-Mac installation and the updated drag UI need further checking. The **100 MB Release memory budget and idle CPU targets are unvalidated**. See [verification reports](verification/) for actual outcomes and pending gates.

## Code and agent guide

Start with [AGENTS.md](AGENTS.md) for the implementation map, engineering constraints, validation notes and handoff. The complete [original brief](SelfDrop/DropShelf-Codex-Brief/), [architecture](SelfDrop/DropShelf-Codex-Brief/docs/02-architecture.md), [implementation plan](SelfDrop/DropShelf-Codex-Brief/docs/07-implementation-plan.md) and [original SVG](SelfDrop/DropShelf-Codex-Brief/design/shelf-wireframe.svg) remain included.

The downloadable ZIP is tracked in [downloads/](downloads/). DMG creation was blocked by development-environment disk-image services; [failure notes](verification/dmg-packaging.md) and an experimental [script](scripts/create-dmg.sh) are retained. No working DMG is claimed.

The [owner-supplied icon SVG](design/appicon.svg) is preserved as source artwork. Native macOS icon exports are generated by `scripts/render-app-icon.swift`; the current app uses these assets in Finder, the Dock, About panel and shelf header.
