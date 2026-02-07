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
6. Submit to Apple Notarization
7. Staple notarization ticket
8. Generate release notes from commits (feat/fix)
9. Create git tag and push
10. Upload to GitHub Release

## When to use me

Use this when releasing a new version of ClipFlow. The skill will prompt for version number if not provided.

## Prerequisites

Before releasing, ensure you have:

1. **Developer ID Certificate**: Created in Xcode → Settings → Accounts → Manage Certificates → "+" → Developer ID Application
2. **App Store Connect API Key**: Created at https://appstoreconnect.apple.com/access/api (role: Admin)
   - Download .p8 file
   - Note Key ID and Issuer ID
   - Store API key at `scripts/AuthKey.p8`

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
codesign --force --sign "Developer ID Application: Your Name (TEAM_ID)" --timestamp --entitlements Resources/ClipFlow.entitlements --options=runtime "$APP_PATH"
```

### 5. Create DMG

```bash
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "ClipFlow.app" -path "*/Release/ClipFlow.app" -type d | head -1)
hdiutil create -srcfolder "$APP_PATH" -volname "ClipFlow" ClipFlow.dmg
```

### 6. Sign DMG

```bash
codesign --force --sign "Developer ID Application: Your Name (TEAM_ID)" --timestamp ClipFlow.dmg
```

### 7. Notarize (REQUIRED)

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

### 8. Verify

```bash
# Check signature
codesign -dv --verbose=4 ClipFlow.app

# Check Gatekeeper acceptance
spctl -a -vvv ClipFlow.dmg
```

### 9. Generate Release Notes

Ask OpenCode to review commits since the last release and summarize:
- New features (commits with "feat:")
- Bug fixes (commits with "fix:")
- Other notable changes

Example prompt:
```
Review commits since v<x.y> and summarize the changes for release notes. List new features, bug fixes, and other changes.
```

### 10. Create Release

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

### 11. Verify Release

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
