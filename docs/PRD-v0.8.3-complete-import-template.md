# VibePM 0.8.3 PRD — Complete Excel Import Template

## Status

- Version: 0.8.3
- Date: 2026-09-20
- State: Implemented and accepted

## Problem

The Excel import template opens on the Project sheet. That sheet correctly contains only Project fields, but it makes the Task fields easy to miss. Users cannot immediately see that the template supports the same Task information available in the manual create form, including description, scheduled date, due date, status, priority, Project, and Parent Task.

## Product model

- Project and Task remain separate record types.
- The Project sheet contains the fields from manual Project creation: name, description, and accent, plus archive and import identity fields.
- The Task sheet contains the fields from manual Task creation: title, description, scheduled date, due date, status, priority, Project, and Parent Task, plus import identity and audit fields.
- Task-only fields must not be copied onto Project records.

## Requirements

### Task-first template

- A newly downloaded import template opens with the Task sheet selected.
- The Task sheet appears first in the visible tab order, followed by Projects and Instructions.
- The on-disk worksheet paths remain compatible with the existing importer and previously exported files.

### Complete editable field coverage

- Task columns include title, description, scheduled date, due date, status, priority, Project relationship, and Parent Task relationship.
- Project columns include name, description, accent, and archive state.
- Status, priority, Project, Parent Task, accent, and archive fields provide localized drop-down validation.
- Scheduled and due dates are stored as typed Excel dates with readable localized headers.
- The sample rows populate every requested Task field and demonstrate a parent/subtask relationship.

### Guidance and compatibility

- Instructions begin with a concise note that the Task sheet matches the manual create form.
- Field-level instructions remain available in Simplified Chinese and English.
- Existing templates and exports remain importable.
- A template downloaded under the current app language uses matching sheet names, headers, examples, instructions, and validation values.

## Acceptance

1. Chinese and English templates open on the Task sheet and show it as the leftmost tab.
2. Template XML contains all manual Task fields and all corresponding validation controls.
3. Importing either localized template restores description, scheduled date, due date, status, priority, Project, and Parent Task.
4. Existing export/import round-trip tests remain green.
5. `swift test`, release build, packaged app, and generated workbook visual inspection pass.
