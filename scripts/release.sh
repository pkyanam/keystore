#!/usr/bin/env bash
#
# Build, sign (Developer ID), notarize, staple, and package KeyStore.
#
# Produces:  dist/KeyStore-<version>.dmg  and  dist/KeyStore-<version>.zip
#
# Prerequisites:
#   - A "Developer ID Application" certificate in your login keychain.
#   - Notarization credentials stored once via:
#       xcrun notarytool store-credentials "$NOTARY_PROFILE" \
#         --apple-id "you@example.com" --team-id "YOURTEAMID" --password "app-specific-pw"
#
# Usage:
#   TEAM_ID=YOURTEAMID ./scripts/release.sh 1.0.0
#
# Environment variables:
#   TEAM_ID         (required) Your Apple Developer Team ID.
#   NOTARY_PROFILE  (optional) notarytool keychain profile name. Default: keystore-notary.
#   SKIP_NOTARIZE   (optional) Set to 1 to build/sign/package without notarizing.
#
# CI / headless signing (optional) — App Store Connect API key. When all three
# are set, provisioning and notarization use the key instead of interactive
# account auth and the keychain profile:
#   ASC_KEY_ID      App Store Connect API key ID.
#   ASC_KEY_ISSUER  Issuer ID for the key.
#   ASC_KEY_PATH    Path to the .p8 private key file.

set -euo pipefail

# ---- Configuration -----------------------------------------------------------
SCHEME="KeyStore"
PROJECT="KeyStore.xcodeproj"
CONFIGURATION="Release"
APP_NAME="KeyStore"

VERSION="${1:-}"
TEAM_ID="${TEAM_ID:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-keystore-notary}"
SKIP_NOTARIZE="${SKIP_NOTARIZE:-0}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT/build"
DIST_DIR="$ROOT/dist"
ARCHIVE="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
EXPORT_PLIST="$BUILD_DIR/ExportOptions.plist"

# ---- Validation --------------------------------------------------------------
if [[ -z "$VERSION" ]]; then
  echo "error: version argument required, e.g. ./scripts/release.sh 1.0.0" >&2
  exit 1
fi
if [[ -z "$TEAM_ID" ]]; then
  echo "error: TEAM_ID environment variable is required." >&2
  exit 1
fi

echo "==> Releasing $APP_NAME $VERSION (team $TEAM_ID)"
rm -rf "$BUILD_DIR" "$DIST_DIR"
mkdir -p "$BUILD_DIR" "$DIST_DIR"

# Optional App Store Connect API key auth for headless provisioning.
AUTH_ARGS=()
if [[ -n "${ASC_KEY_ID:-}" && -n "${ASC_KEY_ISSUER:-}" && -n "${ASC_KEY_PATH:-}" ]]; then
  echo "==> Using App Store Connect API key for provisioning/notarization"
  AUTH_ARGS=(-authenticationKeyID "$ASC_KEY_ID" \
             -authenticationKeyIssuerID "$ASC_KEY_ISSUER" \
             -authenticationKeyPath "$ASC_KEY_PATH")
fi

# ---- 1. Archive --------------------------------------------------------------
echo "==> Archiving"
# Automatic signing + -allowProvisioningUpdates is required: the app's
# keychain-access-groups entitlement (needed for the data-protection keychain
# on macOS) makes the app require a provisioning profile, which Xcode generates
# and embeds automatically here.
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -archivePath "$ARCHIVE" \
  -destination "generic/platform=macOS" \
  -allowProvisioningUpdates \
  ${AUTH_ARGS[@]+"${AUTH_ARGS[@]}"} \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  MARKETING_VERSION="$VERSION"

# ---- 2. Export (Developer ID) ------------------------------------------------
echo "==> Writing export options"
cat > "$EXPORT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
PLIST

echo "==> Exporting signed app"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$EXPORT_PLIST" \
  -exportPath "$EXPORT_DIR" \
  -allowProvisioningUpdates \
  ${AUTH_ARGS[@]+"${AUTH_ARGS[@]}"}

APP_PATH="$EXPORT_DIR/$APP_NAME.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "error: exported app not found at $APP_PATH" >&2
  exit 1
fi

echo "==> Verifying signature"
codesign --verify --strict --verbose=2 "$APP_PATH"

# ---- 3. Notarize -------------------------------------------------------------
NOTARIZE_ZIP="$BUILD_DIR/$APP_NAME-notarize.zip"
if [[ "$SKIP_NOTARIZE" == "1" ]]; then
  echo "==> SKIP_NOTARIZE=1, skipping notarization"
else
  /usr/bin/ditto -c -k --keepParent "$APP_PATH" "$NOTARIZE_ZIP"
  if [[ ${#AUTH_ARGS[@]} -gt 0 ]]; then
    echo "==> Submitting for notarization (API key)"
    xcrun notarytool submit "$NOTARIZE_ZIP" \
      --key "$ASC_KEY_PATH" \
      --key-id "$ASC_KEY_ID" \
      --issuer "$ASC_KEY_ISSUER" \
      --wait
  else
    echo "==> Submitting for notarization (profile: $NOTARY_PROFILE)"
    xcrun notarytool submit "$NOTARIZE_ZIP" \
      --keychain-profile "$NOTARY_PROFILE" \
      --wait
  fi
  echo "==> Stapling notarization ticket"
  xcrun stapler staple "$APP_PATH"
  xcrun stapler validate "$APP_PATH"
fi

# ---- 4. Package: zip + dmg ---------------------------------------------------
FINAL_ZIP="$DIST_DIR/$APP_NAME-$VERSION.zip"
FINAL_DMG="$DIST_DIR/$APP_NAME-$VERSION.dmg"

echo "==> Creating zip"
/usr/bin/ditto -c -k --keepParent "$APP_PATH" "$FINAL_ZIP"

echo "==> Creating dmg"
DMG_STAGE="$BUILD_DIR/dmg"
rm -rf "$DMG_STAGE"
mkdir -p "$DMG_STAGE"
cp -R "$APP_PATH" "$DMG_STAGE/"
ln -s /Applications "$DMG_STAGE/Applications"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_STAGE" \
  -ov -format UDZO \
  "$FINAL_DMG"

echo ""
echo "==> Done."
echo "    $FINAL_DMG"
echo "    $FINAL_ZIP"
