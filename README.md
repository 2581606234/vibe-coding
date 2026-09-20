# VibePM

A local-first personal project manager for macOS, built with SwiftUI and SwiftData.

## Highlights

- Native macOS list, board, and Gantt workflows
- Project archive and a 30-day Trash with batch restore, permanent deletion, and immediate Undo
- Persistent sorting by priority, schedule, due date, or creation time across every Task view
- Local-first SwiftData persistence with visible save errors and automatic local Recovery Points
- Editable Excel import/export with localized templates, field selectors, and a create/update Import Preview
- Runtime language switching: Follow System, Simplified Chinese, or English

## Requirements

- macOS 14 or later
- Swift 6.2 or later
- Full Xcode for visual development, signing, and distribution

## Run locally

```sh
swift run VibePM
```

## Verify

```sh
swift build
swift test
```

## Package for installation

```sh
./scripts/package_app.sh
```

The script creates `dist/VibePM.app` and `dist/VibePM.dmg`. See `docs/INSTALL.md` for installation and acceptance testing.

Product scope lives in `docs/PRODUCT.md`; delivery milestones live in `docs/ROADMAP.md`.

The current development release is 0.8.2. It fixes toolbar select-all behavior and displays stable Trash timestamps; requirements and acceptance evidence are in `docs/PRD-v0.8.2-selection-and-trash-time.md` and `docs/acceptance/0.8.2.md`.
