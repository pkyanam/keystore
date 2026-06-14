# Changelog

All notable changes to KeyStore are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/pkyanam/keystore/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/pkyanam/keystore/releases/tag/v1.0.0
