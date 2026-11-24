# DropShelf — Codex implementation brief

Native macOS temporary drag-and-drop shelf. Requirements agreed with the owner through 24 November 2026. This is a specification package, not a compiled app or existing Xcode project.

## Start here
1. Create a macOS App project in Xcode named DropShelf, Swift, SwiftUI template (or AppKit if preferred), no data storage, with a test target. Choose a unique local bundle identifier and a deployment target compatible with the actual Mac.
2. Copy the contents of this folder beside `DropShelf.xcodeproj`, not into Copy Bundle Resources. Keep docs and design assets in the repository; no runtime assets are required by this package.
3. In Xcode open Coding Assistant, start a new conversation, choose Codex, and paste `START_CODEX.md`. Ensure it can read `AGENTS.md` and `docs/`.
4. Work through the milestones. Test full-screen behavior and real typed drags before building elaborate UI. Commit each verified milestone.

## Reading order
- `AGENTS.md`: engineering contract and instructions for the coding agent.
- `docs/01-requirements.md`: owner requirements and scope.
- `docs/02-architecture.md`: components, state, data flows and concurrency.
- `docs/03-ui-interactions.md`: native side shelf and input behavior; see `design/shelf-wireframe.svg`.
- `docs/04-native-integration.md`: AppKit, screenshots, permissions and displays.
- `docs/05-performance-reliability.md`: strict 100 MB RAM acceptance budget.
- `docs/06-acceptance-tests.md`: unit, integration, manual and performance gates.
- `docs/07-implementation-plan.md`: phased build and unresolved decisions.
- `docs/08-references.md`: official documentation starting points.

Owner intent: a daily-use utility, not a demo, clipboard manager, file manager, screenshot replacement or cloud service. Never confuse a native file payload with pasted path text. Never silently delete or duplicate original files.
