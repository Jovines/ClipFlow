#!/bin/bash

# ClipFlow release packaging workflow.
# Order matters: notarize/staple the DMG before generating the Sparkle signature.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}/.."
APP_NAME="ClipFlow.app"
DEFAULT_APP_PATH="$(find "$HOME/Library/Developer/Xcode/DerivedData" -path "*/Build/Products/Release/${APP_NAME}" -type d | head -n 1)"

APP_PATH="${1:-${DEFAULT_APP_PATH}}"
DMG_PATH="${2:-${REPO_ROOT}/ClipFlow.dmg}"
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:-Developer ID Application: Deqiao Ding (7437GDF3XU)}"
ENTITLEMENTS_PATH="${ENTITLEMENTS_PATH:-${REPO_ROOT}/Resources/ClipFlow.entitlements}"
SPARKLE_KEY_PATH="${SPARKLE_KEY_PATH:-${REPO_ROOT}/secrets/sparkle_private_key.txt}"

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: Release app not found. Pass the .app path explicitly."
    echo "Usage: $0 [app-path] [dmg-path]"
    exit 1
fi

if [ ! -f "$ENTITLEMENTS_PATH" ]; then
    echo "❌ Error: Entitlements file not found: $ENTITLEMENTS_PATH"
    exit 1
fi

if [ ! -f "$SPARKLE_KEY_PATH" ]; then
    echo "❌ Error: Sparkle private key not found: $SPARKLE_KEY_PATH"
    exit 1
fi

echo "==> Signing app bundle"
codesign --force --sign "$CODE_SIGN_IDENTITY" --timestamp --entitlements "$ENTITLEMENTS_PATH" --options=runtime --deep "$APP_PATH"

echo "==> Creating DMG"
rm -f "$DMG_PATH"
create-dmg \
    --volname "ClipFlow" \
    --window-pos 400 250 \
    --window-size 540 300 \
    --icon-size 80 \
    --icon "${APP_NAME}" 270 125 \
    --hide-extension "${APP_NAME}" \
    --app-drop-link 270 205 \
    --no-internet-enable \
    --skip-jenkins \
    "$DMG_PATH" \
    "$APP_PATH"

echo "==> Signing DMG"
codesign --force --sign "$CODE_SIGN_IDENTITY" --timestamp "$DMG_PATH"

echo "==> Notarizing and stapling DMG"
"${SCRIPT_DIR}/notarize.sh" "$DMG_PATH"

echo "==> Generating Sparkle signature from final DMG"
SIGN_UPDATE="$(${SCRIPT_DIR}/sign_update.sh)"
SPARKLE_OUTPUT="$($SIGN_UPDATE -f "$SPARKLE_KEY_PATH" "$DMG_PATH")"

echo ""
echo "Release artifact ready: $DMG_PATH"
echo "$SPARKLE_OUTPUT"
echo ""
echo "Appcast enclosure snippet:"
echo "$SPARKLE_OUTPUT" | python3 - "$DMG_PATH" <<'PY'
import re
import sys

line = sys.stdin.read().strip()
dmg_path = sys.argv[1]
sig = re.search(r'sparkle:edSignature="([^"]+)"', line)
length = re.search(r'length="([^"]+)"', line)

if not sig or not length:
    raise SystemExit("Could not parse Sparkle output")

print(f'<enclosure url="RELEASE_URL/{dmg_path.split("/")[-1]}"')
print(f'           sparkle:edSignature="{sig.group(1)}"')
print(f'           length="{length.group(1)}"')
print('           type="application/octet-stream" />')
PY
