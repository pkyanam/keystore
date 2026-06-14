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
#   SIGN_IDENTITY   (optional) Code-signing identity. Default: "Developer ID Application".
#   SKIP_NOTARIZE   (optional) Set to 1 to build/sign/package without notarizing.

set -euo pipefail

# ---- Configuration -----------------------------------------------------------
SCHEME="KeyStore"
PROJECT="KeyStore.xcodeproj"
CONFIGURATION="Release"
APP_NAME="KeyStore"

VERSION="${1:-}"
TEAM_ID="${TEAM_ID:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-keystore-notary}"
SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application}"
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

# ---- 1. Archive --------------------------------------------------------------
echo "==> Archiving"
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -archivePath "$ARCHIVE" \
  -destination "generic/platform=macOS" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  OTHER_CODE_SIGN_FLAGS="--timestamp" \
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
    <string>manual</string>
    <key>signingCertificate</key>
    <string>$SIGN_IDENTITY</string>
</dict>
</plist>
PLIST

echo "==> Exporting signed app"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$EXPORT_PLIST" \
  -exportPath "$EXPORT_DIR"

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
  echo "==> Submitting for notarization (profile: $NOTARY_PROFILE)"
  /usr/bin/ditto -c -k --keepParent "$APP_PATH" "$NOTARIZE_ZIP"
  xcrun notarytool submit "$NOTARIZE_ZIP" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait
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
