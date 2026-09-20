# VibePM 0.8.1 PRD — Empty Trash

## Status

- Version: 0.8.1
- Date: 2026-09-20
- State: Implemented and accepted

## Problem

Trash supports restoring or permanently deleting one deletion batch at a time, but users cannot permanently remove all Trash contents in one action.

## Requirements

1. Trash displays an **Empty Trash** action whenever at least one deleted Project or independent Task batch exists.
2. The action requires a destructive confirmation and clearly states that the operation cannot be undone.
3. Confirming removes every deleted Project, every Task associated with those Projects, and every independently deleted Task.
4. Active Projects and Tasks must remain unchanged, including active Tasks unrelated to deleted Projects.
5. A failed save rolls the operation back and uses the existing localized persistence error.
6. After success, Trash becomes empty, its sidebar count becomes zero, and reminders are refreshed from active Tasks.
7. Simplified Chinese and English copy are required.

## Acceptance

1. Unit-test the complete permanent-deletion scope, including older independently deleted Tasks attached to a deleted Project.
2. Verify active unrelated data is excluded from cleanup.
3. Verify Empty Trash is visible only when Trash contains data.
4. Verify the destructive confirmation can be cancelled.
5. Verify confirming clears Trash in the packaged application.
6. Run the complete automated test suite and update release artifacts.
