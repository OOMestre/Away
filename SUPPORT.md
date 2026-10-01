# Support

Away is a free and open source project, maintained on a best-effort basis. There is no formal support contract or promised response time, but every issue, question, and suggestion is read and appreciated.

---

## Report a Bug

1. Check [existing issues](https://github.com/OOMestre/Away/issues) to avoid duplicates.
2. Open the [bug report template](https://github.com/OOMestre/Away/issues/new?template=bug_report.md) and include:
   - **Away version** (e.g. `v1.0.0`)
   - **macOS version** (e.g. macOS 15.0 Sequoia)
   - **Hardware architecture:** Apple Silicon or Intel
   - **Steps to reproduce**, **expected** and **actual** behavior
   - Screenshots of your Dock or desktop when relevant (remove private information)

## Request a Feature

Open the [suggestion template](https://github.com/OOMestre/Away/issues/new?template=suggestion.md). Describe the problem or the look you are trying to achieve, not only a single implementation idea — it helps design a cohesive, native solution.

## Restore the macOS Defaults

If something looks wrong after a customization, Away can always restore the previous state. If the app cannot open, you can reset the Dock manually:

```bash
defaults delete com.apple.dock && killall Dock
```

> This resets **all** Dock preferences, including the apps pinned to it.

## Security and Privacy

If you discover a security vulnerability, please open a [private security advisory](https://github.com/OOMestre/Away/security/advisories/new) instead of a public issue. See [docs/PRIVACY.md](docs/PRIVACY.md) for details.

---

## Documentation Index

- [README](README.md) — Overview, roadmap, and installation
- [Contributing Guide](CONTRIBUTING.md) — Development setup, standards, and Pull Request workflow
- [Release Guide](docs/RELEASE_GUIDE.md) — Versioning, staging betas, and production releases
- [Privacy and Security Policy](docs/PRIVACY.md) — Data handling, permissions, and network behavior
- [Trademarks Policy](TRADEMARKS.md) — Away name, icon, and branding
