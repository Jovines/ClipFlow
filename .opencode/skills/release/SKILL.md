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

Complete release workflow:
1. Update version → xcodegen → commit
2. Build Release → resign
3. Create DMG → sign with Developer ID + Sparkle EdDSA
4. Notarize → staple
5. Create GitHub Release → update appcast

## When to use me

Releasing a new version of ClipFlow. Skill will prompt for version number if not provided.

## Prerequisites

1. **Developer ID Certificate**: Xcode → Settings → Accounts → Manage Certificates → "+" → Developer ID Application
2. **App Store Connect API Key**: https://appstoreconnect.apple.com/access/api (role: Admin)
   - Download .p8, store at `scripts/AuthKey.p8`
3. **Sparkle EdDSA Key**: `scripts/sparkle_private_key.txt` (not in git)
4. **create-dmg**: `brew install create-dmg`

## Release Steps

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
xcodegen generate
git add project.yml ClipFlow.xcodeproj/
git commit -m "chore: bump version to v<x.y.z>"
git push origin main
```

### 3. Build Release

```bash
xcodegen generate
xcodebuild -project ClipFlow.xcodeproj -scheme ClipFlow -configuration Release build
```

### 4. Resign with Timestamp

```bash
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "ClipFlow.app" -path "*/Release/ClipFlow.app" -type d | head -1)
codesign --force --sign "Developer ID Application: Your Name (TEAM_ID)" --timestamp --entitlements Resources/ClipFlow.entitlements --options=runtime --deep "$APP_PATH"
```

### 5. Create DMG

```bash
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

### 6. Sign DMG with Developer ID

```bash
codesign --force --sign "Developer ID Application: Your Name (TEAM_ID)" --timestamp ClipFlow.dmg
```

### 7. Sign DMG with Sparkle EdDSA

```bash
SPARKLE_VERSION="2.8.1"
curl -L -o /tmp/sparkle.tar.xz "https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz"
tar -xf /tmp/sparkle.tar.xz -C /tmp
/tmp/bin/sign_update -f scripts/sparkle_private_key.txt ClipFlow.dmg > /tmp/sparkle_sig.txt
cat /tmp/sparkle_sig.txt
```

### 8. Notarize

```bash
./scripts/notarize.sh ClipFlow.dmg scripts/AuthKey.p8 KEY_ID ISSUER_ID
```

### 9. Verify

```bash
codesign -dv --verbose=4 ClipFlow.app
spctl -a -vvv ClipFlow.dmg
```

### 10. Generate Release Notes

Review commits since last release (feat: and fix:), summarize changes.

### 11. Create Release

```bash
git tag v<x.y.z>
git push origin v<x.y.z>
gh release create v<x.y.z> --title "ClipFlow v<x.y.z>" --notes "## What's New..." ClipFlow.dmg
```

### 12. Update Appcast

```bash
SIGNATURE=$(cat /tmp/sparkle_sig.txt | grep -o 'sparkle:edSignature="[^"]*"' | cut -d'"' -f2)
LENGTH=$(cat /tmp/sparkle_sig.txt | grep -o 'length="[^"]*"' | cut -d'"' -f2)
git fetch origin gh-pages
git checkout gh-pages
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
git add appcast.xml
git commit -m "chore: update appcast for vx.y.z"
git push origin gh-pages
git checkout main
```

## Version Convention

Semantic Versioning: `MAJOR.MINOR.PATCH`
- **MAJOR**: Breaking changes
- **MINOR**: New features
- **PATCH**: Bug fixes

## Troubleshooting

### Notarization Fails with "get-task-allow"

```bash
codesign --force --sign "Developer ID Application: Your Name (TEAM_ID)" --timestamp --options=runtime "$APP_PATH"
```

### Notarization Fails with "secure timestamp"

```bash
codesign --force --sign "Developer ID Application: Your Name (TEAM_ID)" --timestamp "$APP_PATH"
```

### Gatekeeper warns users

```bash
xcrun stapler staple ClipFlow.dmg
```

### Automatic updates not working

1. Check `SUFeedURL` in `Info.plist`
2. Verify signature in appcast.xml
3. `sparkle:version` must use build number (integer)
4. Test: Settings → "Check for Updates Now"
