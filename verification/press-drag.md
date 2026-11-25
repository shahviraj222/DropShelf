# Continuous press-and-drag — 2026-11-25

Cause found in the source: crossing the movement threshold called endPress before snapshot validation. References older than five seconds then failed the freshness guard, refreshed, and required another gesture. Store callbacks also rebuilt tile views during the held press.

Changes: tiles accept the first mouse event in an inactive panel; selection records the gesture's IDs; threshold movement cancels long press, stores the genuine drag event and requests validation without ending the press. A store callback resumes the native session only when the original selection is still ready and the left mouse button is still down. Mouse-up clears the pending event. Tile rebuilds are deferred through held presses and active drag sessions. Freshness, typed payloads, all-or-nothing selection, copy-only operations and active snapshots remain enforced. No continuous mouse polling was introduced.

Actual verification: Xcode build passed (3.658 seconds). Seven existing SelfDropTests passed, zero failed/skipped/not run. A RunCodeSnippet check confirmed first-mouse acceptance, first-press selection, source tile identity preserved through a metadata update, and reload after release. This snippet did not simulate a complete native dragging session. Physical first-press drag to Finder/ChatGPT/VS Code, delayed-validation completion while holding, release-before-completion and multi-selection still require manual checks.

Source-only update: the installed app and public 1.0.2 ZIP have not been replaced. Quit the installed copy and run the SelfDrop scheme in Xcode to check the new behavior. Header-collapse change from the preceding source commit is included when building current main.
