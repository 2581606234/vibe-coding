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
7. Move a parent Task to Trash, use Undo, then repeat and restore it from Trash; confirm its Subtasks return with it.
8. Put two items in Trash, choose Empty Trash, cancel once, then confirm and verify the sidebar count returns to zero.
9. Move the Project to Trash, restore it, then archive and restore it from Archive.
10. Open Settings → Data, download the Excel template, and confirm its language follows the app and its Status, Priority, Project, and Parent Task fields provide drop-down choices.
11. Import an Excel workbook, verify the Import Preview create/update counts, cancel once, then confirm the import.
12. Create and export a Recovery Point; restore it and confirm the local snapshot is replaced exactly.
13. Open a Project's **Project actions** menu and verify **Import Tasks…**, **Export Project…**, and **Download Template…**.
14. Export the Project and reimport it; verify Import Preview reports unchanged Tasks as Skip.
15. Import a Project template with a blank Task ID; verify the Task is created in the current Project without a Project column.
16. Attempt to import a Task ID from another Project; verify a blocking Conflict is shown and Import is disabled.
17. Select two Tasks in a Project; choose **Edit Selected…** and change Priority only. Confirm Status and dates stay unchanged.
18. Move a parent Task to another Project; confirm its Subtasks move with it and remain nested. Move a Subtask alone and confirm it becomes top-level in the destination.
19. Repeat the bulk editor in Board and Gantt, then verify a pre-bulk Recovery Point was created.
20. Open Settings → General and switch between Simplified Chinese and English; confirm the main window updates immediately.
21. Quit and reopen VibePM to confirm local data, language selection, and latest automatic Recovery Point time persist.

## Build a fresh package

```sh
./scripts/package_app.sh
```

## Run automated verification

```sh
swift build
swift test
```
