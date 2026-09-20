# VibePM 0.8.4 PRD — Import Identity and Audit Fields

## Status

- Version: 0.8.4
- Date: 2026-09-20
- State: Implemented and accepted

## Problem

The downloadable Excel template exposes `created_at` and `updated_at`, even though users should not manage system audit timestamps while creating Projects or Tasks. Its first identity column also appears mandatory, which makes bulk creation harder and obscures the intended export-edit-import update workflow. The current SwiftUI document exporter can also fail to present a usable save flow for existing data.

## Decisions

- Downloadable templates contain user-editable business fields only; `created_at` and `updated_at` are omitted.
- The first Project and Task identity columns remain present but are optional for new records.
- A blank identity creates a new UUID during import.
- An exported UUID identifies an existing local record; importing that row updates the record rather than creating a duplicate.
- User-provided non-UUID identifiers remain supported for compatibility and relationships.
- Full data exports continue to include identity and audit timestamps.

## Requirements

### Template

- Use clear localized labels for the first column: an optional Project ID and optional Task ID.
- Remove Project and Task creation/update timestamp columns from templates.
- Keep descriptions, schedule, due date, status, priority, Project, Parent Task, completion time, archive state, and accent behavior unchanged.
- Explain that IDs may be blank for new rows and must be retained from exports when updating records.
- Explain that Project and Parent Task relationships require a referenced row to have an ID.

### Import behavior

- Accept blank Project and Task IDs and generate UUIDs.
- Reject duplicate nonblank IDs.
- Resolve Project and Parent Task references through supplied IDs.
- Continue accepting previous Chinese and English header names and canonical export headers.
- When audit columns are absent, preserve an existing record's creation time and set its update time to the import time.
- When audit columns are present in a full export, retain the supplied timestamps.

### Export/update behavior

- Existing-data and template exports use a native macOS save panel and write the selected `.xlsx` file atomically.
- Export every Project and Task UUID in the first column.
- Reimporting an unmodified export reports those records as updates in Import Preview.
- Existing export/import round trips preserve IDs, hierarchy, dates, and timestamps.

## Acceptance

1. Chinese and English templates omit `created_at` and `updated_at` columns.
2. Blank IDs create records with generated UUIDs.
3. Exported UUIDs are present and reimport as updates.
4. Updating from a timestamp-free template preserves original creation time.
5. Older localized templates and full exports remain importable.
6. Packaged-app UI acceptance saves an existing-data workbook through the native save panel.
7. Full automated tests, workbook visual inspection, release build, signing, and DMG verification pass.
