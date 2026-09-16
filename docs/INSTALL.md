# Install and test VibePM

## Requirements

- Apple Silicon Mac
- macOS 14 or later

## Install from the DMG

1. Open `dist/VibePM.dmg`.
2. Drag `VibePM.app` to the Applications folder.
3. Open VibePM from Applications.

The current development release is ad-hoc signed rather than notarized with an Apple Developer certificate. If macOS blocks the first launch, Control-click VibePM, choose Open, and confirm once.

## Acceptance test

1. Create a Project with an accent color.
2. Create a Task with a priority and due date.
3. Create a second Task and assign the first Task as its parent.
4. Switch the Project between List, Board, and Gantt; confirm scheduled Tasks appear on the timeline.
5. Move Tasks between Status columns using the status menu.
6. Search and apply a priority or Status filter.
7. Archive the Project, then restore it from Archive.
8. Open Settings → Data, download the Excel template, and confirm it opens with Projects, Tasks, and Instructions worksheets.
9. Export an Excel workbook, import the same workbook, and confirm records are merged rather than duplicated.
10. Open Settings → General and switch between Simplified Chinese and English; confirm the main window updates immediately.
11. Quit and reopen VibePM to confirm local data and language selection persist.

## Build a fresh package

```sh
./scripts/package_app.sh
```

## Run automated verification

```sh
swift build
swift test
```
