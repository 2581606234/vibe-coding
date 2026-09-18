# Delivery Roadmap

## Milestone 0 — Foundation

- Establish domain language, architecture, repository rules, and test harness.
- Create a native macOS shell with local persistence.
- Validate create/list flows for Projects and Tasks.

Exit: `swift build` and `swift test` pass, and the application opens locally.

## Milestone 1 — Capture and organize

- Inbox and quick Task creation.
- Project creation and assignment.
- Task editing, priority, due date, and completion.
- Empty, loading, and validation states.

Exit: the primary workflow works without data loss across launches.

## Milestone 2 — Plan and focus

- Today view and scheduling.
- Project Board with status transitions and a schedule-to-due-date Gantt view.
- Subtasks, search, sorting, and filtering.
- Undo and keyboard shortcuts.

Exit: a user can plan and execute a small real project entirely in VibePM.

## Milestone 3 — Own and trust the data

- Excel export/import with stable record keys, typed dates, and a downloadable template.
- Local notifications.
- Migration and recovery tests.
- Accessibility and performance review.

Exit: release-candidate quality with documented backup and recovery.

## Milestone 4 — Distribution

- Create an Xcode app project and production iconography.
- Configure signing, sandbox entitlements, and notarization.
- Package a signed DMG; evaluate the Mac App Store separately.

Exit: a clean Mac can install, launch, update, and remove VibePM safely.

## Product gap review — 2026-09-18

The next work should prioritize trust and planning depth in this order:

1. Add Undo and a recoverable Trash for Task and Project deletion.
2. Surface persistence failures instead of silently ignoring save errors.
3. Add import preview, validation errors, and conflict choices before Excel data is committed.
4. Add bulk edit and bulk move for selected Tasks, not only bulk deletion.
5. Add manual drag ordering as an alternative to automatic sorting.
6. Add milestones and Task dependencies so the Gantt view can represent real delivery sequencing.
7. Add recurring Tasks and more precise reminder controls.
8. Add tags and saved smart views for cross-Project organization.
9. Add an in-app update path and notarized distribution for dependable upgrades.
