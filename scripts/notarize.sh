#!/bin/bash

# ClipFlow Notarization Script
# Usage: ./notarize.sh <dmg-path> <api-key-path> <api-key-id> <api-issuer>
# Example: ./notarize.sh ClipFlow.dmg AuthKey.p8 ABC123DEF456 12345678-1234-1234-1234-123456789012

set -e

if [ $# -ne 4 ]; then
    echo "Usage: $0 <dmg-path> <api-key-path> <api-key-id> <api-issuer>"
    echo ""
    echo "Example:"
    echo "  $0 ClipFlow.dmg AuthKey.p8 ABC123DEF456 12345678-1234-1234-1234-123456789012"
    exit 1
fi

DMG_PATH="$1"
API_KEY_PATH="$2"
API_KEY_ID="$3"
API_ISSUER="$4"

echo "📦 Submitting $DMG_PATH for notarization..."

# Submit to Apple Notarization service
xcrun notarytool submit "$DMG_PATH" \
    -k "$API_KEY_PATH" \
    -d "$API_KEY_ID" \
    -i "$API_ISSUER" \
    --wait

echo "✅ Notarization completed!"

# Staple the notarization ticket to the DMG
echo "📌 Stapling notarization ticket..."
xcrun stapler staple "$DMG_PATH"

echo "✅ Done! $DMG_PATH is now notarized and ready for distribution."
echo ""
echo "Verify with:"
echo "  spctl -a -vvv $DMG_PATH"
