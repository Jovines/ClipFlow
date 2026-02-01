# Agent Guidelines for ClipFlow

ClipFlow is a macOS menu bar clipboard manager built with Swift 5.9, SwiftUI, and XcodeGen.

## Build Commands

```bash
# Generate Xcode project (if xcodegen not installed: brew install xcodegen)
xcodegen generate

# Build and verify
xcodebuild -project ClipFlow.xcodeproj -scheme ClipFlow build

# Run (separate terminal for logs)
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "ClipFlow.app" -path "*/Debug/ClipFlow.app" -type d | head -1)
"$APP_PATH/Contents/MacOS/ClipFlow"
```

## Code Verification

After completing a logical unit of work (feature, bug fix, refactoring), compile to verify:

```bash
xcodebuild -project ClipFlow.xcodeproj -scheme ClipFlow build
```

Do NOT build after every code change—only after completing a task. Fix errors before marking complete.

## Code Style

### Naming
- Types: `PascalCase` (`ClipboardItem`, `OpenAIService`)
- Variables/Constants: `camelCase` (`clipboardItems`, `apiKey`)
- Acronyms: `APIKey` (not `ApiKey`)
- Booleans: `isEnabled`, `hasContent`

### SwiftUI Views
- Use `some View` return type
- Prefix private `@State`/`@StateObject` with `_` (`_clipboardMonitor`)
- View structs: `View` suffix (`ContentView`, `SettingsView`)
- Reusable components: `Component` suffix (`SearchBar`, `TagFilterBar`)

### Access Control
- Prefer `private` over `fileprivate`
- Use `final` on classes

### Error Handling
- Use `enum` conforming to `LocalizedError`
- Provide `errorDescription` for user-facing messages

### Async/Await
- Prefer `async/await` over completion handlers
- Create `Task` for concurrent work
- Avoid `@MainActor` unless view updates require it

### Database (GRDB)
- Conform to `FetchableRecord` and `PersistableRecord`
- Use `Columns` enum for type-safe column access
- Define `databaseTableName`

### Project Structure
```
Sources/
├── App/              # App entry point
├── Models/           # Data models
├── Persistence/      # Database managers
├── Services/         # Business logic
└── Views/            # SwiftUI views
    └── Components/   # Reusable UI components
```
