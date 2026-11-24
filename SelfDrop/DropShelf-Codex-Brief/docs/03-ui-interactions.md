# UI and interaction specification

See design/shelf-wireframe.svg (conceptual, not pixel-perfect). Compact, native appearance; respect light/dark mode, accessibility, reduced motion and display safe areas. Blue right-edge tab always accessible in supported desktop/full-screen contexts; opens inward, never center. Suggested tab 24–32 pt wide by 52–64 pt high, panel 260–320 pt wide and content-bounded height, adjust for actual displays. Dimensions/colors are design defaults, not user-approved hard values. No full-screen overlay window or giant invisible hit area. Do not steal focus unnecessarily; preserve ability to use keyboard selection intentionally.

## Interaction contract
| Gesture | Behavior |
|---|---|
| Drag over collapsed tab | Highlight/round/expand target without opening entire shelf (default). |
| Drop files onto tab | Register valid references; brief checkmark/round feedback only after success; return to collapsed. |
| Single click tab | Toggle right-side panel. |
| Single click item | Select one; no auto paste. |
| Click and drag item | Native drag, no wait for long-press. |
| Long press item | Enter multi-select mode; suggested 0.7s, owner originally suggested 2–3s. Tune after testing; movement cancels long press. |
| Cmd-click / Shift-click | Toggle individual / select range, standard Mac behavior (proposed). |
| Cmd-A | Select all within active section (proposed). |
| Drag selected item | Drag all selected valid items in one native session; unselected item starts single drag. |
| Delete / remove action | Remove selected shelf references, not original files. |
| Escape / outside click | Dismiss selection/panel (proposed; no global event tap). |
| Right click | Proposed compact menu: clear shelf, toggle screenshot collection, quit. |
| Double click tab | Proposed Quick Copy latest item to clipboard, then user Cmd-V; no auto paste. |
| Drag from collapsed tab | Proposed Quick Drag latest item using native drag session. |

Collapsed -> drag-hover -> registering -> accepted/rejected/cancelled -> collapsed. Separate shelf expansion and active-drag state; success animation suggested ~200–300 ms, respect reduce motion. Show partial success count or error non-modally. A click cannot trigger a drag or long-press accidentally; defer single-click action if implementing double-click, test responsiveness. No notification sound.

Panel: header with close/collapse and clear options, manual files section and recent screenshots section (newest first, up to 10). Thumbnail for images, native icons for folders/documents, shortened filename + accessible full label; selection highlight and count; unavailable marker, retry/reveal if appropriate. Scroll/virtualize long manual collection. Multi-select crosses sections only if deliberately supported. Keep selections by stable IDs, not array index. Clear removed IDs. Offer explicit remove, not trash semantics. Empty state: 'Drop files here'. Avoid unnecessary global hover monitoring.

Collapse default (proposed): after native drag completes, not at drag start until proven safe. On cancel/reject preserve selection and optionally keep panel open. Do not destroy originating view or session mid-drag. Quick copy/drag default is latest available item of any type if approved; if latest unavailable do not silently choose unrelated item. Clipboard behavior varies by receiving app and is not native drag equivalence.
