# Milestone 2 — session store checkpoint

Owner authorized continuation after reporting working VS Code/email/ChatGPT integration on 2026-11-24.

## Changes

- ShelfStore owns up to 500 session-only references, UUID selection, atomic capacity refusal, URL and resource/volume identity deduplication. Native file URL payloads remain copy-only.
- ReferenceResolver performs serial, background metadata checks and best-effort ordinary bookmark resolution without UI/mounting. Bookmark bytes stay in memory, limited to 64 KiB per item. No content hashes, recursive enumeration, original-file writes or persistence.
- Item/generation checks discard stale results. Clearing removes membership and queued work; active drag snapshots retain reference access until terminal callback. A noninterruptible filesystem call may finish after cancellation, but its result is discarded. At most one metadata call runs; slow/disconnected volumes can delay subsequent checks without blocking the UI.
- Checking/unavailable rows, explicit retry via status line, all-or-nothing selection drag. Validation older than five seconds requires a fresh check and another drag gesture; no silent partial payload.
- Scrollable nine-row viewport, Cmd-click selection, 0.7-second long press for multi-select, Cmd-A, Delete, Escape, and header Remove/Clear actions. Clear/Delete only remove references. Generic drag icon avoids synchronous filesystem icon lookup.
- Swift Testing target covers capacity/deduplication, stale-result removal, unavailable subset rejection, snapshot lifetime, generation guards, and real-file/deleted-file validation.

## Validation

Initial app build passed (4.920 s); app-scheme build-for-testing passed (4.069 s), but its test plan contained zero tests. Live Xcode diagnostics for FileDragView and ShelfStore: zero issues.

Final Swift Testing run, 2026-11-25 00:02 IST, SelfDropTests scheme on My Mac: **5 passed, 0 failed, 0 skipped, 0 not run**. Earlier hosted setup failed to link with the debug dylib and then failed runner connection. The final test target is hostless and compiles the actual production ShelfStore.swift through a relative symlink (SelfDropTests/ShelfStore.swift -> ../SelfDrop/ShelfStore.swift), avoiding a second implementation. Use SelfDropTests scheme with Product > Test; SelfDrop remains the run scheme. Debug dylib remains enabled for Xcode snippets.

The real-file test initially failed on deleted-file availability. Clearing cached URL resource values before reading metadata fixed it; the full five-test suite passed afterward. Separate Xcode RunCodeSnippet assertions passed URL deduplication, atomic capacity refusal, generation guard, unavailable-subset rejection, stale removal, retained snapshot and fresh-store emptiness. These tests do not replace physical-Mac UI, sandbox or integration checks.

## Remaining gates

New long-press, scrolling, unavailable/retry, rename/move, slow/offline volume, clear-during-drag and sandbox access behavior need physical-Mac verification. Custom-drawn rows still need a full accessibility pass and production native control polish. Outside-click dismissal, range selection and previews are deferred. Automatic screenshots, separate FIFO/TTL queue and folder opt-in belong to milestone 3 and are not implemented in this checkpoint. No Release footprint/CPU compliance claimed.
