---
name: release
description: MUST USE when releasing, versioning, creating releases, git tags, changelog, version bump, or GitHub releases. Handles ClipFlow build, DMG creation, and release workflow.
license: MIT
compatibility: opencode
metadata:
  audience: maintainers
  workflow: local
---

## What I do

This skill guides you through the complete release process for ClipFlow:

1. Update version numbers in `project.yml`
2. Commit and push version changes
3. Build Release configuration (using `build` instead of `archive` to avoid SwiftLint blocking)
4. Sign with Developer ID certificate
5. Create DMG disk image
6. **Sign DMG with Sparkle EdDSA** (for automatic updates)
7. Submit to Apple Notarization
8. Staple notarization ticket
9. Generate release notes from commits (feat/fix)
10. Create git tag and push
11. Upload to GitHub Release
12. **Update appcast.xml** (for automatic updates)

## When to use me

Use this when releasing a new version of ClipFlow. The skill will prompt for version number if not provided.

## Prerequisites

Before releasing, ensure you have:

1. **Developer ID Certificate**: Created in Xcode → Settings → Accounts → Manage Certificates → "+" → Developer ID Application
2. **App Store Connect API Key**: Created at https://appstoreconnect.apple.com/access/api (role: Admin)
   - Download .p8 file
   - Note Key ID and Issuer ID
   - Store API key at `scripts/AuthKey.p8`
3. **Sparkle EdDSA Key**: Generated during auto-update setup
   - Public key is in `Info.plist` as `SUPublicEDKey`
   - Private key is stored at `scripts/sparkle_private_key.txt` (not in git, see `.gitignore`)
4. **create-dmg**: Install via Homebrew for user-friendly DMG with Applications link
   ```bash
   brew install create-dmg
   ```

## Important Notes

- Always use `xcodebuild build` instead of `archive` for Release builds
- SwiftLint errors will cause `archive` to fail, but `build` succeeds
- Always run `xcodegen generate` BEFORE committing version changes
- Notarization is REQUIRED for Gatekeeper to allow users to run the app directly
- Without notarization, users must manually approve the app in System Settings

## Release Steps

1. Update version in `project.yml`
2. Run `xcodegen generate` (modifies project.pbxproj)
3. Commit and push version changes + xcodegen output
4. Build Release (use `build` command)
5. Resign app with timestamp (required for notarization)
6. Create DMG
7. Sign DMG with Developer ID
8. Submit to Apple Notarization
9. Staple notarization ticket
10. Generate release notes from commits
11. Create git tag and push to GitHub
12. Verify release

### 1. Update Version

Edit `project.yml`:
```yaml
settings:
  base:
    MARKETING_VERSION: "x.y.z"
    CURRENT_PROJECT_VERSION: "n"
```

### 2. Run xcodegen and Commit

```bash
# Generate Xcode project (modifies project.pbxproj)
xcodegen generate

# Stage version and xcodegen changes
git add project.yml ClipFlow.xcodeproj/

# Commit with conventional format (English only)
git commit -m "chore: bump version to v<x.y.z>"

# Push to remote
git push origin main
```

### 3. Build Release

```bash
xcodegen generate
xcodebuild -project ClipFlow.xcodeproj -scheme ClipFlow -configuration Release build
```

The Release build will be at:
`~/Library/Developer/Xcode/DerivedData/.../Build/Products/Release/ClipFlow.app`

### 4. Resign with Timestamp

Resign the app with a secure timestamp (required for notarization):
```bash
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "ClipFlow.app" -path "*/Release/ClipFlow.app" -type d | head -1)
codesign --force --sign "Developer ID Application: Your Name (TEAM_ID)" --timestamp --entitlements Resources/ClipFlow.entitlements --options=runtime --deep "$APP_PATH"
```

**Important**: Use `--deep` to sign all nested binaries inside Sparkle.framework (Autoupdate, Updater, Downloader, Installer).

### 5. Create DMG

Use `create-dmg` to create a user-friendly DMG with an Applications folder link for easy drag-and-drop installation:

```bash
# Check if create-dmg is installed
if ! command -v create-dmg &> /dev/null; then
    echo "Error: create-dmg is not installed."
    echo "Install it with: brew install create-dmg"
    exit 1
fi

APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "ClipFlow.app" -path "*/Release/ClipFlow.app" -type d | head -1)
create-dmg \
  --volname "ClipFlow" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --icon "ClipFlow.app" 200 190 \
  --hide-extension "ClipFlow.app" \
  --app-drop-link 600 185 \
  --no-internet-enable \
  ClipFlow.dmg \
  "$APP_PATH"
```

The DMG will include:
- `ClipFlow.app` - The application
- `Applications` link - Drag apps here to install (standard macOS convention)

### 6. Sign DMG

Sign with Apple Developer ID:
```bash
codesign --force --sign "Developer ID Application: Your Name (TEAM_ID)" --timestamp ClipFlow.dmg
```

### 7. Sign DMG with Sparkle EdDSA

**Important**: Do this BEFORE notarization, as notarization modifies the DMG.

```bash
# Download Sparkle tools (if not already available)
SPARKLE_VERSION="2.8.1"
curl -L -o /tmp/sparkle.tar.xz "https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz"
tar -xf /tmp/sparkle.tar.xz -C /tmp

# Sign the DMG using private key file
/tmp/bin/sign_update -f scripts/sparkle_private_key.txt ClipFlow.dmg > /tmp/sparkle_sig.txt
cat /tmp/sparkle_sig.txt
```

Save the output - you'll need the `sparkle:edSignature` and `length` values for the appcast.

### 8. Notarize (REQUIRED)

Using the notarization script:
```bash
./scripts/notarize.sh ClipFlow.dmg scripts/AuthKey.p8 KEY_ID ISSUER_ID
```

Example:
```bash
./scripts/notarize.sh ClipFlow.dmg scripts/AuthKey.p8 TZJ6FHT528 39497853-d795-468a-88a2-af5206568006
```

Or manually:
```bash
# Submit
xcrun notarytool submit ClipFlow.dmg -k scripts/AuthKey.p8 -d KEY_ID -i ISSUER_ID --wait

# Staple
xcrun stapler staple ClipFlow.dmg
```

### 9. Verify

```bash
# Check signature
codesign -dv --verbose=4 ClipFlow.app

# Check Gatekeeper acceptance
spctl -a -vvv ClipFlow.dmg
```

### 10. Generate Release Notes

Ask OpenCode to review commits since the last release and summarize:
- New features (commits with "feat:")
- Bug fixes (commits with "fix:")
- Other notable changes

Example prompt:
```
Review commits since v<x.y> and summarize the changes for release notes. List new features, bug fixes, and other changes.
```

### 11. Create Release

```bash
# Create and push tag
git tag v<x.y.z>
git push origin v<x.y.z>

# Upload to GitHub with release notes
gh release create v<x.y.z> \
  --title "ClipFlow v<x.y.z>" \
  --notes "## What's New

[Summary from OpenCode]" \
  ClipFlow.dmg
```

### 12. Update Appcast

Update `appcast.xml` so existing users receive the update:

```bash
# Get values from step 7
SIGNATURE=$(cat /tmp/sparkle_sig.txt | grep -o 'sparkle:edSignature="[^"]*"' | cut -d'"' -f2)
LENGTH=$(cat /tmp/sparkle_sig.txt | grep -o 'length="[^"]*"' | cut -d'"' -f2)

# Clone gh-pages branch
git fetch origin gh-pages
git checkout gh-pages

# Update appcast.xml with new release item
# Add this item at the top (after <!-- Add new release items here at the top -->):
cat > /tmp/new_item.txt << EOF
        <item>
            <title>Version x.y.z</title>
            <sparkle:version>BUILD_NUMBER</sparkle:version>
            <sparkle:shortVersionString>x.y.z</sparkle:shortVersionString>
            <pubDate>$(date -u +"%a, %d %b %Y %H:%M:%S +0000")</pubDate>
            <enclosure url="https://github.com/jovines/ClipFlow/releases/download/vx.y.z/ClipFlow.dmg"
                       sparkle:edSignature="${SIGNATURE}"
                       length="${LENGTH}"
                       type="application/octet-stream" />
        </item>
EOF

cat /tmp/new_item.txt
# Now manually edit appcast.xml to add this item

# Commit and push
git add appcast.xml
git commit -m "chore: update appcast for vx.y.z"
git push origin gh-pages

# Switch back to main
git checkout main
```

**Appcast URL**: `https://jovines.github.io/ClipFlow/appcast.xml`

### 13. Verify Release

Check the release on GitHub:
```bash
gh release view v<x.y.z>
```

## Version Convention

Follow Semantic Versioning: `MAJOR.MINOR.PATCH`
- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

## Troubleshooting

### Notarization Fails with "get-task-allow" error

This means the app was signed with a development certificate. Re-sign with:
```bash
codesign --force --sign "Developer ID Application: Your Name (TEAM_ID)" --timestamp --options=runtime "$APP_PATH"
```

### Notarization Fails with "secure timestamp" error

Ensure you use `--timestamp` when signing:
```bash
codesign --force --sign "Developer ID Application: Your Name (TEAM_ID)" --timestamp "$APP_PATH"
```

### Gatekeeper still warns users

Ensure you stapled the notarization ticket:
```bash
xcrun stapler staple ClipFlow.dmg
```

### Automatic updates not working

1. **Check appcast URL**: Verify `SUFeedURL` in `Info.plist` matches `https://jovines.github.io/ClipFlow/appcast.xml`
2. **Check signature**: Ensure the signature in appcast.xml matches the output from step 7
3. **Check version numbers**: `sparkle:version` must use build number (integer), not marketing version
4. **Test manually**: Use "Check for Updates Now" in Settings → Update
