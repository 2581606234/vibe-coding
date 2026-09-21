# VibePM v0.8.6 PRD — Bulk Task editing and moving

Status: Implemented and accepted

## Problem and goal

Task selection currently supports only deletion. Updating a group of Tasks requires opening every Task separately. v0.8.6 makes the existing selection mode useful for routine organization while preserving the local-first, recoverable data model.

## Scope

1. In Inbox, Today, and Project List/Board/Gantt, selecting one or more visible Tasks exposes **Edit Selected…**.
2. A single bulk editor can optionally change Status, Priority, and destination Project (including Inbox). Every field defaults to **Keep current**. An unchecked/unchanged field never overwrites mixed values.
3. The editor shows the number of selected Tasks and a preview count for Tasks affected by a Project move, including descendants.
4. Confirm applies the selected changes in one SwiftData save; Cancel changes nothing. A successful save exits selection mode and refreshes reminders. Failure rolls back and shows the existing persistence error.
5. Status changes set or clear completion time consistently with individual Task status changes. Priority changes affect only selected Tasks.
6. Moving a Task to a different Project (or Inbox) also moves all of its active descendants, preserving their relative hierarchy. If a selected Subtask moves without its parent, it becomes a top-level Task in the destination. If its parent is also moved, the relationship remains.
7. Archived and deleted Projects cannot be destinations. Trashed Tasks are not edited or moved.
8. Before a committed bulk change, create a local pre-bulk Recovery Point so a user can restore the previous snapshot through Data settings.
9. All new UI copy has English and Simplified Chinese translations and accessibility labels.

## Rules and edge cases

- Selected IDs are resolved against all active Tasks at confirmation time; selection is cleared if the visible set disappears.
- Descendant expansion occurs only for a Project move. Status/Priority edits do not implicitly affect unselected descendants.
- If an entire parent/child pair is selected, each Task is changed once.
- Moving a child alone detaches it only when its parent will not be in the destination after the move.
- A no-op editor cannot be confirmed. A destination identical to every selected Task's current Project is a no-op unless another field changes.
- A failed Recovery Point creation or SwiftData save prevents a success message. The database must remain unchanged on a failed save.
- Bulk editing never deletes Tasks, changes IDs, or changes titles/descriptions/dates.

## Out of scope

- Bulk date editing, title/description replacement, tags, assignees, or manual drag ordering.
- Cross-device collaboration and cloud history.
- Moving Tasks into Archive or Trash via the bulk editor (existing Trash action remains separate).

## Acceptance criteria

1. Selection mode in Inbox, Today, Project List, Board, and Gantt exposes the same bulk editor.
2. Status-only and Priority-only changes leave every other field unchanged and touch only selected Tasks.
3. Moving a parent moves all active descendants and preserves hierarchy; duplicate selections do not duplicate work.
4. Moving a Subtask without its parent detaches it; moving the parent too preserves the relationship.
5. Inbox and active Projects are valid destinations; Archive and Trash are not.
6. Cancel and no-op paths write nothing; success is one save and creates a pre-bulk Recovery Point.
7. Failed saves roll back and show localized error feedback.
8. English and Simplified Chinese labels and confirmation copy are verified in the packaged app.
9. `swift test`, release build, signature, DMG integrity, and functional acceptance pass.

## Development assessment

- Domain rules and tests: small-to-medium change, about half a day. Reuse `TaskHierarchy.deletionIDs` for descendant expansion; keep the action model in `VibePMCore`.
- SwiftUI selection/editor integration: medium change, about half a day. Reuse the existing selection state across all three Project views.
- Recovery Point, persistence, localization, package, and UI acceptance: about half a day.
- Main risk: moving a selected Subtask could leave a cross-Project parent. Mitigation: explicitly normalize parent links in the domain action and test parent-only, child-only, combined, and Inbox moves.

## Delivery records

- Tracking issue: [#20](https://github.com/2581606234/vibe-coding/issues/20).
- Acceptance: `docs/acceptance/0.8.6.md`.
- Release notes: `docs/releases/0.8.6.md`.
