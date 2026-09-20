# VibePM 0.8 PRD — Data Trust and Recovery

## Status

- Version: 0.8.0
- Date: 2026-09-20
- Owner: VibePM
- State: Implemented and accepted

## Problem

VibePM can now hold real project data, but deletion is permanent, save failures can be silent, and Excel imports commit immediately. A user can therefore lose work or apply an incorrect import without a reliable recovery path.

## Goal

Make every destructive or bulk data operation understandable, recoverable, and verifiable while preserving VibePM's local-first and low-friction experience.

## Non-goals

- Cloud backup or synchronization.
- Team audit logs, permissions, or approval workflows.
- General version history for every field edit.
- Merging two divergent databases.
- Custom retention policies in this release.

## Users and jobs

As an individual project owner, I want to:

1. Recover a Task or Project I deleted by mistake.
2. Undo the most recent move-to-Trash action immediately.
3. Know when a local save fails and retry without assuming the change succeeded.
4. See what an Excel workbook will change before importing it.
5. Recover my local database from a recent automatic or pre-import Recovery Point.

## Functional requirements

### FR-1 Trash lifecycle

- Deleting a Task or Project moves it to Trash instead of permanently removing it.
- Moving a parent Task to Trash includes every visible descendant.
- Moving a Project to Trash includes all non-deleted Tasks in that Project.
- Archive remains separate from Trash.
- Trash shows deleted Projects and independently deleted Tasks.
- A deleted Project is shown once; Tasks deleted with that Project are nested under its recovery lifecycle rather than duplicated in Trash.
- Trash supports Restore and Delete Permanently.
- Restoring a deletion restores only records from the same deletion batch.
- Individually deleted Tasks remain in Trash if their Project is later deleted and restored.
- Items older than 30 days are eligible for automatic permanent deletion at launch.

### FR-2 Immediate undo

- After moving Tasks or a Project to Trash, the main window shows a non-modal confirmation bar.
- The bar includes Undo and dismisses automatically after eight seconds.
- Undo restores the complete deletion batch.
- Undo must not restore unrelated records.

### FR-3 Persistence feedback

- User-initiated writes explicitly save the SwiftData context.
- Save failures are never silently ignored.
- On failure, VibePM rolls back the uncommitted mutation when possible and displays a localized error with Retry guidance.
- Successful saves do not require a modal confirmation.

### FR-4 Recovery Points

- VibePM creates at most one automatic Recovery Point in any 24-hour period.
- VibePM retains the newest 14 automatic Recovery Points.
- VibePM creates a Recovery Point immediately before every committed Excel import.
- Recovery Points use the documented JSON backup schema and include Trash state.
- Data settings show the latest automatic backup time and allow Create Backup Now.
- Data settings allow exporting and restoring a JSON Recovery Point.
- Restoring a Recovery Point replaces the local Project and Task set with the exact snapshot and reports the result.

### FR-5 Excel Import Preview

- Selecting a valid workbook opens an Import Preview before data changes.
- The preview shows total Projects and Tasks plus counts that will be created and updated.
- The user can Cancel or Import.
- Invalid workbooks show the existing sheet, row, column, and value error without changing local data.
- Confirming Import first creates a pre-import Recovery Point, then applies the workbook.
- Excel export excludes items currently in Trash; JSON Recovery Points include them.

## Interaction requirements

- Use the canonical terms Trash, Restore, Recovery Point, and Import Preview.
- Provide Simplified Chinese and English copy.
- Trash must be reachable from the sidebar next to Archive.
- Permanent deletion requires a destructive confirmation that names the affected item.
- Empty Trash explains the 30-day retention behavior.
- Keyboard and accessibility labels must exist for Restore, Undo, and Delete Permanently.

## Data rules and edge cases

- Parent-first ordering remains unchanged outside Trash.
- Deleted records never appear in Inbox, Today, Projects, Board, Gantt, search, counts, reminders, or Excel export.
- A Task restored after its Project was permanently deleted is restored to Inbox with no parent.
- A Subtask restored without its parent is restored as a top-level Task.
- Permanent deletion of a Project also permanently deletes every Task still associated with it, including older independently deleted Tasks.
- Backup schema version 1 remains importable; new deleted-state fields default to not deleted.
- A failed import leaves the pre-import database unchanged.
- Restoring a pre-import Recovery Point removes records that were created by that import as well as reverting updated records.

## Acceptance criteria

1. Move a parent Task with two descendants to Trash, restore it, and recover all three in hierarchy order.
2. Move a Project to Trash, restore it, and recover only the Tasks from that deletion batch.
3. Permanently delete a Project from Trash and verify no associated Task remains.
4. Undo a Task and Project deletion from the confirmation bar.
5. Simulate or unit-test a save failure path and verify a localized error is produced.
6. Preview an Excel workbook and verify create/update counts before confirming.
7. Cancel an Import Preview and verify the database is unchanged.
8. Confirm an import and verify a pre-import Recovery Point exists.
9. Create automatic Recovery Points twice within 24 hours and verify only one is created.
10. Verify retention keeps at most 14 automatic Recovery Points.
11. Verify all existing automated tests plus new Trash, preview, and backup tests pass.
12. Verify the signed app and DMG, then perform bilingual UI acceptance without modifying the user's existing data.

## Release artifacts

- Updated `CONTEXT.md`, product plan, roadmap, installation/acceptance documentation, and README.
- Architecture decision for soft deletion and local Recovery Points.
- GitHub Issue linked to the release.
- Signed `VibePM.app` and `VibePM.dmg`.
- GitHub Release notes, SHA-256 checksum, and closed implementation Issue.
