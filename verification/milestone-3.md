# Screenshot collection and shelf UI

2026-11-25. Implemented in response to the owner's missing-functionality/UI report.

## Behavior

- Choose screenshot folder opens NSOpenPanel for explicit read-only folder selection. Collection starts only for files created after watching starts; no historic import or folder preference persistence. Stop releases monitoring. Only that directory is inspected, without recursion.
- DispatchSourceFileSystemObject observes directory writes/deletion/rename/revocation. This public event-driven alternative to FSEvents is appropriate to the single-directory scope. A serial utility queue coalesces notifications and reconciles at most 4,096 entries; larger folders stop with a visible error. At most 64 candidate retries, four readiness/metadata attempts. No continuous directory/clipboard polling.
- Classification uses kMDItemIsScreenCapture or its metadata extended attribute, an image extension, nonzero file size, and a repeated stable-size observation. No filename-only fallback. Metadata missing after bounded retries means no automatic import; manual staging remains available. Floating screenshot promises and clipboard image data remain unsupported.
- Screenshot references are newest-first, capped at ten, expire independently at one hour, and use one next-expiry task. Prune on open/drag/add/wake. Manual promotion removes automatic membership. Clear all and Remove selected remove references only; future new screenshots continue to collect until Stop is pressed. Existing cleared screenshots are not reimported by normal directory events.
- Right-edge panel now has rounded transparent window corners, separate manual/screenshot sections, preview tiles, selection counts, native Clear all/Remove selected/Close/Retry/Choose folder/Stop buttons. Native typed multi-file dragging is preserved.
- ImageIO creates at most 160-pixel previews on one decoder actor, with cancellation checks and a 16-entry cache cleared on collapse. Original image files are never decoded into full-size AppKit images merely for display. Physical decoder/process transient memory remains unmeasured.

## Actual verification

- Final BuildProject: passed, 4.843 seconds.
- Swift Testing, SelfDropTests scheme: **7 passed, 0 failed, 0 skipped, 0 not run**. Added coverage for 1,000 screenshot insertions, newest-ten retention, manual isolation/promotion, duplicate events, exact expiry boundary and clear.
- RunCodeSnippet directory integration: passed with synthetic metadata-marked disposable fixtures. One new marked PNG reference was collected; a pre-existing marked file and an unrelated PNG were ignored. This is not a physical macOS screenshot capture test.
- Attempt to render a UI bitmap through RunCodeSnippet produced no image/output. No visual inspection of the final running app is claimed.

## Manual checks still required

Stop the previously running app and run the SelfDrop scheme again so the new executable is used. Choose the actual screenshot save folder (macOS Screenshot toolbar > Options shows the location), then save a new screenshot. Verify a preview appears, selection drags still attach/copy in real targets, Clear all empties references without touching originals, and Stop prevents future automatic additions. Verify permission denial/revocation, external-folder disconnect, delayed metadata, wake and native full-screen behavior. Recheck layout on the physical display, VoiceOver and reduced-motion settings. Release physical-footprint/idle-CPU tests remain pending; no 100 MB compliance claim.
