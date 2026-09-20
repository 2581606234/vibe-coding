# VibePM v0.8.5 PRD — Project-scoped Excel import and export

Status: Implemented and accepted

## Problem

The Data settings page can exchange the entire local database, but routine planning usually happens inside one Project. Requiring a user to export or import every Project makes a small update harder to understand and increases the chance that an identifier from another Project changes the wrong Task.

## Product decision

VibePM 0.8.5 adds Project-scoped Excel actions without removing the existing global workbook workflow.

- Data settings remains the place for whole-database export, import, and migration.
- A Project's **Project actions** menu gains **Import Tasks…**, **Export Project…**, and **Download Template…**.
- Project-scoped workbooks contain the selected Project's basic information and only its Tasks and Subtasks.
- A Project-scoped import always targets the Project from which it was opened. New rows do not need to select or repeat a Project.
- Stable Task IDs support an export-edit-import update workflow. A blank Task ID creates a new Task.
- Import Preview classifies rows as Create, Update, Skip, or Conflict before any data is written.

## Workbook contract

### Project export

The exported `.xlsx` file contains:

- one Project row with ID, name, description, accent, archive state, creation time, and update time;
- all active Tasks belonging to that Project;
- Task ID, title, description, status, priority, parent Task ID, scheduled date, due date, completion time, creation time, and update time;
- hierarchy represented by stable parent Task IDs.

The Project export excludes Trash. Its filename includes the Project name and export date.

### Project template

The downloadable template is localized to the current app language and is preconfigured for the selected Project. It contains the same editable Task fields as manual Task creation: title, description, scheduled date, due date, status, priority, and Parent Task, plus the optional Task ID used for updates.

System audit timestamps are not presented as fields users must complete. The selected Project is implicit during import.

### Compatibility

- A Project import accepts a Project-scoped export produced by this version.
- A Project import also accepts the localized template produced for that Project.
- Existing global exports, templates, and import behavior remain compatible and unchanged in Data settings.
- English, Simplified Chinese, and canonical field names remain accepted.

## Import classification and safety rules

For each imported Task row:

- **Create**: the Task ID is blank or does not exist locally; VibePM creates it in the selected Project.
- **Update**: the Task ID exists in the selected Project and at least one imported editable value differs.
- **Skip**: the Task ID exists in the selected Project and all imported editable values are unchanged.
- **Conflict**: the Task ID already belongs to another Project or Inbox, or its Parent Task reference resolves outside the selected Project/import set.

Additional rules:

- Parent Tasks are resolved only inside the selected Project or among rows in the same import.
- Duplicate Task IDs and invalid field values remain validation errors.
- Any Conflict disables confirmation; the user must correct the workbook before retrying.
- An import is atomic. VibePM creates a pre-import Recovery Point immediately before applying creates and updates.
- Import never creates, renames, archives, deletes, or moves the selected Project.
- Import never changes Tasks in another Project or Inbox.

## User experience

- Project actions are available while viewing an active Project in List, Board, or Gantt mode.
- Saving exports and templates uses the native macOS save panel.
- Import uses the native macOS file picker.
- Import Preview names the target Project and shows Create, Update, Skip, and Conflict counts.
- Conflict guidance explains that IDs and Parent Task IDs must belong to the current Project.
- Successful import reports the number of created and updated Tasks and refreshes reminders.
- All new interface text is available in Simplified Chinese and English.

## Out of scope

- Choosing or creating a different destination Project during import.
- Moving Tasks between Projects through Excel.
- Merging two Projects.
- Importing dependencies, assignees, comments, attachments, or custom fields.
- Cloud synchronization or multi-user collaboration.

## Acceptance criteria

1. Every active Project exposes import, export, and localized template actions.
2. A Project export includes exactly that Project and its active Tasks, preserving IDs, hierarchy, dates, status, priority, and audit timestamps.
3. A blank-ID template row imports as a new Task in the selected Project without a Project column.
4. Reimporting an unchanged Project export reports its Tasks as Skip rather than Update.
5. Editing an exported Task and reimporting it reports and applies an Update without creating a duplicate.
6. An imported ID that belongs to Inbox or another Project is reported as a Conflict and cannot be committed.
7. A Parent Task reference outside the selected Project/import set is reported as a Conflict and cannot be committed.
8. Canceling Import Preview writes nothing; confirming a conflict-free import creates a pre-import Recovery Point and applies all changes atomically.
9. Global Data-settings import/export and older workbook compatibility remain operational.
10. English and Simplified Chinese UI, template labels, and instructions are verified.
11. `swift test`, workbook ZIP validation, packaged-app smoke testing, and functional acceptance all pass before release.

## Delivery records

- Tracking issue: [#19](https://github.com/2581606234/vibe-coding/issues/19)
- Acceptance record: `docs/acceptance/0.8.5.md`
- Release notes: `docs/releases/0.8.5.md`
