---
name: release-project
description: Release new versions of ClipFlow locally - build, create dmg, and push to GitHub
license: MIT
compatibility: opencode
metadata:
  audience: maintainers
  workflow: local
---

## What I do

This skill guides you through the complete release process for ClipFlow:

1. Update version numbers in `project.yml`
2. Build Release configuration
3. Create DMG disk image
4. Generate release notes from commits (feat/fix)
5. Create git tag and push
6. Upload to GitHub Release

## When to use me

Use this when releasing a new version of ClipFlow. The skill will prompt for version number if not provided.

## Release Steps

### 1. Update Version

Edit `project.yml`:
```yaml
settings:
  base:
    MARKETING_VERSION: "x.y.z"
    CURRENT_PROJECT_VERSION: "n"
```

### 2. Build Release

```bash
xcodegen generate
xcodebuild -project ClipFlow.xcodeproj -scheme ClipFlow -configuration Release archive
```

The archive will be at:
`~/Library/Developer/Xcode/DerivedData/.../Build/Products/Release/ClipFlow.app`

### 3. Create DMG

```bash
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "ClipFlow.app" -path "*/Release/ClipFlow.app" -type d | head -1)
hdiutil create -srcfolder "$APP_PATH" -volname "ClipFlow" ClipFlow.dmg
```

### 4. Generate Release Notes

Generate changelog from commits since last release:

```bash
# Get previous version tag
PREV_TAG=$(git tag -l "v*" --sort=-version:refname | head -2 | tail -1)

# Extract features (feat:) and fixes (fix:)
FEATURES=$(git log $PREV_TAG..HEAD --oneline --grep="feat" | sed 's/.*/ - /')
FIXES=$(git log $PREV_TAG..HEAD --onetime --grep="fix" | sed 's/.*/ - /')

# Build release notes
cat <<EOF
## What's New

### Features
${FEATURES:-None}

### Bug Fixes
${FIXES:-None}

### Other Changes
$(git log $PREV_TAG..HEAD --oneline --grep -v "feat" --grep -v "fix")
EOF
```

### 5. Create Release

```bash
# Create and push tag
git tag v<x.y.z>
git push origin v<x.y.z>

# Upload to GitHub with release notes
gh release create v<x.y.z> \
  --title "ClipFlow v<x.y.z>" \
  --notes "## What's New

### Features
- New feature 1
- New feature 2

### Bug Fixes
- Fix issue 1
- Fix issue 2" \
  ClipFlow.dmg
```

## Version Convention

Follow Semantic Versioning: `MAJOR.MINOR.PATCH`
- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)
