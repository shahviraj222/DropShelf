# Header text layout — 2026-11-28

Owner requested removal of the normal Watching new screenshots / originals stay in your folder line and Waiting for a new saved screenshot placeholder. The view suppresses the normal watch message (including the shelf tooltip) while retaining monitoring internals, permission/error/stopped feedback and text-copy feedback. The screenshot empty state is blank while monitoring.

Moved selection count and one-hour expiry directly beneath DropShelf at y=42. Shifted Files/Text controls, counts, manual tiles, actions and screenshot section down 18 points. Moved remaining footer feedback into the former selection-count row; preferred panel dimensions stay unchanged.

Actual validation: Xcode BuildProject passed in 4.537 seconds with no errors; git diff --check passed. A native geometry snippet confirmed unchanged 643-point preferred height with ten screenshots, four manual and ten screenshot tiles, manual tiles below the header controls and screenshot tiles above footer feedback. Attempted bitmap rendering returned no output and produced no image, so no visual inspection is claimed. No unit-suite rerun for this presentation-only change. Public ZIP unchanged.

## Folder and Stop header row

Moved Folder and Stop to y=62, below the title/selection summary and above Files/Text at y=98. Shifted tile sections/actions down 36 points and moved feedback to the freed bottom row, keeping preferred dimensions unchanged. Button actions and monitoring behavior are unchanged.

Xcode build passed in 4.861 seconds with no errors; git diff --check passed. The first populated runtime snippet timed out after 60 seconds, so it supplies no verification result. A subsequent minimal native inspection passed and printed Folder: Desktop at (12, 62, 238, 26), Stop at (254, 62, 52, 26), and unchanged empty-panel height 400. Visual inspection and physical pointer checks remain pending; no unit suite rerun for this layout-only adjustment. Public ZIP unchanged.

## Section divider and bottom actions

Removed the redundant Select Desktop to grant access, or choose another folder sentence, while retaining the access button and picker. Moved Remove selected and Retry to the bottom. Text mode also places its Copy/Save clipboard buttons in that footer to keep the action row together. Added a rounded 2-point NSColor.separatorColor line above Recent screenshots; moved screenshot content into the former action gap and kept feedback above footer actions. Semantic separator color adapts to system appearance. Preferred panel dimensions remain unchanged.

Validation: Xcode BuildProject passed in 4.535 seconds with no errors. Native snippet confirmed both footer buttons at preferredHeight minus 38 and unchanged 400-point empty-panel height. Coordinate checks confirmed manual tiles clear the separator and four screenshot rows clear feedback at the maximum queue size. git diff --check passed. No visual inspection or unit-suite rerun for this presentation change. Public ZIP unchanged.
