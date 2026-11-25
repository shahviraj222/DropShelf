# DropShelf — agent handoff and engineering instructions

## Start here

Read README.md, SelfDrop/DropShelf-Codex-Brief/AGENTS.md, its README/START_CODEX, all eight docs files and design/shelf-wireframe.svg before behavioral changes. The original brief is the complete requirements source; conversation instructions override proposed defaults. Read verification/ to distinguish actual results from pending gates.

Product name is DropShelf. Xcode project/schemes and internal executable remain SelfDrop. Packaging and tests rely on these paths.

## Implementation map

| File | Responsibility |
|---|---|
| SelfDrop/SelfDropApp.swift | AppKit entry point, menu, panel lifetime, shutdown |
| SelfDrop/ShelfWindowController.swift | One nonactivating floating panel, right-edge placement, display observation |
| SelfDrop/FileDragView.swift | Native buttons/tiles, selection/long press, typed drag sessions, folder picker, bounded previews |
| SelfDrop/ShelfStore.swift | Main-actor references/UUID selection; serial resolver; in-memory bookmarks; dedup, screenshot FIFO/expiry |
| SelfDrop/ScreenshotMonitor.swift | Selected-directory DispatchSource notifications, bounded reconciliation, screenshot metadata/readiness |
| SelfDropTests/SelfDropTests.swift | Ten Swift Testing checks with injected-clock expiry and real-file fixtures |
| SelfDropTests/ShelfStore.swift | Relative symlink to production source; never replace with a copied implementation |
| downloads/ | Public ZIP and SHA-256 checksum linked in README |
| scripts/create-dmg.sh | Experimental packaging; disk-image creation is blocked here |

ContentView.swift is an unused starter excluded from compilation. The brief was intended to be excluded from resources; the existing ZIP still contains brief resources, observed during archive inspection. Recheck target resource membership before the next package. No third-party runtime dependencies exist.

## Constraints to preserve

- UI/AppKit/state on main actor; filesystem/preview IO bounded and off UI thread. No recursive scans or continuous directory/clipboard polling.
- Files remain references only. Owner-authorized text snippets are held in memory: 50 entries, 65,536 UTF-8 bytes per entry, no automatic clipboard monitoring, exact-content deduplication, cleared at shutdown. Files/Text share the four-tile viewport; never grow the panel for text. Copy uses native plain-text NSPasteboard; file drag payloads remain typed file URLs.
- Session-only state: no database, restoration, persisted bookmarks, copied originals, automatic original deletion/move, networking or telemetry.
- Use typed native file URLs, one NSDraggingItem per selected file, copy-only operations. Never send plain text paths or claim upload success from a drag-end operation.
- Retain ordered drag snapshots and security access until terminal callback. Removal/expiry cannot invalidate active snapshots. Stale results cannot resurrect removed items.
- Manual cap 500 with explicit refusal. Automatic queue newest 10; each expires at one hour; one next-expiry task. Manual promotion removes automatic membership. Clear removes references but keeps future monitoring; Stop disables collection.
- The owner authorized Desktop as the startup default screenshot folder. Attempt that location without broad permissions; when access is denied, offer the Desktop-prefilled picker. Monitor only Desktop or another explicitly selected screenshot folder. Baseline old files without import. Current bounds: 4,096 entries, 64 pending candidates, four metadata/readiness attempts. No filename-only fallback, screen recording, clipboard image materialization or promised-file storage.
- Previews: one decoder actor, 160-pixel max, 16 cached images, cleared on collapse. Do not introduce full-size image decoding without measurement.
- Release physical footprint acceptance is <=100,000,000 bytes in the agreed workload; NOT yet established. Unit tests/build success cannot prove release acceptance.
- Avoid force unwraps/Combine, release tasks/observers/scopes, preserve sandbox and user-selected read-only permissions. No broad entitlements or Gatekeeper bypass.

## Validation and known traps

Use Xcode BuildProject for IDE builds. Run tests with SelfDropTests; the app scheme currently has zero tests. Restore SelfDrop afterward. Tests are hostless after the original app-hosted setup failed. Keep ENABLE_DEBUG_DYLIB enabled for snippets.

Clear cached URL resource values before revalidating availability: a real-file deletion test caught stale metadata. Snapshots require validation within five seconds. A stale/checking selection now retains the held press while refreshing and resumes its native drag only while the left button is still down. Release cancels the pending gesture. Keep source tiles alive during this interval; unavailable or changed selections must never silently become a partial drag. Ordinary bookmarks offer best-effort rename/move resolution. Noninterruptible metadata calls can delay the single worker but must not block UI.

Recorded: ten tests passed (including three text checks); synthetic directory-event fixtures passed; Release build and ad hoc signature verification passed. Pending: real screenshot collection on owner setup, redesigned UI/drag regression checks, full-screen/Stage Manager/multiple displays, permission denial, accessibility, memory/CPU/soak, other-Mac installation. Never relabel pending work as passed.

## Download and packaging

downloads/DropShelf-1.0.2-arm64.zip is the actual Release download: arm64, macOS 27.2 minimum, ad hoc signed, not notarized. No verified DMG exists. See verification/dmg-packaging.md. The SVG is a design concept, not a current app screenshot.

For replacement packages: rebuild Release from intended source, verify signature/ZIP integrity, update checksum and README version/requirements, and record source/build provenance. Never leave a stale checksum. Keep generated .build/, dist/, Xcode user state and credentials out of Git. Do not add licensing terms without owner direction.

## Commit discipline

The owner requires detailed commits from now on. Keep each change focused and explain every change, why it was made, validation actually run and known limitations in the commit body. Do not claim unrun tests.

## Icon and app details update

The owner-supplied icon is preserved at design/appicon.svg. scripts/render-app-icon.swift exports its exact simple vector geometry into all ten native macOS AppIcon slots with transparency; update the exporter if the artwork changes. SelfDropApp now supplies About, Show Shelf (Shift-Command-S), usage help and Dock reopen handling. Shelf header uses the bundled app icon. Current version 1.0.2/build 3; project/scheme/executable names are unchanged.

## Text shelf update

The current source adds Text → Save clipboard, compact selectable previews, Copy, explicit text drops and focused ⌘V/⌘C shortcuts. Clear all clears both file references and text; removal targets the active section. No text persistence or automatic clipboard history. Native snippet confirmed exact clipboard round trip, four bounded previews and unchanged preferred panel height. Real cross-app paste and interaction remain manual checks. The original Release ZIP is preserved. The latest owner-supplied Debug app is now published separately as downloads/DropShelf-1.0.2-text-preview-arm64.zip; see verification/text-preview-package.md. See verification/text-shelf.md.

## Latest owner-supplied download

README now points to downloads/DropShelf-1.0.2-text-preview-arm64.zip, packaged from the owner-supplied SelfDropTests/SelfDrop.app without rebuilding or altering its signed contents. It is arm64, macOS 27.2+, ad hoc signed, not notarized, and contains Debug/preview libraries. Its internal version remains 1.0.2/build 3. Signature and extracted-file equality/ZIP checks passed. Do not describe this artifact as an optimized Release or assert exact source provenance. Original 1.0.2 Release remains available.
