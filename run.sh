#!/bin/bash

set -e

echo "🚀 Building ClipFlow..."

# Build the project
xcodebuild -project ClipFlow.xcodeproj -scheme ClipFlow build

# Find the built app
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "ClipFlow.app" -path "*/Debug/ClipFlow.app" -type d | head -1)

if [ -z "$APP_PATH" ]; then
    echo "❌ Could not find built app"
    exit 1
fi

echo "✅ Build succeeded"
echo "📦 Running: $APP_PATH"
echo "📝 Logs will appear below..."
echo ""

# Run directly in foreground to see logs
"$APP_PATH/Contents/MacOS/ClipFlow"
