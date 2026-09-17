# VibePM

A local-first personal project manager for macOS, built with SwiftUI and SwiftData.

## Highlights

- Native macOS list, board, and Gantt workflows
- Projects, Tasks, Subtasks, priorities, due dates, and local reminders
- Local-first SwiftData persistence with editable Excel import/export and localized templates with field selectors
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
