#!/bin/bash

# ClipFlow Notarization Script
# Usage: ./notarize.sh <dmg-path> <api-key-path> <api-key-id> <api-issuer>
# Example: ./notarize.sh ClipFlow.dmg scripts/AuthKey.p8 TZJ6FHT528 39497853-d795-468a-88a2-af5206568006

set -e

if [ $# -ne 4 ]; then
    echo "Usage: $0 <dmg-path> <api-key-path> <api-key-id> <api-issuer>"
    echo ""
    echo "Example:"
    echo "  $0 ClipFlow.dmg scripts/AuthKey.p8 TZJ6FHT528 39497853-d795-468a-88a2-af5206568006"
    exit 1
fi

DMG_PATH="$1"
API_KEY_PATH="$2"
API_KEY_ID="$3"
API_ISSUER="$4"

# Check if DMG exists
if [ ! -f "$DMG_PATH" ]; then
    echo "❌ Error: DMG file not found: $DMG_PATH"
    echo "   Please build and create the DMG first."
    exit 1
fi

# Check if API key exists
if [ ! -f "$API_KEY_PATH" ]; then
    echo "❌ Error: API key file not found: $API_KEY_PATH"
    echo ""
    echo "📋 Setup required:"
    echo "   1. Go to https://appstoreconnect.apple.com/access/api"
    echo "   2. Create an API key with Admin role"
    echo "   3. Download the .p8 file"
    echo "   4. Save it to: $API_KEY_PATH"
    echo ""
    echo "📖 See skill:release for full setup instructions."
    exit 1
fi

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
