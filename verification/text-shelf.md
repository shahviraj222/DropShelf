# Text shelf verification — 2026-11-25

The owner requested multiple saved text/URL snippets with compact previews and unchanged shelf dimensions. This explicitly extends the original file-reference scope to session-only text storage.

## Implementation

- Files/Text segmented control reuses the existing four-tile viewport. Text previews are limited to 80 characters and normalized to one line; the full original string is retained separately. Scrolling browses additional entries.
- Explicit Save clipboard or focused Command-V saves plain text/URLs. Text drops are accepted after checking for native file URLs first. There is no clipboard timer or automatic collection.
- Select a text tile and Copy (or focused Command-C), then paste into the destination app. NSPasteboard writes the exact original plain-text string. Rich text formatting and outgoing text drags are not provided.
- Fifty entries maximum; each accepts at most 65,536 UTF-8 bytes. Exact duplicates select the existing entry. Capacity refusal never evicts existing entries. Removal follows the active section; Clear all clears both sections. Shutdown releases text.
- Existing typed file drag sessions, screenshot queue and panel height calculations are preserved.

## Actual results

- Xcode BuildProject passed after implementation (3.710 seconds); the final rebuild after updating built-in help also passed (2.647 seconds, no errors).
- SelfDropTests: 10 passed, 0 failed, 0 skipped, 0 not run. The three new Swift Testing cases cover exact text preservation/deduplication/bounded previews, UTF-8/capacity refusal without eviction, and removal/clear/fresh-session shutdown behavior. Restored SelfDrop scheme afterward.
- RunCodeSnippet in FileDragView created eight entries and reported: exact private-pasteboard round trip true; preferred panel height unchanged true; four visible text tiles; all previews bounded true. The check used a unique pasteboard and did not replace the user's general clipboard.

## Pending and distribution

Real mouse/keyboard interaction, scrolling, cross-app paste and accessibility still need manual verification. No new memory-budget acceptance claim is made. The downloadable 1.0.2 ZIP and its checksum remain unchanged; this feature currently requires building the source in Xcode.
