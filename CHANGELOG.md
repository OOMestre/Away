# Changelog

All notable changes, new features, and bug fixes for **Away** are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) and adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Dock running apps only:** Toggle whether the Dock shows only open apps, with Away's existing backup and undo support.
- **Unresponsive app alerts:** Detect repeated Accessibility timeouts in open Dock apps, show an icon alert, and offer a confirmed Force Quit action.
- **Dock auto-hide:** Controls for the show delay and animation duration, an instant preset, and a button to restore macOS defaults.
- **Dock spacers:** Add large or small spacers to the apps or folders side of the Dock, move them between items, and remove them with undo support.
- **Dock window previews focus:** Clicking a window preview thumbnail brings specifically that window to the front without pulling all windows of the application forward, restoring minimized windows when needed.
- **Dock Window Preview Titles:** Window titles rendered underneath preview thumbnails with ellipsis truncation for long titles, whitespace/newline sanitization, and fallback app name resolution.
- **Dock Foundation:** Reversible Dock settings store with a full original backup, step-by-step undo, restore and reset to the macOS defaults. Dock item, hover and window services built on Accessibility, and a permissions screen.
- **Project Foundation:** Native Swift package (`AwayCore` + `AwayApp`), staging build and DMG tooling, CI and tag-driven release workflows.
