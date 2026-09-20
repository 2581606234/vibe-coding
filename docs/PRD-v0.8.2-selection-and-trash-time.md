# VibePM 0.8.2 PRD — Selection and Trash Timestamp Fixes

## Status

- Version: 0.8.2
- Date: 2026-09-20
- State: Implemented and accepted

## Problems

1. Trash rows use a live relative-time label, causing the displayed deletion time to keep changing.
2. The toolbar selection button enters selection mode but leaves every visible Task unselected, which conflicts with the expected select-all behavior.

## Requirements

### Fixed Trash timestamp

- Show the stored `deletedAt` value as an absolute local date and time.
- The displayed value must not refresh as time passes.
- Use the currently selected app language/locale for formatting.
- Continue using the deletion-batch timestamp for grouped Tasks.

### Toolbar select all

- Clicking the toolbar selection button while not selecting enters selection mode and selects every currently visible Task.
- Parent and Subtask rows are both selected when visible.
- Clicking the toolbar button while already selecting exits selection mode and clears the selection.
- Existing inline Select All / Deselect All behavior remains available.
- Filtering controls the visible selection scope.

## Acceptance

1. Trash displays a stable absolute deletion date and time in Chinese and English locales.
2. Waiting does not alter the displayed Trash timestamp.
3. Clicking the toolbar selection button selects all visible Task rows immediately.
4. Clicking the same toolbar button again exits selection mode.
5. Run the complete automated test suite and packaged UI smoke test.
