# Repository Guidance

VibePM is a local-first project management application for macOS. Keep the first release focused on fast personal task management and native Mac interaction.

## Development rules

- Read `CONTEXT.md` before naming domain types or user-facing concepts.
- Read relevant files in `docs/adr/` before changing architecture or persistence.
- Prefer small, testable feature slices over framework-heavy abstractions.
- Keep the core domain independent from individual views.
- Run `swift test` before considering an implementation complete.

## Agent skills

### Issue tracker

Requirements, specifications, and implementation tasks are tracked in GitHub Issues for `2581606234/vibe-coding`. See `docs/agents/issue-tracker.md`.

### Domain docs

This is a single-context repository with `CONTEXT.md` at the root and architectural decisions in `docs/adr/`. See `docs/agents/domain.md`.

