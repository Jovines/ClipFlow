#!/bin/bash

set -e

echo "🚀 Building ClipFlow..."

# Step 1: Generate .xcodeproj if needed
if [ ! -d "ClipFlow.xcodeproj" ]; then
    echo "📦 Generating Xcode project..."
    xcodegen generate
else
    # Check if project.yml is newer than .xcodeproj
    PROJECT_MODIFIED=$(stat -f "%m" ClipFlow.xcodeproj/project.pbxproj 2>/dev/null || stat -c "%Y" ClipFlow.xcodeproj/project.pbxproj 2>/dev/null)
    YML_MODIFIED=$(stat -f "%m" project.yml 2>/dev/null || stat -c "%Y" project.yml 2>/dev/null)

    if [ "$YML_MODIFIED" -gt "$PROJECT_MODIFIED" ]; then
        echo "📦 Regenerating Xcode project (project.yml updated)..."
        xcodegen generate
    fi
fi

# Step 2: Resolve Swift Package dependencies
echo "📦 Resolving Swift Package dependencies..."
xcodebuild -project ClipFlow.xcodeproj -scheme ClipFlow -resolvePackageDependencies

# Step 3: Build the project
echo "🔨 Building ClipFlow..."
xcodebuild -project ClipFlow.xcodeproj -scheme ClipFlow build

# Find the built app (prefer Debug, exclude empty Index.noindex bundles)
DEBUG_PATH=$(find ~/Library/Developer/Xcode/DerivedData -path "*/Debug/ClipFlow.app" -type d | grep -v "Index.noindex" | head -1)
if [ -n "$DEBUG_PATH" ]; then
    APP_PATH="$DEBUG_PATH"
else
    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "ClipFlow.app" -type d | grep -v "Index.noindex" | head -1)
fi

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
