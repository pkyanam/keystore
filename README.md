# KeyStore

A lightweight macOS **menu bar app** for storing key–value secrets — API keys,
temporary passwords, recovery codes, and anything else you need quick, private
access to — from one simple interface that lives in your menu bar.

Everything is encrypted on disk and protected behind a single **Touch ID**
unlock per session.

> **Status:** v1.0 · macOS 14 (Sonoma) or later · Apple Silicon & Intel

---

## Features

- 🔐 **Encrypted vault** — all entries are stored in a single AES‑GCM encrypted
  file; the encryption key never leaves the Keychain.
- 👆 **Touch ID unlock** — one biometric prompt per session (falls back to your
  Mac password). Browse, search, and copy freely once unlocked.
- ➕ **Fast capture** — add a key/value pair in seconds right from the menu bar.
- 🔎 **Search & scroll** — instantly filter your catalog by name, category, or
  tag. Secret values are never searched.
- 🏷️ **Categories & tags** — organize entries (e.g. *API Keys*, *Recovery Codes*).
- 📋 **One‑click copy** — copy a value to the clipboard; reveal/hide on demand.
- 🔒 **Auto‑lock** — the vault relocks after a period of inactivity, or instantly
  with **Lock Now**.
- 🧰 **No Dock icon, no clutter** — runs as a menu bar accessory only.

---

## Install

### Download a release (recommended)

1. Go to the [**Releases**](https://github.com/pkyanam/keystore/releases) page.
2. Download `KeyStore.dmg` (or `KeyStore.zip`).
3. Open the DMG and drag **KeyStore** into **Applications**.
4. Launch it — a 🔑 key icon appears in your menu bar.

Release builds are **signed with a Developer ID certificate and notarized by
Apple**, so they open without Gatekeeper warnings.

> If you built the app yourself (unsigned) and macOS blocks it, right‑click the
> app → **Open**, or run:
> ```bash
> xattr -dr com.apple.quarantine /Applications/KeyStore.app
> ```

### Build from source

Requirements: **macOS 14+** and **Xcode 16+**.

```bash
git clone https://github.com/pkyanam/keystore.git
cd keystore
open KeyStore.xcodeproj      # then press ⌘R
```

Or from the command line:

```bash
xcodebuild -scheme KeyStore -configuration Debug build
```

> The first build signs with your own team. Open
> **Signing & Capabilities** in Xcode and select your team if prompted. The
> **Keychain Sharing** capability (group `ai.keystore.KeyStore`) is required —
> it's already in the entitlements file.

---

## Usage

1. Click the 🔑 icon in the menu bar.
2. Authenticate with **Touch ID** (or your Mac password). The first launch
   creates your vault.
3. Use **＋** to add an entry: give it a **Name**, the secret **Value**, and
   optionally a **Category** and **Tags**.
4. **Search** at the top to filter; click the **eye** to reveal a value or the
   **copy** button to put it on your clipboard.
5. Use the **⋯** menu to **Lock Now** or **Quit**.

---

## Security model

KeyStore is designed so that your secrets are encrypted at rest and only
accessible after biometric/passcode authentication.

| Concern | How it's handled |
| --- | --- |
| **Encryption** | The vault is a Codable blob sealed with **AES‑256‑GCM** (CryptoKit). GCM is authenticated, so any tampering or wrong key fails to decrypt. |
| **Key storage** | The 256‑bit master key lives in the **Keychain** (data protection keychain) behind a `SecAccessControl` of `[.biometryAny .or .devicePasscode]`, `WhenUnlockedThisDeviceOnly`. |
| **Authentication** | Unlock forces a fresh `LAContext.evaluateAccessControl` prompt, then reads the key — the secret is released by the Secure Enclave, **not** gated by a hookable boolean. |
| **Recovery resilience** | `.biometryAny` (not `.biometryCurrentSet`) is used so re‑enrolling Touch ID does **not** destroy the key. |
| **At rest** | Vault file lives in the sandbox container and is written atomically with complete file protection. |
| **Distribution** | App Sandbox + Hardened Runtime; releases are signed (Developer ID) and notarized. |

> ⚠️ **Recovery:** Because the master key is bound to your Mac's Keychain and is
> **device‑only**, it is not backed up or synced. If you erase your Mac or your
> login keychain, the vault becomes unrecoverable. Encrypted export/import is on
> the roadmap — until then, keep an independent backup of anything critical.

This project leans on Apple's documented best practices (Keychain Services,
LocalAuthentication, TN3137, CryptoKit). See [`SECURITY`](#reporting-a-vulnerability)
below for how to report issues.

---

## Architecture

SwiftUI for the UI, a small AppKit shell for the menu bar window, and a clean
separation between security, storage, and presentation.

```
KeyStore/
├── KeyStoreApp.swift          # @main; wires the AppDelegate
├── AppDelegate.swift          # NSStatusItem + key‑capable NSPanel, activation,
│                              #   outside‑click dismissal, auto‑lock/unlock
├── Models/
│   ├── Entry.swift            # a single secret + metadata
│   └── Vault.swift            # Codable container (versioned)
├── Security/
│   ├── MasterKeyStore.swift   # Keychain master key (biometric SecAccessControl)
│   ├── VaultCrypto.swift      # AES‑GCM seal/open
│   ├── Biometrics.swift       # availability checks for UI labels
│   └── KeychainError.swift
├── Store/
│   └── VaultStore.swift       # @Observable state: lock/unlock, CRUD, search, persistence
└── Views/
    ├── MenuContentView.swift  # routes locked ↔ unlocked
    ├── UnlockView.swift
    ├── EntryListView.swift     # search + scroll + add
    ├── EntryRow.swift          # reveal / copy
    └── EntryEditorView.swift   # add / edit / delete

Config/      # Info.plist + entitlements (referenced via build settings)
KeyStoreTests/   # Swift Testing unit tests (no Keychain needed — injected key)
scripts/release.sh   # local sign + notarize + package
.github/workflows/   # CI build/test + tag‑triggered release
```

**Why a custom `NSPanel` instead of `MenuBarExtra(.window)`?** The SwiftUI menu
bar popover is transient and can't reliably become the key window, which breaks
text‑field focus and modal sheets. A real key‑capable `NSPanel` (in
`AppDelegate`) fixes input handling and gives full control over dismissal.

---

## Development

```bash
# Build
xcodebuild -scheme KeyStore -configuration Debug build

# Run the test suite (Swift Testing)
xcodebuild -scheme KeyStore -configuration Debug test
```

Tests avoid the real Keychain/biometrics by injecting a fake key provider
(`FakeKeyProvider`), so they run anywhere — no entitlements or hardware needed.

The Xcode project uses **file‑system‑synchronized groups**, so new files added
under `KeyStore/` or `KeyStoreTests/` are picked up automatically — no
`project.pbxproj` edits required.

---

## Releasing

See [`docs/RELEASING.md`](docs/RELEASING.md) for the full signing + notarization
walkthrough. In short:

```bash
# One‑time: store notarization credentials in your login keychain
xcrun notarytool store-credentials keystore-notary \
  --apple-id "you@example.com" --team-id "YOURTEAMID" --password "app-specific-pw"

# Build, sign (Developer ID), notarize, staple, and package into dist/
TEAM_ID=YOURTEAMID ./scripts/release.sh 1.0.0
```

This produces `dist/KeyStore-1.0.0.dmg` and `dist/KeyStore-1.0.0.zip`.

CI (`.github/workflows/release.yml`) does the same automatically when you push a
`v*` tag, using repository secrets.

---

## Contributing

Contributions are welcome! Please read [`CONTRIBUTING.md`](CONTRIBUTING.md).

## Reporting a vulnerability

Please **do not** open public issues for security problems. Email the maintainer
or open a private GitHub security advisory.

## License

[MIT](LICENSE) © 2026 Preetham Kyanam
