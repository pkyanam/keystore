# KeyStore

A sandboxed macOS menu bar app (macOS 14+) for storing key-value secrets
(API keys, temporary passwords, recovery codes) behind a single Touch ID unlock.

## Architecture

- **Storage:** Entries are serialized and encrypted with AES-GCM (CryptoKit) into
  a single file at `~/Library/Containers/<bundleid>/Data/Library/Application Support/KeyStore/vault.dat`
  (sandbox container).
- **Master key:** A 256-bit `SymmetricKey` stored in the Keychain behind a biometric
  `SecAccessControl` (`[.biometryAny, .or, .devicePasscode]`, `WhenUnlockedThisDeviceOnly`).
  Retrieving it triggers exactly one Touch ID prompt per session. `.biometryAny` is
  used (not `.biometryCurrentSet`) so re-enrolling Touch ID does not destroy the key.
- **UI:** SwiftUI `MenuBarExtra` (`.window` style). Locked → `UnlockView`;
  unlocked → `EntryListView` (search + scroll + add/edit/delete + copy).
- **Auto-lock:** Vault locks after 5 minutes of app inactivity (and via "Lock Now").

### Key files
- `KeyStore/Security/MasterKeyStore.swift` — Keychain master key (biometric ACL).
- `KeyStore/Security/VaultCrypto.swift` — AES-GCM seal/open.
- `KeyStore/Store/VaultStore.swift` — state, CRUD, search, encrypted persistence.
- `Config/Info.plist`, `Config/KeyStore.entitlements` — referenced via build settings
  (kept out of the synchronized source group so they aren't bundled as resources).

The Xcode project uses file-system-synchronized groups, so new files added under
`KeyStore/` or `KeyStoreTests/` are picked up automatically (no pbxproj edits needed).

## Build & test

```bash
# Build the app
xcodebuild -scheme KeyStore -configuration Debug build

# Run unit tests (Swift Testing)
xcodebuild -scheme KeyStore -configuration Debug test
```

Tests avoid the Keychain/biometrics via `FakeKeyProvider` (see `KeyStoreTests/`).

## Distribution

Local builds use ad-hoc signing (`CODE_SIGN_IDENTITY = "-"`), which disables the
Hardened Runtime. For notarized distribution, set a Developer ID identity/team;
`ENABLE_HARDENED_RUNTIME` and App Sandbox are already configured.

## Known future work
- Encrypted export/import for backup/recovery (master key loss currently means
  the vault is unrecoverable by design).
- Optional clipboard auto-clear after copy.
