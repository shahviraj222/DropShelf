# Published DropShelf 1.0.3 — 2026-11-28

Source commit: e42130407071789d08d0b4b56daf4486c0aafcca. Code was unchanged during packaging. The owner approved the latest UI and requested GitHub publication. The prior staged owner-supplied app/icon are untouched and were not used for this fresh build.

## Build provenance

Built with Xcode 27.2 (27B52), macOS 27.2 SDK, Release configuration, arm64 destination and macOS 27.2 minimum. Compiler log confirms -O and whole-module optimization. Package version 1.0.3/build 4 comes from command-line overrides; the local project's default version/build are still 1.0.2/3. Source hashes, ZIP checksum/size and build overrides are recorded in [provenance JSON](release-1.0.3-provenance.json).

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild   -project SelfDrop.xcodeproj -scheme SelfDrop -configuration Release   -destination 'platform=macOS,arch=arm64'   -derivedDataPath .build/release-1.0.3 build ARCHS=arm64   CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=   MARKETING_VERSION=1.0.3 CURRENT_PROJECT_VERSION=4   'EXCLUDED_SOURCE_FILE_NAMES=ContentView.swift *.md shelf-wireframe.svg'
```

The ignored dist/release-1.0.3-build.log contains the local full build log. The app was copied with ditto into a staging directory as DropShelf.app, zipped with ditto -c -k --sequesterRsrc --keepParent and extracted into a separate verification directory. No post-sign resource editing or re-signing was performed. No DMG was made.

## Actual checks

- Release build succeeded; executable reports arm64. Built/extracted Info.plist reports version 1.0.3/build 4, AppIcon and minimum macOS 27.2.
- codesign --verify --deep --strict passed before and after ZIP extraction. Signing is ad hoc, not Developer ID or notarized. Entitlements retain App Sandbox, user-selected read-only access and the local build's get-task-allow setting; no broad filesystem entitlement was added.
- unzip -t passed. Every extracted regular file matches the fresh build byte-for-byte. ZIP SHA-256 generated and stored in its sibling checksum file.
- Archive contains AppIcon.icns and Assets.car. No brief Markdown, wireframe resource or Debug/preview dylibs. Build exclusions resolve the previously noted accidental documentation resources for this package.
- Latest source suite result remains 12 passing Swift Testing cases (including Shift ranges); presentation changes subsequently passed their documented IDE builds/geometry checks. No new unit-suite run was performed for packaging.
- README download and checksum links now point to 1.0.3. Older releases/preview archives are preserved.

## Remaining acceptance limits

No fresh launch or cross-app upload was performed for this package. Owner approved the latest UI, but exact manual coverage is unspecified. Actual multi-video Google Drive upload, full-screen/multiple displays, accessibility, permission edge cases, other-Mac Gatekeeper/installation and Release physical footprint/CPU/soak acceptance remain pending. This optimized development download does not establish those gates.
