# Contributing to Away

Thank you for your interest in contributing to Away!

Away is a free and open-source native macOS customization app (Dock, widgets, and wallpaper) built entirely in Swift and SwiftUI. We welcome contributions ranging from bug fixes and performance improvements to documentation enhancements and new features.

---

## Code of Conduct and Principles

When contributing to Away, please keep these core project tenets in mind:

1. **100% Native Swift and SwiftUI:** Away relies on Apple's first-party frameworks (Swift, SwiftUI, AppKit, Swift Concurrency). Avoid adding external dependencies unless strictly necessary and discussed beforehand.
2. **Platform Focus:** Engineered specifically for macOS (macOS 14.0 Sonoma and newer), supporting both Apple Silicon and Intel architectures.
3. **Safe and Reversible System Changes:** Anything Away changes on the system (Dock preferences, wallpaper, widgets) must be backed up first and restorable to the previous state or to the macOS defaults.
4. **Privacy and Offline First:** Zero telemetry, no cloud analytics, no accounts. User data stays on the Mac.
5. **macOS Human Interface Guidelines:** Respect Apple design principles, keyboard navigability, contrast, Light/Dark appearance, and Reduce Motion.
6. **Quality and Stability:** All changes must maintain a 100% test pass rate with zero regressions.

---

## Branching Strategy and Workflow

Away follows a structured Git branching model:

- **staging**: The primary integration branch. All active development, feature branches, and bugfix branches must branch from and target `staging`.
- **main**: The production release branch. Strictly reserved for verified, tagged releases (e.g. `v1.0.0`). Never open Pull Requests directly targeting `main`.
- **Feature and Bugfix branches**: Named descriptively according to their purpose (e.g., `feat/dock-presets`, `fix/dock-restart-loop`, `docs/update-release-guide`).

---

## Step-by-Step Contribution Guide

### 1. Fork and Clone

1. Fork the official repository [https://github.com/OOMestre/Away](https://github.com/OOMestre/Away) to your personal GitHub account.
2. Clone your fork locally:
   ```bash
   git clone https://github.com/<your-username>/Away.git
   cd Away
   ```
3. Add the upstream remote to keep your fork updated:
   ```bash
   git remote add upstream https://github.com/OOMestre/Away.git
   ```

### 2. Create a Topic Branch

Always base your working branch on the latest `staging` branch:

```bash
git fetch upstream
git checkout -b feat/your-feature-name upstream/staging
```

Branch naming conventions:
- `feat/<feature-name>`: New capabilities or functional additions.
- `fix/<issue-name>`: Bug fixes and edge-case corrections.
- `refactor/<component>`: Code restructuring without altering external behavior.
- `perf/<optimization>`: Performance and memory optimizations.
- `docs/<topic>`: Documentation updates or corrections.
- `test/<suite>`: New test suites or test framework improvements.

### 3. Build and Test Locally

Before making modifications, ensure your environment builds and passes the test suite:

```bash
# Run the complete automated test suite
make test

# Build release executable
make build

# Build local staging application bundle
make staging
```

Requirements:
- macOS 14.0 (Sonoma) or newer.
- Xcode 15.0+ or Swift 5.9+ / Swift 6.0+.

### 4. Implement Your Changes

- Follow idiomatic Swift style and the project architecture: platform logic in `AwayCore`, UI in `AwayApp`.
- Maintain test coverage by adding corresponding unit tests under `Tests/AwayTests/` for any new logic or bugfixes. Tests must never touch the real system Dock or user preferences.
- Preserve existing comments and docstrings unless explicitly refactoring that code.
- Verify light and dark mode appearance, window resizing resilience, and keyboard accessibility.

### 5. Commit Guidelines (Conventional Commits)

We follow the Conventional Commits specification. Write clear, concise commit messages in English or Portuguese (consistent with the repository style), prefixed by the appropriate type:

- `feat: add Dock magnification slider`
- `fix: restore Dock preferences after failed apply`
- `refactor: extract defaults access into DockPreferencesStore`
- `perf: debounce Dock restarts while dragging sliders`
- `test: add unit tests for Dock preset encoding`
- `docs: clarify Pull Request contribution steps in CONTRIBUTING.md`
- `chore: update build scripts for release packaging`

### 6. Submitting a Pull Request (PR)

1. Push your branch to your GitHub fork:
   ```bash
   git push origin feat/your-feature-name
   ```
2. Navigate to the Away repository on GitHub and open a **New Pull Request**.
3. **Important:** Ensure the base branch is set to **`staging`** (not `main`).
4. Fill out the Pull Request description:
   - **Summary of Changes:** Concise explanation of what was changed and why.
   - **Issue Reference:** Link related issue (e.g., `Closes #42` or `Fixes #18`).
   - **Verification Steps:** Step-by-step instructions for testing and verifying the changes.
   - **Screenshots or Recordings:** Include visual before/after for any UI or layout changes.
5. Ensure that all automated checks in GitHub Actions CI pass with 100% success.

---

## Pull Request Review Process

Once your Pull Request is opened:

1. **Automated CI:** GitHub Actions runs `swift build` and `swift test` across macOS runners.
2. **Review and Feedback:** Maintainers will review code clarity, architectural fit, HIG adherence, test coverage, and security implications.
3. **Revisions:** If changes are requested, push additional commits to your topic branch; the PR will update automatically.
4. **Merge:** Once approved, your PR will be merged into `staging` and included in the next release cycle.

---

## Reporting Issues and Requesting Features

If you encounter a bug or have an idea for improvement:

- Check existing [GitHub Issues](https://github.com/OOMestre/Away/issues) to avoid duplicates.
- Open a new issue using the appropriate format:
  - **Bug Reports:** Include macOS version, Mac hardware architecture (Apple Silicon/Intel), reproduction steps, expected behavior, and actual behavior.
  - **Feature Requests:** Provide clear context on the problem being solved and how the proposed feature fits Away's philosophy of native, reversible customization.

---

## License

By contributing to Away, you agree that your contributions will be licensed under the project's [GNU General Public License v3 (GPL-3.0)](LICENSE).
