# Agent Guidelines for ClipFlow

This document provides guidelines for AI agents working on the ClipFlow codebase.

## Project Overview

ClipFlow is a macOS menu bar clipboard manager app built with Swift 5.9, SwiftUI, and XcodeGen. It uses GRDB for SQLite persistence, OpenAI for AI features, and KeychainAccess for secure storage.

## Build Commands

### Development Build & Run
**Warning**: This command will launch the app and block until you manually quit it. If you want to see logs while the app runs, run the app separately after building.

```bash
# Option 1: Build and run (blocks terminal until app is quit)
./run.sh

# Option 2: Build only, then run app manually for logs
xcodegen generate
xcodebuild -project ClipFlow.xcodeproj -scheme ClipFlow build
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "ClipFlow.app" -path "*/Debug/ClipFlow.app" -type d | head -1)
"$APP_PATH/Contents/MacOS/ClipFlow"  # Run in background or separate terminal for logs
```

This script:
- Regenerates `.xcodeproj` if `project.yml` changed
- Resolves Swift Package dependencies
- Builds the project
- Launches the app

### Manual Build Commands
```bash
# Generate Xcode project (if xcodegen is not installed, install via: brew install xcodegen)
xcodegen generate

# Resolve dependencies
xcodebuild -project ClipFlow.xcodeproj -scheme ClipFlow -resolvePackageDependencies

# Build debug
xcodebuild -project ClipFlow.xcodeproj -scheme ClipFlow build

# Build release
xcodebuild -project ClipFlow.xcodeproj -scheme ClipFlow -configuration Release build
```

### Run from DerivedData
```bash
# Find and run the built app
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "ClipFlow.app" -path "*/Debug/ClipFlow.app" -type d | head -1)
"$APP_PATH/Contents/MacOS/ClipFlow"
```

## Linting

### SwiftLint
SwiftLint is configured and runs as a post-build script. Install via: `brew install swiftlint`

```bash
swiftlint
```

Configuration is in `.swiftlint.yml`:
- Disabled: `trailing_whitespace`, `line_length`, `identifier_name`
- Opt-in: `empty_count`, `closure_spacing`

## Code Style Guidelines

### Naming Conventions
- **Types** (classes, structs, enums): PascalCase (`ClipboardItem`, `OpenAIService`)
- **Variables, constants, parameters**: camelCase (`clipboardItems`, `apiKey`)
- **Private/internal properties**: prefix with `_` only when needed for disambiguation
- **Acronyms**: maintain consistent capitalization (e.g., `APIKey`, not `ApiKey`)
- **Booleans**: use adjective form (`isEnabled`, `hasContent`)

### SwiftUI Views
- Use `some View` return type for view builders
- Prefix `@State`, `@StateObject` properties with underscore convention when private (`_clipboardMonitor`)
- Use `View` suffix for view structs (`ContentView`, `SettingsView`)
- Use `Component` suffix for reusable components (`SearchBar`, `TagFilterBar`)

### Access Control
- Prefer `private` over `fileprivate`
- Use `internal` (default) for public API
- Mark `public` only when necessary for package integration
- Use `final` on classes not meant for inheritance

### Error Handling
- Use `enum` conforming to `LocalizedError` for domain-specific errors
- Provide `errorDescription` for user-facing messages
- Use `throw` and `try` for recoverable errors
- Use `Result` type for completion handlers where appropriate
- Wrap async errors with descriptive context

### Async/Await
- Prefer `async/await` over completion handlers
- Use `AsyncThrowingStream` for streaming responses
- Create `Task` for spawning concurrent work
- Avoid `@MainActor` unless view updates require it

### Database (GRDB)
- Types conforming to `FetchableRecord` and `PersistableRecord`
- Use `Columns` enum for type-safe column access
- Define `databaseTableName` on persistable types
- Use `Codable` for serialization compatibility

### Project Structure
```
Sources/
├── App/              # App entry point, delegates
├── Models/           # Data models (ClipboardItem, Tag)
├── Persistence/      # Database managers
├── Services/         # Business logic (ClipboardMonitor, OpenAIService)
└── Views/            # SwiftUI views
    └── Components/   # Reusable UI components
```

### Imports
- Group imports: Foundation, SwiftUI, third-party, project
- Use explicit imports (avoid `@testable` in production code)
- One import per line

### Formatting
- Use 4 spaces for indentation
- No trailing whitespace (disabled in SwiftLint)
- Keep line length reasonable (80 char max warning)
- Use closure spacing (`{ }`)
- Add documentation comments for public APIs

### Property Observers
- Use `didSet` and `willSet` for side effects
- Keep property observer logic minimal

### Type Inference
- Allow type inference for obvious cases
- Use explicit types for ambiguous cases or protocol conformances

## Key Dependencies
- **GRDB**: v6.29.3+ (SQLite database)
- **OpenAI**: main branch (OpenAI API client)
- **KeychainAccess**: v4.2.2+ (secure storage)

## Configuration Files
- `project.yml`: XcodeGen configuration
- `.swiftlint.yml`: SwiftLint rules
- `Resources/Info.plist`: app configuration
- `Resources/ClipFlow.entitlements`: capability declarations
