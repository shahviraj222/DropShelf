# Shift-click range selection — 2026-11-28

File tiles now delegate modifier selection to ShelfStore.selectFile. An ordinary click establishes the anchor, Shift-click selects the inclusive range in visual Files order (manual items followed by newest-first screenshots), repeated Shift-click expands/shrinks that range, and Command-Shift-click unions it with existing selection. Command-click/long-press individual selection and dragging an already-selected group are preserved. Removed anchors fall back to the target; clear/shutdown discard the anchor. No text-tile multi-selection was added.

Actual results: Xcode BuildProject passed in 4.326 seconds; all 12 Swift Testing checks passed (0 failed/skipped/not run), including two new forward/reverse/shrinking range, group preservation, visual screenshot order, additive modifiers and removed-anchor checks. Restored SelfDrop scheme. Physical Shift-click followed by native dragging still requires manual checking. Public ZIP unchanged.
