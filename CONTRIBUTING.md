# Contributing to KeyStore

Thanks for your interest in improving KeyStore! This is a small, focused macOS
app, and contributions of all sizes are welcome.

## Getting started

1. Fork and clone the repo.
2. Requirements: **macOS 14+** and **Xcode 16+**.
3. Open `KeyStore.xcodeproj` and select your signing team under
   **Signing & Capabilities** (Keychain Sharing capability is required and
   already configured).
4. Build and run (⌘R), or use:
   ```bash
   xcodebuild -scheme KeyStore -configuration Debug build
   xcodebuild -scheme KeyStore -configuration Debug test
   ```

## Guidelines

- **Match the existing style.** Swift, SwiftUI for views, AppKit only where
  necessary (the menu bar shell).
- **Keep security code conservative.** Changes to `Security/` (Keychain, crypto,
  biometrics) should follow Apple's documented patterns and include tests where
  feasible. Never log secret values.
- **Add tests** for logic changes. Unit tests use the Swift Testing framework and
  inject a fake key provider, so they don't touch the real Keychain.
- **Don't add dependencies** without discussion — the app is intentionally
  dependency‑free.
- **Comments:** only where they add real value; avoid noise.

## Pull requests

1. Create a topic branch.
2. Make your change with a clear, focused commit history.
3. Ensure `xcodebuild ... build` and `... test` both pass.
4. Open a PR describing **what** changed and **why**, plus any testing notes.

## Reporting bugs

Open an issue with steps to reproduce, your macOS version, and whether you're on
a release build or building from source.

For **security vulnerabilities**, do not open a public issue — use a private
GitHub security advisory instead.
