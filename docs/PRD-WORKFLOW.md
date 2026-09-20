# VibePM PRD Workflow

## Purpose

Every product change must remain traceable from requirement through implementation, testing, acceptance, and release.

## Required sequence

1. Create or revise a versioned PRD before changing product behavior.
2. Record the problem, decisions, requirements, compatibility rules, and acceptance criteria.
3. Create or update the matching tracking issue.
4. Implement against the PRD.
5. Add automated and functional verification for every acceptance criterion.
6. Update the acceptance record and release notes.
7. Mark the PRD `Implemented and accepted` only after verification succeeds.

## Requirement changes

When a requirement changes after development has started or after a release:

1. Update the affected PRD first and describe the revised behavior.
2. Update the tracking issue and compatibility expectations.
3. Change the implementation and tests.
4. Repeat functional acceptance.
5. Update acceptance records, release notes, and version information when a new release is required.

Code and acceptance material must never intentionally describe behavior that differs from the current PRD.
