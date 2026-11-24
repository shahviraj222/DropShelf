# Local packaging attempt — 2026-11-25

- Xcode BuildProject passed. Release xcodebuild succeeded after excluding the unused starter ContentView.swift, whose Preview macro hit sandbox-exec restrictions. Runtime AppKit source was not changed.
- Release output uses the existing ad hoc identity and sandbox entitlements. codesign --verify --deep --strict passed for the app and its copied DropShelf.app package.
- DMG creation did not succeed in the assistant environment: hdiutil create returned Device not configured, Directory not empty and Operation not permitted across attempts; macOS 27 diskutil image create from returned OSStatus 2. HFS+/UDF hybrid attempts stalled and were stopped. No verified DMG exists and no mounting/installation claim is made.
- The reusable script uses macOS 27 diskutil image create from, whose command syntax was checked locally. A successful run would verify/mount/check/detach the image and produce a SHA-256 checksum. That path remains blocked here; run bash scripts/create-dmg.sh in a normal Terminal with working disk-image services.
- Fallback artifact: dist/DropShelf-1.0-arm64.zip, containing the verified Release app. SHA-256: 657f1f22466c62b2adebd61a1016bd759e4047bcb3e3de07c711cd220d435812. The app is not Developer ID signed or notarized. Launch on another Mac and full product acceptance are unverified.
- Build output and artifacts are ignored by Git. No binary was uploaded to GitHub.
