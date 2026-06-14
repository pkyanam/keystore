# Releasing KeyStore

This guide covers signing, notarizing, and publishing a release — both manually
(local script) and automatically (GitHub Actions).

## Prerequisites (one time)

You need a **paid Apple Developer Program** membership.

### 1. Create a Developer ID Application certificate

1. In **Xcode → Settings → Accounts**, select your team → **Manage Certificates…**
2. Click **+** → **Developer ID Application**. (Or create it at
   <https://developer.apple.com/account/resources/certificates>.)
3. Confirm it's installed:
   ```bash
   security find-identity -v -p codesigning | grep "Developer ID Application"
   ```

### 2. Find your Team ID

```bash
# Shown in parentheses in the cert name, or at developer.apple.com → Membership
security find-identity -v -p codesigning
```

### 3. Create an app-specific password

1. Go to <https://account.apple.com> → **Sign-In and Security → App-Specific Passwords**.
2. Generate one (e.g. labeled "notarytool").

### 4. Store notarization credentials in your keychain

```bash
xcrun notarytool store-credentials keystore-notary \
  --apple-id "you@example.com" \
  --team-id  "YOURTEAMID" \
  --password "abcd-efgh-ijkl-mnop"   # the app-specific password
```

---

## Local release

```bash
TEAM_ID=YOURTEAMID ./scripts/release.sh 1.0.0
```

This will:

1. Archive the app (Release config, hardened runtime, secure timestamp).
2. Export it signed with your **Developer ID Application** certificate.
3. Submit it to Apple's notary service and **wait** for the result.
4. Staple the notarization ticket.
5. Produce `dist/KeyStore-1.0.0.dmg` and `dist/KeyStore-1.0.0.zip`.

To test packaging without notarizing (e.g. iterating on the DMG):

```bash
SKIP_NOTARIZE=1 TEAM_ID=YOURTEAMID ./scripts/release.sh 1.0.0
```

### Verify the result

```bash
spctl -a -vvv -t install dist/KeyStore-1.0.0.dmg   # should say: accepted / Notarized Developer ID
xcrun stapler validate "build/export/KeyStore.app"
```

---

## Publish to GitHub

```bash
# Tag and push — this triggers the release workflow (see below)
git tag v1.0.0
git push origin v1.0.0
```

Or manually attach artifacts to a release:

```bash
gh release create v1.0.0 dist/KeyStore-1.0.0.dmg dist/KeyStore-1.0.0.zip \
  --title "KeyStore 1.0.0" --notes "See CHANGELOG.md"
```

---

## Automated release (GitHub Actions)

`.github/workflows/release.yml` runs on any `v*` tag push and performs the same
sign → notarize → staple → package → publish flow on a macOS runner.

CI uses an **App Store Connect API key** for provisioning and notarization
(headless‑friendly), plus your Developer ID **signing certificate**.

### Required repository secrets

Set these under **Settings → Secrets and variables → Actions**:

| Secret | Description |
| --- | --- |
| `DEVELOPER_ID_CERT_P12_BASE64` | Your Developer ID Application cert + private key, exported as a `.p12`, then base64‑encoded. |
| `DEVELOPER_ID_CERT_PASSWORD` | The password you set when exporting the `.p12`. |
| `KEYCHAIN_PASSWORD` | Any random string; used for the temporary CI keychain. |
| `APPLE_TEAM_ID` | Your Apple Developer Team ID. |
| `ASC_KEY_ID` | App Store Connect API **Key ID**. |
| `ASC_KEY_ISSUER_ID` | App Store Connect API **Issuer ID**. |
| `ASC_API_KEY_P8_BASE64` | The downloaded `AuthKey_XXXX.p8`, base64‑encoded. |

### Exporting the signing certificate (`.p12`)

1. Open **Keychain Access**, find **Developer ID Application: …**.
2. Right‑click → **Export…** → save as `cert.p12` with a password.
3. Base64‑encode it for the secret:
   ```bash
   base64 -i cert.p12 | pbcopy   # paste into DEVELOPER_ID_CERT_P12_BASE64
   ```

### Creating the App Store Connect API key

1. Go to <https://appstoreconnect.apple.com/access/integrations/api>.
2. Create a key with the **Developer** role (sufficient for signing +
   notarization). Note the **Key ID** and **Issuer ID**.
3. Download the `AuthKey_XXXXXXXX.p8` (you can only download it once) and
   base64‑encode it:
   ```bash
   base64 -i AuthKey_XXXXXXXX.p8 | pbcopy   # paste into ASC_API_KEY_P8_BASE64
   ```

Once secrets are configured, every `git push origin vX.Y.Z` builds and publishes
a signed, notarized release automatically.

> The local `scripts/release.sh` also accepts the same key via `ASC_KEY_ID`,
> `ASC_KEY_ISSUER`, and `ASC_KEY_PATH` env vars if you prefer key‑based auth
> locally; otherwise it uses your interactive account + the `keystore-notary`
> keychain profile.
