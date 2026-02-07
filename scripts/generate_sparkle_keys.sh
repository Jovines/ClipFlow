#!/bin/bash
# Script to generate Sparkle EdDSA keys
# This creates a key pair for signing app updates

set -e

SPARKLE_VERSION="2.8.1"
SPARKLE_URL="https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz"
TEMP_DIR=$(mktemp -d)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Downloading Sparkle ${SPARKLE_VERSION}..."
curl -L -o "${TEMP_DIR}/sparkle.tar.xz" "$SPARKLE_URL"

echo "Extracting..."
tar -xf "${TEMP_DIR}/sparkle.tar.xz" -C "$TEMP_DIR"

echo "Generating EdDSA keys..."
"${TEMP_DIR}/Sparkle.framework/Versions/B/Resources/generate_keys"

echo ""
echo "Keys generated successfully!"
echo ""
echo "IMPORTANT:"
echo "1. Save the private key securely (it's shown above)"
echo "2. Add the public key to your Info.plist as SUPublicEDKey"
echo "3. Use the private key with sign_update when creating releases"

# Cleanup
rm -rf "$TEMP_DIR"
