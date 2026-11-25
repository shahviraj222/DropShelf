# Native app icon verification — 2026-11-25

Source: 604d4d16a50421545488a262dc22dfff2194853a. Version 1.0.2/build 3, arm64, macOS 27.2 minimum, ad hoc signed.

- Regenerated ten macOS AppIcon slots from the owner's SVG geometry using the checked-in exporter. Catalog filenames/sizes remain configured for 16/32/128/256/512 points at 1x and 2x.
- Resolved xcodebuild Release settings explicitly report ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon. Built Info.plist declares CFBundleIconFile = AppIcon and CFBundleIconName = AppIcon; compiled AppIcon.icns is present.
- Added explicit startup assignment of bundled AppIcon.icns to NSApplication.applicationIconImage. This covers the running Dock icon while bundle metadata covers Finder/Spotlight discovery.
- IDE build passed in 5.402 seconds; optimized Release build passed. Signature, ZIP integrity and checksum checks passed.
- Installed at /Users/virajshah/Applications/DropShelf.app, registered with LaunchServices, requested Spotlight import and launched. No previous copy existed in the standard system/user Applications locations checked.
- A native NSWorkspace.icon(forFile:) lookup returned the custom blue arrow/tray icon, inspected visually. Native running-app inspection included the installed Release bundle. Spotlight mdls reported kMDItemDisplayName = DropShelf and kMDItemKind = Application.
- The initial Xcode preview verification could not read the user Applications bundle and its temporary assertion failed. The subsequent native check outside the preview sandbox passed. No assertion was added to production source.

Archive: downloads/DropShelf-1.0.2-arm64.zip, checksum in its sibling .sha256. Earlier downloads retained; README points to 1.0.2. No runtime store behavior changed, so store tests were not rerun for this icon-only update; the earlier seven-test result remains the latest suite run. The physical Dock and Spotlight result were not visually inspected. Global caches were not deleted and Dock was not restarted. Notarization, other-Mac launch and performance acceptance remain unverified.
