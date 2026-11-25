# App icon and native details — 2026-11-25

Source/build provenance: runtime source and icon assets in commit af978ce1b36d8995c6e0efcf4c25118fdac0f6ff. Release build used Xcode 27.2, SelfDrop scheme, macOS 27.2 deployment target, arm64, ad hoc signing. Bundle version 1.0.1/build 2; original project/executable/bundle identity retained.

The owner SVG is preserved at design/appicon.svg. Native transparent PNG exports populate all ten AppIcon slots (16 through 1024 pixels). The deterministic CoreGraphics exporter renders the supplied gradient/path geometry and checks for unsupported source changes. Quick Look rendering was inspected first, but its white background was unsuitable for icon corners; it was not used as the production export. The final 1024px transparent native export was inspected visually, and PNG dimensions were verified for every slot.

Added About DropShelf with version/owner icon credit, Show Shelf (Shift-Command-S), built-in usage help, Dock reopen handling, and the icon in the shelf header. No screenshot, file-storage or transfer policy changes.

Actual results:

- Xcode BuildProject passed, most recent build 1.540 seconds.
- Command-line optimized Release build passed. actool invocation explicitly selected --app-icon AppIcon; final Info.plist declares CFBundleIconFile=AppIcon and AppIcon.icns exists.
- SelfDropTests: seven passed, zero failed/skipped/not run.
- Release app deep/strict signature verification, ZIP integrity, SHA-256 verification, icon dimensions and local README links passed.
- Download artifact: downloads/DropShelf-1.0.1-arm64.zip; checksum is in its sibling .sha256 file. Earlier 1.0 download is retained; README points to 1.0.1.

Physical Finder/Dock refresh, About/help interactions and header appearance still need manual observation. No other-Mac launch/notarization or performance acceptance is claimed. Ad hoc signing remains in use. The archive still contains original brief resources; their target membership remains a packaging cleanup item. The user's separately staged SelfDropTests/appicon.svg was preserved and not included in these commits.
