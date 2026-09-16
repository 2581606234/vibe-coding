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

- JSON export/import with schema versioning.
- Local notifications.
- Migration and recovery tests.
- Accessibility and performance review.

Exit: release-candidate quality with documented backup and recovery.

## Milestone 4 — Distribution

- Create an Xcode app project and production iconography.
- Configure signing, sandbox entitlements, and notarization.
- Package a signed DMG; evaluate the Mac App Store separately.

Exit: a clean Mac can install, launch, update, and remove VibePM safely.
