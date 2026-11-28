# Multi-file paste and movable shelf — 2026-11-28

## Findings and changes

Reported: individual files and multiple images work in Google Drive in Chrome; multiple videos do not. No signed-in browser automation is available here. Source inspection found that Command-V unconditionally read clipboard text/URLs, despite Finder publishing native file URLs too. Corrected paste to prefer all native file URLs before the existing plain-text fallback. This fixes a concrete intake bug; it does not establish the cause of a video drop that was staged by dragging instead of pasting.

Outgoing native drag remains one NSDraggingItem per retained selected reference, NSURL writer and copy-only mask, without file bytes, video decoding, copying originals or filename-only strings. Factored the writer construction into a shared helper so runtime payload checks exercise the same writer used by actual drags. Chromium's [FilesFromPasteboard implementation](https://chromium.googlesource.com/chromium/src/+/main/ui/base/clipboard/clipboard_util_mac.mm) enumerates native file-URL items; no video-specific workaround or fabricated upload-success state was added.

The collapsed tab and expanded icon/title now use ShelfMoveHandle. Short release preserves open/close; holding 700 ms with the left button down hands the original event to [NSWindow.performDrag](https://developer.apple.com/documentation/appkit/nswindow/performdrag(with:)). It returns immediately and may consume mouse-up, so gesture state is cleared before handoff. Early release or movement cancels the hold. No repeating timer, global monitor or new permissions. Shutdown cancels the pending task.

Window delegate move events retain a session-only center. Expansion/collapse retains the anchor and fits the panel inside the nearest surviving display's visible frame. The default remains the right edge on startup; no settings/history are persisted. Short-click and collapsed hit-area resizing are preserved.

## Actual verification

- Xcode BuildProject passed initially in 10.083 seconds and after the final code changes in 0.525 seconds, no errors.
- SelfDropTests: 10 passed, 0 failed/skipped/not run. Restored SelfDrop scheme afterward.
- Native RunCodeSnippet: three NSURL writers (MP4, MOV with Unicode filename, PNG) produce three typed file-URL pasteboard items; URL round trip matches order; paste registers all three as files and zero text clips; plain-text URL fallback still adds a text clip. Synthetic URL fixtures, not real video uploads.
- Native positioning snippet: negative-coordinate display and extreme offscreen centers fit inside the visible frame; an actual controller retains a manually moved center through expand/collapse; collapsed handle covers the resized bounds and accepts first mouse.

## Pending

Real held-press window movement, release before threshold, drag cancellation, VoiceOver, multiple physical displays/disconnect/Spaces and full-screen apps require manual checks. For Drive: compare two real, locally readable MP4/MOV files dragged directly from Finder with the same files pasted/staged into DropShelf, selected together and dragged into the same Drive folder. Record file count offered/accepted, whether upload starts and any Chrome/Drive error. If direct Finder upload also fails, investigate that baseline before changing payloads. Never infer upload completion from AppKit's drag-end operation.

The public ZIP remains the older owner-supplied text preview; these changes require running the current SelfDrop source in Xcode. No new release package, performance acceptance or real third-party upload success is claimed.

## Hold duration adjustment — 2026-11-28

At the owner’s request, the tab/header movement hold is now 400 ms (0.4 seconds). Updated both tooltips, README and agent handoff. The separate file-tile multi-selection hold remains unchanged. Xcode BuildProject passed in 4.442 seconds with no errors; git diff --check passed. No new unit-suite or physical gesture check was run for this timing-only change. Public ZIP unchanged.
