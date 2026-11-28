# Screenshot responsiveness — 2026-11-28

## Cause and implementation

The old monitor restarted a 400 ms debounce on every directory write, so sustained activity postponed scans. A completed screenshot also needed a second 400 ms scan for stable size, and four closely spaced attempts could miss delayed metadata.

Now a directory event schedules a scan after 50 ms, preserving the earliest existing deadline. One cancellable work item and generation token suppress obsolete callbacks. Candidates retain separate next-attempt deadlines, so unrelated directory activity cannot burn their attempts early. Failed readiness/metadata checks retry after 150 ms, 750 ms and 2 seconds (still four attempts maximum). The first stable marked file can normally be discovered around 200 ms after a save event; this is a scheduling target, not a guaranteed OS latency.

Scans remain serial, off the UI thread, nonrecursive and limited to 4,096 entries and 64 pending candidates. New creation time, image extension, repeated nonzero stable size and screenshot metadata/xattr are still required. Old files are baselined without import. Deleted/unreadable candidates clear retry deadlines; stop releases scan/candidate state. There is no continuous polling, raw clipboard access, filename-only fallback, image copying or screen capture.

## Actual results

- Xcode BuildProject passed after monitor implementation (4.290 seconds) and final invalid-candidate cleanup (4.169 seconds), with no errors.
- All 12 Swift Testing store/selection tests passed before the monitor-only change; no claim that these unit tests exercise directory delivery.
- Native synthetic event check passed initially with collection in 0.238 seconds. Repeated against final code with a deleted pending candidate: 0.221 seconds. Created a metadata-marked PNG, a delayed-metadata PNG, an unrelated PNG and a pending PNG subsequently deleted while 50 unrelated directory writes occurred about 20 ms apart. Exactly the two eligible images were collected, including the delayed marker; pre-existing, unrelated and deleted files were excluded; no duplicate results. Stop prevented a subsequent marked image from being collected. General clipboard and real Desktop contents were untouched.
- [Repeatable snippet](screenshot-events-snippet.swift) runs in ScreenshotMonitor.swift's Xcode context. This uses synthetic metadata, not the macOS screenshot UI.
- Native FileDragView snippet also confirmed that click item 1 then a Shift-modified mouse event on item 4 selects all four through the actual handler.

## User setup and pending checks

DropShelf can react only after macOS saves a durable screenshot in the watched directory. A floating screenshot thumbnail, clipboard-only capture or different save folder may delay/prevent collection. Desktop is attempted by default; use the folder picker to grant access or select the actual save location. No extra privileges were added.

Physical screenshot saving, permission denial, busy real Desktop, large captures, screenshot UI timing, accessibility, CPU/memory and full-screen regression remain unverified. No guaranteed real-time deadline or performance-budget acceptance is claimed. The public ZIP remains the older text preview; run current SelfDrop source in Xcode for these changes.
