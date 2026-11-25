# Owner-supplied text preview package — 2026-11-25

The owner identified `SelfDropTests/SelfDrop.app` as the latest app and requested publication. Packaged that exact signed bundle as `DropShelf.app` inside `downloads/DropShelf-1.0.2-text-preview-arm64.zip`; no rebuild, resource removal, re-signing or version modification was performed.

- Bundle metadata: version 1.0.2/build 3, com.virajshah.SelfDrop, arm64 executable, macOS 27.2 minimum, Xcode 27.2 SDK metadata.
- Ad hoc signature, no Developer ID or notarization. Contains SelfDrop.debug.dylib and __preview.dylib: this is a Debug preview, not an optimized Release artifact.
- Binary string inspection found Save clipboard, Text saved and Text shelf is full in the debug library. The owner supplied the build as latest; exact build commit and build invocation are unknown, so no reproducible-source provenance is asserted.
- codesign --verify --deep --strict passed for the supplied app and for the ZIP-extracted app. unzip -t passed. Every extracted regular file matched the supplied bundle byte-for-byte. SHA-256 recorded in the sibling checksum file.
- The signed bundle retains brief documentation resources. Removing them would alter the supplied signed artifact, so they were preserved. Revisit resource membership for the next source-built Release.
- README points to this preview; the previous optimized 1.0.2 Release ZIP and checksum remain unchanged.

No launch, cross-app paste, Gatekeeper acceptance on another Mac, performance acceptance or new automated suite run was performed for this packaging operation. The source feature's previous 10-test result is documented separately in text-shelf.md and does not establish the exact supplied binary's source commit.
