# Repository Guidance

VibePM is a local-first project management application for macOS. Keep the first release focused on fast personal task management and native Mac interaction.

## Development rules

- Read `CONTEXT.md` before naming domain types or user-facing concepts.
- Read relevant files in `docs/adr/` before changing architecture or persistence.
- Create or update a versioned PRD in `docs/` before implementing any feature or behavior change.
- Treat the PRD as the source of truth throughout development, testing, and acceptance.
- If requirements change after implementation or acceptance, update the corresponding PRD first, then revise code, tests, acceptance records, release notes, and tracking issues to match.
- Record the PRD state explicitly (`In development`, `Implemented; acceptance in progress`, or `Implemented and accepted`) and do not mark it accepted before verification is complete.
- Prefer small, testable feature slices over framework-heavy abstractions.
- Keep the core domain independent from individual views.
- Run `swift test` before considering an implementation complete.

## Agent skills

### Issue tracker

Requirements, specifications, and implementation tasks are tracked in GitHub Issues for `2581606234/vibe-coding`. See `docs/agents/issue-tracker.md`.

### Domain docs

This is a single-context repository with `CONTEXT.md` at the root and architectural decisions in `docs/adr/`. See `docs/agents/domain.md`.
