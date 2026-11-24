# Build plan and decision register

## Milestones
0. Inspect installed Xcode, macOS, architecture and project. Confirm deployment target. Create git baseline. Build minimal AppKit host, right-edge nonactivating panel; test ordinary/maximized/full-screen Spaces and display switching immediately. Record exact public APIs and limitations.
1. Native drag proof: Finder -> collapsed tab -> simple shelf -> Finder, ChatGPT, VS Code Explorer and folder target. Use real typed URL payload; prove actual file semantics and multi-item transfer. Minimal UI; no auto screenshot monitor yet. Build/run tests.
2. Implement main-actor session store, dedup, reference resolution, selection, error states, stable drag snapshots and teardown. Unit tests with injected clock/IO; test no persistence. Add compact panel and success animation, multi-selection gestures, light/dark accessibility.
3. Screenshot monitor/classifier and separate 10/1h queue, opt-in folder access, event coalescing and expiry. Test new-vs-old, bursts, metadata delay and denied permissions.
4. Bounded preview/cache and production UI polish. Validate memory early and after each change. Optional Quick Copy/Quick Drag only after decisions below; inspect file promises and clipboard-only data without storing them automatically.
5. Harden displays/Spaces, sleep, unavailable references and permission boundaries. Complete manual native integration acceptance; profile 100 MB budget and idle CPU, run soak/stress tests. Fix regressions, document supported OS and known limits.
6. Local distribution/signing, launch-on-login if approved, final README and release notes. No App Store promise or paid-account assumption. Only ship after acceptance gates pass.

## Decision register
Confirmed: Swift/AppKit, native wrapper; right edge button; direct drop and visual confirmation; compact side panel; multiple selection incl. long press; session-only references, no restore, retain on outgoing drop, dedup, gracefully handle unavailable items; automatic screenshot collection, 10 FIFO and 1h TTL; original files untouched by shelf cleanup; true native file transfer; 100 MB RAM cap.

Proposed defaults / unresolved (not owner-confirmed):
| Topic | Conservative implementation default |
|---|---|
| Outgoing operation mask | Copy only; do not allow move/delete until approved. Destination still controls actual action. |
| Partial failures | Warn and allow intentional valid subset or cancel. No silent omission. |
| Auto collapse | After drag ends; keep panel on rejection/cancel. Test before changing. |
| Quick copy/drag | Optional; latest available of any type, explicit copy then Cmd-V, not automatic paste. Defer until core verified; exact gestures/target not confirmed. |
| Long press duration | Start 0.7s adjustable in code; owner suggested 2–3s, test usability. |
| Raw clipboard / promised screenshots | No owned image persistence in v1. Inspect types; require explicit approval for transient bytes/files and limits/cleanup if needed. |
| Manual reference count | Proposed 500 bound with explicit refusal, no automatic eviction. |
| Automatic/manual duplicates | Promote to manual on explicit staging, no duplicate; validate expected UX. |
| Multiple displays | One panel following selected/active display by public events; confirm owner preference later. |
| Dock/login | Accessory/no Dock proposed; opt-in launch on login later, not automatic default without approval. |
| OS support | Determine actual Mac OS and SDK, guard API availability. |
| Sandbox/signing/distribution | Evaluate local development vs sandbox; explain tradeoffs and request permission decisions before broad entitlements. |
| UI dimensions/colors/cache budgets | Starting proposals, adjust based on accessibility and profiling. |

Do not block early spikes on nonessential decisions. Do not promise universal overlay behavior, screenshot classification, clipboard compatibility or an absolute memory guarantee before testing. No app code supplied in this ZIP; the coding agent builds it in the user's Xcode project.
