# Agent Guidelines for ClipFlow

ClipFlow is a macOS menu bar clipboard manager built with Swift 6.0, SwiftUI, and XcodeGen.

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

#### UUID Storage Type Consistency
**Requirement**: When using UUID as a primary key or foreign key, explicitly encode it as TEXT in `encode(to:)`:

```swift
func encode(to container: inout PersistenceContainer) throws {
    container[Columns.id] = id.uuidString  // Required: Force TEXT storage
}
```

**Why**: GRDB defaults to BLOB storage for UUID. When table columns are defined as `TEXT`, BLOB vs TEXT type mismatch causes JOIN queries to fail silently.

**Verification**: Run `SELECT typeof(column_name) FROM table_name LIMIT 1` to confirm storage type is `text`, not `blob`.

#### SwiftUI Hit Testing
- When adding `onTapGesture` to container views (`VStack`, `HStack`, `Group`), always add `.contentShape(Rectangle())` before the gesture modifier to ensure the entire view area responds to clicks, not just areas with content
- Place `.contentShape(Rectangle())` on the outermost view that should respond to taps, not on nested child views
- This prevents the common issue where tapping empty/padding areas does not trigger the gesture

## Project Structure
```
Sources/
├── App/              # App entry point
├── Models/           # Data models
├── Persistence/      # Database managers
├── Services/         # Business logic
└── Views/            # SwiftUI views
    └── Components/   # Reusable UI components
```

## Skills

For specialized workflows, load the appropriate skill:
- **Release**: Use `release` skill for versioning, builds, and GitHub releases
- **UI/Colors**: Use `flexoki` skill for SwiftUI color scheme and styling
- **Skill Development**: Use `skill-creation` skill for creating/modifying skills

## Commit Messages

- **CRITICAL: Use English for ALL commit messages** - This is a project standard, violations will be requested to amend
- Follow **Conventional Commits** format: `<type>: <description>`
- Types: `feat`, `fix`, `chore`, `refactor`, `perf`, `docs`, `update`, `revert`
- Keep description concise and clear
- Before committing, always verify the commit message is in English

## Code Signing & Notarization

### Developer ID Signing

For direct distribution (outside Mac App Store), the app must be signed with a Developer ID certificate:

```bash
# Verify certificates
security find-identity -v -p codesigning

# Build Release with signing
xcodebuild -project ClipFlow.xcodeproj -scheme ClipFlow -configuration Release build
```

### Notarization (Required for Gatekeeper)

**Without notarization**: Users will see a Gatekeeper warning and must manually approve the app in System Settings > Privacy & Security.

**With notarization**: Users can run the app directly with no warnings.

#### Setup App Store Connect API Key

1. Go to https://appstoreconnect.apple.com/access/api
2. Click "+" to generate a new API key
3. Role: Admin
4. Download the .p8 file (can only be downloaded once)
5. Note the Key ID and Issuer ID

#### Notarization Workflow

```bash
# 1. Build and sign Release
xcodegen generate
xcodebuild -project ClipFlow.xcodeproj -scheme ClipFlow -configuration Release build

# 2. Create DMG
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "ClipFlow.app" -path "*/Release/ClipFlow.app" -type d | head -1)
hdiutil create -srcfolder "$APP_PATH" -volname "ClipFlow" ClipFlow.dmg

# 3. Submit for notarization
./scripts/notarize.sh ClipFlow.dmg AuthKey_ABC123.p8 ABC123DEF456 12345678-1234-1234-1234-123456789012

# 4. Verify
spctl -a -vvv ClipFlow.dmg
```

The notarization script (`scripts/notarize.sh`) handles:
- Submitting the DMG to Apple for security verification
- Waiting for approval (typically 1-5 minutes)
- Stapling the notarization ticket to the DMG