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
4. Create git tag and push
5. Upload to GitHub Release

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

Or run:
```bash
./run.sh
```

### 3. Create DMG

```bash
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "ClipFlow.app" -path "*/Release/ClipFlow.app" -type d | head -1)
hdiutil create -srcfolder "$APP_PATH" -volname "ClipFlow" ClipFlow.dmg
```

### 4. Create Release

```bash
# Create and push tag
git tag v<x.y.z>
git push origin v<x.y.z>

# Upload to GitHub
gh release create v<x.y.z> \
  --title "ClipFlow v<x.y.z>" \
  --notes "Release notes" \
  ClipFlow.dmg
```

## Version Convention

Follow Semantic Versioning: `MAJOR.MINOR.PATCH`
- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)
