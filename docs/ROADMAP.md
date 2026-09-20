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

## Milestone 3.1 — Data trust (0.8.0)

- Recoverable 30-day Trash for Projects, Tasks, and deletion batches.
- Immediate Undo and explicit persistence-error feedback.
- Daily automatic, manual, exportable, and pre-import Recovery Points.
- Excel Import Preview with create/update counts and cancel-before-write behavior.

Exit: 48 automated tests pass, the ad-hoc signed application and DMG verify, and bilingual acceptance is recorded in `docs/acceptance/0.8.0.md`.

## Next iteration candidates

1. Bulk edit and bulk move for selected Tasks.
2. Manual drag ordering and saved view preferences per Project.
3. Milestones and Task dependencies, including dependency lines in Gantt.
4. Recurring Tasks and reminder lead-time controls.
5. Tags and saved smart views across Projects.
6. Notarized distribution and an in-app update channel.

## Milestone 3.1.1 — Trash cleanup (0.8.1)

- One-click Empty Trash action with destructive confirmation.
- Complete removal of deleted Projects, their associated Tasks, and independently deleted Task batches.
- Active data exclusion and rollback on persistence failure.

Exit: 49 automated tests pass and packaged bilingual UI acceptance verifies cancel and confirm paths.

## Milestone 3.1.2 — Selection and timestamp polish (0.8.2)

- Stable absolute entry timestamps for Trash rows.
- Toolbar selection action selects all currently visible Tasks immediately.
- Second toolbar action exits selection and clears the selection.

Exit: packaged UI acceptance verifies stable timestamps and select-all behavior.
