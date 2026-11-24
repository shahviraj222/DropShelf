# Acceptance tests — all initially NOT RUN

Codex must distinguish automated tests from manual tests. Report date, OS/hardware, build config, actual observations and pass/fail/pending. Do not infer real third-party app integration from unit tests. Use non-sensitive test fixtures and disposable copies for file operations.

| ID | Test | Acceptance |
|---|---|---|
| U01 | Add a file/folder, same URL twice, many URLs | Correct entries; dedup; no file bytes copied. |
| U02 | 11 and burst 1,000 screenshot insertions | At most 10 newest; oldest evicted; manual entries unaffected. |
| U03 | Inject clock at expiry boundaries, wake/time jump | Each item expires at 1h; timer reschedules, originals intact. |
| U04 | Manual remove, clear, active drag during expiry | Remove metadata only; snapshot remains safe; no resurrection. |
| U05 | Deleted/renamed/moved/inaccessible/disconnected item | Resolve where possible; unavailable safely otherwise; no hang. |
| U06 | Selection and async stale result | Stable IDs; no accidental multi-drag; stale callbacks discarded. |
| U07 | Cancel/teardown tasks, cache eviction | Bound memory cost, release handles and observers. |
| U08 | New vs old screenshot events; duplicate/late metadata | No historic import or duplicates; conservative classification. |
| I01 | Inspect native drag pasteboard | File URL typed payload per item, not plain string substitution. |
| I02 | Finder -> collapsed tab -> Finder test folder | Real file copied with expected bytes; original remains; no shelf copy. |
| I03 | Desktop screenshot -> ChatGPT browser composer | Actual image attachment preview, not textual path; compare direct Finder drop. |
| I04 | Five screenshots -> ChatGPT | Five actual attachments or clear destination limitation; compare baseline. |
| I05 | Image -> VS Code Explorer folder | File exists in actual project folder, byte equality vs original. Not merely editor preview. |
| I06 | Folder -> supported VS Code target | Opens/adds correct original folder as direct Finder drag does. |
| I07 | PDF -> Gmail attachment area | Actual file attached, no text link. No need to send. |
| I08 | Cancel or drop onto rejecting target | Entries retained, no false success. |
| I09 | Partial missing items | Explicit warning; never silently omit; valid subset or safely cancel. |
| I10 | Native screenshot save and file event | New reference after file becomes ready, unrelated downloads not collected; no screen capture permission. |
| I11 | Floating thumbnail/clipboard-only screenshot | Inspect supported data; handle approved types only; no false success or unapproved files. |
| I12 | Denied/revoked screenshot folder permission | Auto collection gracefully unavailable, manual drop still works. |
| I13 | Quit/reopen app, restart Mac | Empty shelf; no saved item data; originals unchanged. |
| I14 | Maximized and green-button full-screen apps, Spaces switching | Right-edge button accessible in supported contexts; no minimize required; typed drag works. |
| I15 | Multiple monitors, Stage Manager, disconnect, sleep/wake | Safe repositioning, no duplicate panels, no focus theft/hangs; document OS limitations. |
| I16 | Long press vs drag, keyboard selection, direct collapsed drop | Predictable gestures, concise feedback, accessible UI. |
| P01 | Fresh startup + 5 min idle, 24h soak | Peak footprint <=100 MB in tested workload, near-zero idle CPU; no sustained growth. |
| P02 | 10 real high-resolution screenshots, 500 manual refs or chosen bound, rapid panel open | <=100 MB peak, UI responsive, preview cache bounded. |
| P03 | 100 GB folder reference (or safe simulated fixture) | No recursive scan, no copy, no significant file-size-dependent growth. |
| P04 | 1,000 open/close and repeated drag cycles | <=100 MB peak in tested workload, no leaks or sustained growth. |
| P05 | Burst screenshot events and pressure/sleep/wake | Bounded tasks, cache drops, stable UI, no unhandled crash. |

Measure P tests with release build and Activity Monitor/physical footprint sampling plus Instruments Allocations/Leaks/Time Profiler. Record transient peaks and limitations of sampling. Manual native cross-app testing is release-blocking. Build success alone is not acceptance. No tests performed by the specification author.
