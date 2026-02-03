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
2. Commit and push version changes
3. Build Release configuration (using `build` instead of `archive` to avoid SwiftLint blocking)
4. Create DMG disk image
5. Generate release notes from commits (feat/fix)
6. Create git tag and push
7. Upload to GitHub Release

## When to use me

Use this when releasing a new version of ClipFlow. The skill will prompt for version number if not provided.

## Important Note

Always use `xcodebuild build` instead of `xcodebuild archive` for Release builds. SwiftLint errors will cause `archive` to fail, but `build` succeeds (linting warnings don't block the build).

Before releasing, always run `git status` to check for any uncommitted changes (like `project.pbxproj` from `xcodegen generate`) that should be included.

## Release Steps

1. Update version in `project.yml`
2. Commit and push version changes
3. Build Release (use `build` command)
4. Create DMG disk image
5. Generate release notes from commits
6. Create git tag and push to GitHub
7. Verify release

### 1. Update Version

Edit `project.yml`:
```yaml
settings:
  base:
    MARKETING_VERSION: "x.y.z"
    CURRENT_PROJECT_VERSION: "n"
```

### 2. Commit Version Update

```bash
# Stage version changes and xcodegen output
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

Note: Use `build` instead of `archive` because SwiftLint errors will cause `archive` to fail, but `build` succeeds (warnings don't block the build).

### 4. Create DMG

```bash
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "ClipFlow.app" -path "*/Release/ClipFlow.app" -type d | head -1)
hdiutil create -srcfolder "$APP_PATH" -volname "ClipFlow" ClipFlow.dmg
```

### 5. Generate Release Notes

Ask OpenCode to review commits since the last release and summarize:
- New features (commits with "feat:")
- Bug fixes (commits with "fix:")
- Other notable changes

Example prompt:
```
Review commits since v<x.y> and summarize the changes for release notes. List new features, bug fixes, and other changes.
```

### 6. Create Release

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

### 7. Verify Release

Check the release on GitHub:
```bash
gh release view v<x.y.z>
```

## Version Convention

Follow Semantic Versioning: `MAJOR.MINOR.PATCH`
- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)
