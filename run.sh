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
echo "📦 Opening: $APP_PATH"
open "$APP_PATH"
