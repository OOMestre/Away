# Away Privacy and Security Policy

Away is designed to run entirely on your Mac.

## Data Collection

- **No telemetry, analytics, or tracking.** Away does not collect usage data, crash reports, or identifiers.
- **No accounts.** Away never asks you to sign in.
- **Local only.** Presets, backups of your previous system settings, and app preferences are stored locally on your Mac.

## System Changes

Away customizes parts of macOS (such as the Dock) by changing the same preferences that macOS itself uses. Before applying a change, Away saves a backup of the previous values so it can be restored at any time. Away never modifies system files protected by System Integrity Protection (SIP) and never asks you to disable SIP.

## Permissions

Some features may require macOS permissions (for example, Accessibility). Away requests a permission only when you use a feature that needs it, and explains why before macOS shows the prompt. Away keeps working without optional permissions; only the dependent feature is unavailable.

## Network Behavior

Away does not send your data anywhere. A future in-app update checker will only read the public GitHub Releases metadata of this repository and download the official installer, sending no personal data.

## Code Signing and Hardened Runtime

Builds are signed with the hardened runtime. The app is intentionally not sandboxed, because changing Dock and desktop preferences is not possible from inside the App Sandbox. Official releases are distributed only from this repository.

## Reporting Vulnerabilities

Please use a [private security advisory](https://github.com/OOMestre/Away/security/advisories/new) instead of a public issue.
