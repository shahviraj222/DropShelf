# Instructions for Codex / coding agents

Read README, all docs and design/shelf-wireframe.svg before implementation. Owner-confirmed requirements override proposed defaults; see docs/07 for open decisions. Do not interpret an unresolved decision as an approved feature.

- Swift + AppKit core; use SwiftUI only where it helps and fits the measured budget. Prefer public Apple APIs, no external dependencies, no Chromium, backend, analytics or networking.
- Hard product acceptance criterion: app memory footprint stays at or below 100 MB (100,000,000 bytes) in the agreed release workload. Not an OS-enforced ceiling. Measure actual release builds, including transient peaks; if a test exceeds budget, report and fix, do not claim compliance. Idle CPU near zero; no continuous directory or clipboard polling.
- Existing files/folders are references in memory only. No shelf database, saved history, restoration on app/Mac restart or duplicated original contents. Never delete or move originals as part of shelf maintenance.
- Native incoming/outgoing drag payloads, one NSDraggingItem per selected file URL; never implement file drag as a plain-text path. Native destination determines action. Default to copy-only operations pending owner decision; no fake success on app upload/copy.
- Automatic screenshot section: newest 10 max, FIFO eviction, per-item one-hour TTL, no original deletion. Only monitor the user's selected screenshot save folder; do not record screen or globally intercept clipboard.
- Right-edge collapsed blue drop target; direct drop without opening; compact right-side panel, never centered. Brief feedback only after accepted registration. Single click opens shelf; multi-select and outgoing native drag.
- All UI and AppKit work on main actor. Bound background work, handle cancellation, avoid retain cycles/force unwraps, guard lifecycle and permissions. No blocking IO on main except unavoidable narrowly measured AppKit callbacks; avoid synchronous remote-volume probes.
- Start with feasibility spikes on this Mac: right-edge panel over native full-screen Spaces, then real Finder/ChatGPT/VS Code typed drag. Do not assume universal behavior. Use supported public APIs only.
- Make small reviewable changes. Explain API choice, architecture and tradeoffs, list changed files, build/test commands and actual outcomes. Do not invent test results. Keep manual tests marked pending until performed on physical Mac. Add/update tests per milestone.
- Do not enable broad permissions, private APIs, automatic pasting, or persistent/temporary screenshot files without owner approval. Ask only when a material unresolved choice blocks safe progress; otherwise implement labeled conservative defaults from docs/07.
