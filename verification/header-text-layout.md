# Header text layout — 2026-11-28

Owner requested removal of the normal Watching new screenshots / originals stay in your folder line and Waiting for a new saved screenshot placeholder. The view suppresses the normal watch message (including the shelf tooltip) while retaining monitoring internals, permission/error/stopped feedback and text-copy feedback. The screenshot empty state is blank while monitoring.

Moved selection count and one-hour expiry directly beneath DropShelf at y=42. Shifted Files/Text controls, counts, manual tiles, actions and screenshot section down 18 points. Moved remaining footer feedback into the former selection-count row; preferred panel dimensions stay unchanged.

Actual validation: Xcode BuildProject passed in 4.537 seconds with no errors; git diff --check passed. A native geometry snippet confirmed unchanged 643-point preferred height with ten screenshots, four manual and ten screenshot tiles, manual tiles below the header controls and screenshot tiles above footer feedback. Attempted bitmap rendering returned no output and produced no image, so no visual inspection is claimed. No unit-suite rerun for this presentation-only change. Public ZIP unchanged.
