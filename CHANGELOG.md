# Changelog

All notable changes to KeyStore are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.0] - 2026-06-14

### Added
- **Encrypted backup & restore.** Export the vault to a passphrase-protected
  file (PBKDF2-HMAC-SHA256 + AES-256-GCM) and import it on any machine, with
  **merge** or **replace** strategies. Backups are independent of the device
  master key, so they survive key changes and machine migrations.
- Graceful recovery when the vault can't be decrypted with the current key: a
  clear message plus a confirmable **Reset Vault** action (archives the old file).

### Changed
- App version now tracks `MARKETING_VERSION` via the bundle Info.plist.
- Removed the hardcoded development team from the project so contributors build
  with their own signing identity.

## [1.0.0] - 2026-06-14

### Added
- Menu bar app for storing key–value secrets (API keys, passwords, recovery codes).
- AES‑256‑GCM encrypted vault with the master key stored in the Keychain behind a
  biometric `SecAccessControl`.
- Touch ID / device‑passcode unlock (one prompt per session).
- Add, edit, and delete entries.
- Live search and scrollable catalog (secret values are never searched).
- Categories and tags.
- One‑click copy to clipboard with reveal/hide.
- Auto‑lock after inactivity and a manual **Lock Now** action.
- Developer ID signing + notarization release pipeline (local script + CI).

[Unreleased]: https://github.com/pkyanam/keystore/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/pkyanam/keystore/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/pkyanam/keystore/releases/tag/v1.0.0
