# Changelog

All notable changes, new features, and bug fixes for **Away** are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) and adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Dock Window Preview Titles:** Window titles rendered underneath preview thumbnails with ellipsis truncation for long titles, whitespace/newline sanitization, and fallback app name resolution.
- **Dock Foundation:** Reversible Dock settings store with a full original backup, step-by-step undo, restore and reset to the macOS defaults. Dock item, hover and window services built on Accessibility, and a permissions screen.
- **Project Foundation:** Native Swift package (`AwayCore` + `AwayApp`), staging build and DMG tooling, CI and tag-driven release workflows.
