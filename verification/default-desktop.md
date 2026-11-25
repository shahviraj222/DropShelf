# Default screenshot folder — 2026-11-25

Owner explicitly requested Desktop as the default screenshot watching path. FileDragView now resolves the user's Desktop through FileManager's desktopDirectory/userDomainMask API and starts the existing event-driven monitor at startup. Manual selection uses the same startMonitoring helper and opens at the current folder or Desktop. Stop remains explicit and does not auto-restart monitoring during the session.

No Desktop/full-disk entitlement, persistent bookmark, clipboard access or screen recording was added. If the sandbox denies access, collection stops and the UI offers Allow Desktop access with a Desktop-prefilled native picker. Another screenshot save location can still be selected. Only new metadata-classified screenshots are eligible; prior files are baselined without import.

Validation: initial build passed (4.460 s). RunCodeSnippet passed assertions that startup uses the system Desktop URL and displays that folder in the control. Final build after permission guidance passed. Actual access to the protected Desktop and new real screenshot collection remain physical-Mac checks; no permission success is claimed. Existing store logic is unchanged; its tests were not rerun for this folder-default change. Source-only change; installed app and downloadable ZIP are not replaced.
