import SwiftUI
import ServiceManagement

// MARK: - Settings Tab Enum

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case openai = "OpenAI"
    case tags = "Tags"
    case cache = "Cache"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gear"
        case .openai: return "brain"
        case .tags: return "tag"
        case .cache: return "internaldrive"
        case .about: return "info.circle"
        }
    }

    var localizedName: String {
        switch self {
        case .general: return NSLocalizedString("General", comment: "")
        case .openai: return NSLocalizedString("OpenAI", comment: "")
        case .tags: return NSLocalizedString("Tags", comment: "")
        case .cache: return NSLocalizedString("Cache", comment: "")
        case .about: return NSLocalizedString("About", comment: "")
        }
    }
}

// MARK: - Main Settings View

struct SettingsView: View {
    let onClose: (() -> Void)?

    @AppStorage("maxHistoryItems") private var maxHistoryItems = 100
    @AppStorage("saveImages") private var saveImages = true
    @AppStorage("autoStart") private var autoStart = false

    @State private var shortcut = Shortcut.defaultShortcut
    @State private var showConflictAlert = false
    @State private var conflictMessage = ""
    @State private var autoStartStatus: AutoStartStatus = .unknown
    @State private var selectedTab: SettingsTab = .general

    enum AutoStartStatus {
        case unknown
        case enabled
        case disabled
        case error(String)
    }

    init(onClose: (() -> Void)? = nil) {
        self.onClose = onClose
    }

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            sidebar
                .frame(width: 140)
                .background(Color.flexokiSurface)

            // Content
            contentView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 560, height: 440)
        .alert("Shortcut Conflict", isPresented: $showConflictAlert) {
            Button("OK") {}
        } message: {
            Text(conflictMessage)
        }
        .onAppear {
            checkAutoStartStatus()
        }
        .onChange(of: autoStart) { _, newValue in
            setAutoStart(newValue)
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            // Title area
            HStack {
                Text("Settings")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()
                .padding(.horizontal, 12)

            // Tab buttons
            VStack(spacing: 2) {
                ForEach(SettingsTab.allCases) { tab in
                    SidebarTabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        action: { selectedTab = tab }
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            Spacer()
        }
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                Spacer()
                Button(action: { onClose?() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Tab content
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    switch selectedTab {
                    case .general:
                        generalSettingsContent
                    case .openai:
                        OpenAISettingsView()
                    case .tags:
                        TagsManagementView()
                    case .cache:
                        CacheManagementView()
                    case .about:
                        AboutView()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - General Settings Content

    private var generalSettingsContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Shortcut Section
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "keyboard")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                    Text("Global Shortcut")
                        .font(.system(size: 14, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Click to record a new shortcut")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ShortcutRecorderView(shortcut: Binding(
                        get: { shortcut },
                        set: { newShortcut in
                            shortcut = newShortcut
                            applyShortcut(newShortcut)
                        }
                    ))
                }
                .padding(12)
                .background(Color.flexokiSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Divider()

            // History Section
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                    Text("History")
                        .font(.system(size: 14, weight: .semibold))
                }

                VStack(spacing: 12) {
                    HStack {
                        Text("Max Items")
                            .font(.system(size: 13))
                        Spacer()
                        Text("\(maxHistoryItems)")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                    }

                    Slider(value: Binding(
                        get: { Double(maxHistoryItems) },
                        set: { maxHistoryItems = Int($0) }
                    ), in: 10...1000, step: 10)
                    .controlSize(.small)

                    Toggle(isOn: $saveImages) {
                        HStack(spacing: 6) {
                            Image(systemName: "photo")
                                .font(.system(size: 12))
                            Text("Save Images")
                                .font(.system(size: 13))
                        }
                    }
                    .toggleStyle(.checkbox)
                }
                .padding(12)
                .background(Color.flexokiSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Divider()

            // Launch Section
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "power")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                    Text("Launch")
                        .font(.system(size: 14, weight: .semibold))
                }

                VStack(spacing: 12) {
                    Toggle(isOn: $autoStart) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.forward.circle")
                                .font(.system(size: 12))
                            Text("Start at Login")
                                .font(.system(size: 13))
                        }
                    }
                    .toggleStyle(.checkbox)

                    HStack {
                        Text("Status")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        Spacer()
                        statusBadge
                    }
                }
                .padding(12)
                .background(Color.flexokiSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Spacer()
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch autoStartStatus {
        case .unknown:
            Text("Unknown")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.gray.opacity(0.2))
                .clipShape(Capsule())
        case .enabled:
            Text("Enabled")
                .font(.system(size: 11))
                .foregroundStyle(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.green.opacity(0.15))
                .clipShape(Capsule())
        case .disabled:
            Text("Disabled")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.gray.opacity(0.2))
                .clipShape(Capsule())
        case .error(let message):
            Text("Error")
                .font(.system(size: 11))
                .foregroundStyle(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.red.opacity(0.15))
                .clipShape(Capsule())
                .help(message)
        }
    }

    private func checkAutoStartStatus() {
        if SMAppService.mainApp.status == .enabled {
            autoStartStatus = .enabled
        } else {
            autoStartStatus = .disabled
        }
    }

    private func setAutoStart(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                autoStartStatus = .enabled
            } else {
                try SMAppService.mainApp.unregister()
                autoStartStatus = .disabled
            }
        } catch {
            autoStartStatus = .error(error.localizedDescription)
            ClipFlowLogger.error("Failed to set auto-start: \(error.localizedDescription)")
        }
    }

    private func applyShortcut(_ newShortcut: Shortcut) {
        if newShortcut.isValid && !newShortcut.modifiers.isEmpty {
            if !HotKeyManager.shared.register(newShortcut) {
                conflictMessage = "Unable to register this shortcut. It may be in use by another application."
                showConflictAlert = true
            }
        } else {
            conflictMessage = "Please include at least one modifier key (Command, Shift, Control, or Option)."
            showConflictAlert = true
        }
    }
}

// MARK: - OpenAI Settings View

struct OpenAISettingsView: View {
    @State private var apiKeyInput = ""
    @State private var showAPIKeyField = false
    @State private var saveStatus: String?
    @State private var isSaving = false
    @State private var testMessage = ""
    @State private var testResponse = ""
    @State private var isTesting = false

    private var hasAPIKey: Bool {
        OpenAIService.shared.hasAPIKey
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "brain")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                    Text("OpenAI API")
                        .font(.system(size: 14, weight: .semibold))
                }

                Text("Configure your OpenAI API key to enable AI-powered features")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // API Key Section
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "key")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                    Text("API Key")
                        .font(.system(size: 14, weight: .semibold))
                }

                VStack(spacing: 12) {
                    if hasAPIKey && !showAPIKeyField {
                        HStack {
                            Label("API Key 已配置", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.green)

                            Spacer()

                            Button("重新设置") {
                                showAPIKeyField = true
                            }
                            .buttonStyle(.link)
                            .font(.system(size: 13))
                        }
                    } else {
                        SecureField("sk-...", text: $apiKeyInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13))

                        HStack {
                            Button("保存") {
                                saveAPIKey()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(apiKeyInput.isEmpty || isSaving)

                            if hasAPIKey {
                                Button("取消") {
                                    showAPIKeyField = false
                                    apiKeyInput = ""
                                }
                                .buttonStyle(.borderless)
                                .controlSize(.small)
                            }
                        }

                        if let status = saveStatus {
                            Text(status)
                                .font(.caption)
                                .foregroundStyle(status.contains("成功") ? .green : .red)
                        }
                    }
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Divider()

            // Test Section
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "testtube.2")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                    Text("Test Connection")
                        .font(.system(size: 14, weight: .semibold))
                }

                VStack(spacing: 12) {
                    TextField("Test message...", text: $testMessage)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))

                    Button("Send Test Request") {
                        testConnection()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!hasAPIKey || testMessage.isEmpty || isTesting)

                    if !testResponse.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Response:")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(testResponse)
                                .font(.system(size: 12))
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(NSColor.textBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Spacer()
        }
        .onAppear {
            if hasAPIKey {
                showAPIKeyField = false
                apiKeyInput = ""
            } else {
                showAPIKeyField = true
            }
        }
    }

    private func saveAPIKey() {
        isSaving = true
        saveStatus = nil

        do {
            try OpenAIService.shared.setAPIKey(apiKeyInput)
            saveStatus = "保存成功"
            showAPIKeyField = false
            apiKeyInput = ""
        } catch {
            saveStatus = "保存失败: \(error.localizedDescription)"
        }

        isSaving = false
    }

    private func testConnection() {
        isTesting = true
        testResponse = ""

        Task {
            do {
                let response = try await OpenAIService.shared.chat(message: testMessage)
                await MainActor.run {
                    testResponse = response
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testResponse = "Error: \(error.localizedDescription)"
                    isTesting = false
                }
            }
        }
    }
}

// MARK: - Sidebar Tab Button

struct SidebarTabButton: View {
    let tab: SettingsTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: tab.icon)
                    .font(.system(size: 13))
                    .frame(width: 18, height: 18)

                Text(tab.localizedName)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))

                Spacer()
            }
                    .foregroundStyle(isSelected ? Color.flexokiPaper : Color.flexokiText)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isSelected ? Color.flexokiAccent : Color.clear)
                    )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tags Management View

struct TagsManagementView: View {
    @State private var tags: [Tag] = []
    @State private var newTagName = ""
    @State private var editingTag: Tag?
    @State private var showEditSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "tag")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 14))
                Text("Manage Tags")
                    .font(.system(size: 14, weight: .semibold))
            }

            // Add new tag
            HStack(spacing: 8) {
                TextField("New tag name...", text: $newTagName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))

                Button("Add") {
                    addTag()
                }
                .disabled(newTagName.isEmpty)
                .controlSize(.small)
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Tags list
            if tags.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tag.slash")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("No tags yet")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text("Create tags to organize your clipboard items")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, minHeight: 150)
                .background(Color.flexokiSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                VStack(spacing: 0) {
                    ForEach(tags) { tag in
                        TagRow(
                            tag: tag,
                            onEdit: { editTag(tag) },
                            onDelete: { removeTag(tag) }
                        )

                        if tag.id != tags.last?.id {
                            Divider()
                                .padding(.leading, 40)
                        }
                    }
                }
                .padding(8)
                .background(Color.flexokiSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Spacer()
        }
        .sheet(isPresented: $showEditSheet) {
            if let tag = editingTag {
                EditTagSheet(tag: tag) { updatedTag in
                    updateTag(tag, with: updatedTag)
                }
            }
        }
        .onAppear {
            loadTags()
        }
    }

    private func loadTags() {
        do {
            tags = try DatabaseManager.shared.fetchAllTags()
        } catch {
            ClipFlowLogger.error("Failed to load tags: \(error)")
            tags = []
        }
    }

    private func addTag() {
        do {
            let tag = try DatabaseManager.shared.createTag(name: newTagName, color: "blue")
            tags.append(tag)
            newTagName = ""
        } catch {
            ClipFlowLogger.error("Failed to add tag: \(error)")
        }
    }

    private func removeTag(_ tag: Tag) {
        do {
            try DatabaseManager.shared.deleteTag(id: tag.id)
            tags.removeAll { $0.id == tag.id }
        } catch {
            ClipFlowLogger.error("Failed to remove tag: \(error)")
        }
    }

    private func editTag(_ tag: Tag) {
        editingTag = tag
        showEditSheet = true
    }

    private func updateTag(_ oldTag: Tag, with newTag: Tag) {
        do {
            try DatabaseManager.shared.updateTagName(id: oldTag.id, name: newTag.name)
            try DatabaseManager.shared.updateTagColor(id: oldTag.id, color: newTag.color)
            if let index = tags.firstIndex(where: { $0.id == oldTag.id }) {
                tags[index] = newTag
            }
        } catch {
            ClipFlowLogger.error("Failed to update tag: \(error)")
        }
    }
}

// MARK: - Tag Row

struct TagRow: View {
    let tag: Tag
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.fromHex(Tag.colorForName(tag.color)))
                .frame(width: 10, height: 10)

            Text(tag.name)
                .font(.system(size: 13))

            Spacer()

            HStack(spacing: 4) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

// MARK: - Edit Tag Sheet

struct EditTagSheet: View {
    let tag: Tag
    let onSave: (Tag) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var selectedColor: String

    init(tag: Tag, onSave: @escaping (Tag) -> Void) {
        self.tag = tag
        self.onSave = onSave
        _name = State(initialValue: tag.name)
        _selectedColor = State(initialValue: tag.color)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Tag")
                .font(.headline)

            TextField("Tag Name", text: $name)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 8) {
                Text("Color")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    ForEach(Tag.availableColors, id: \.name) { color in
                        Circle()
                            .fill(Color.fromHex(color.hex))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary, lineWidth: selectedColor == color.name ? 2 : 0)
                            )
                            .onTapGesture {
                                selectedColor = color.name
                            }
                    }
                }
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Button("Save") {
                    let updatedTag = Tag(id: tag.id, name: name, color: selectedColor)
                    onSave(updatedTag)
                    dismiss()
                }
                .disabled(name.isEmpty)
                .keyboardShortcut(KeyEquivalent.return, modifiers: [])
            }
        }
        .padding(24)
        .frame(width: 320, height: 240)
    }
}

// MARK: - Cache Management View

struct CacheManagementView: View {
    @State private var cacheSize: Int64 = 0
    @State private var itemCount: Int = 0
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "internaldrive")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 14))
                Text("Image Cache")
                    .font(.system(size: 14, weight: .semibold))
            }

            VStack(spacing: 16) {
                // Stats cards
                HStack(spacing: 12) {
                    StatCard(
                        icon: "photo.stack",
                        title: "Items",
                        value: "\(itemCount)"
                    )

                    StatCard(
                        icon: "memorychip",
                        title: "Size",
                        value: formattedCacheSize
                    )
                }

                Divider()

                // Clear button
                Button(role: .destructive) {
                    clearCache()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                        Text("Clear Cache")
                    }
                }
                .disabled(isLoading)
                .controlSize(.regular)
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Spacer()
        }
        .onAppear {
            loadCacheInfo()
        }
    }

    private var formattedCacheSize: String {
        if cacheSize < 1024 {
            return "\(cacheSize) B"
        } else if cacheSize < 1024 * 1024 {
            return String(format: "%.1f KB", Double(cacheSize) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(cacheSize) / (1024.0 * 1024.0))
        }
    }

    private func loadCacheInfo() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let size = ImageCacheManager.shared.cacheSize()
            let count = ImageCacheManager.shared.itemCount()
            DispatchQueue.main.async {
                self.cacheSize = size
                self.itemCount = count
                self.isLoading = false
            }
        }
    }

    private func clearCache() {
        ImageCacheManager.shared.clearCache()
        loadCacheInfo()
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - About View

struct AboutView: View {
    var body: some View {
        VStack(spacing: 0) {
            // App icon area
            VStack(spacing: 16) {
                // App icon placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [Color.flexokiAccent.opacity(0.8), Color.flexokiAccent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                .frame(width: 80, height: 80)
                .shadow(color: Color.flexokiAccent.opacity(0.3), radius: 10, x: 0, y: 4)

                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(Color.flexokiPaper)
                }

                VStack(spacing: 4) {
                    Text("ClipFlow")
                        .font(.system(size: 20, weight: .bold))

                    Text("Version 1.0.0")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)

            // Links
            VStack(spacing: 0) {
                LinkRow(
                    icon: "globe",
                    title: "GitHub Repository",
                    url: URL(string: "https://github.com/clipflow/clipflow") ?? URL(string: "https://github.com")!
                )

                Divider()
                    .padding(.leading, 44)

                LinkRow(
                    icon: "exclamationmark.bubble",
                    title: "Report Issue",
                    url: URL(string: "https://github.com/clipflow/clipflow/issues") ?? URL(string: "https://github.com")!
                )
            }
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Spacer()

            Text("© 2026 ClipFlow. All rights reserved.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 8)
        }
    }
}

// MARK: - Link Row

struct LinkRow: View {
    let icon: String
    let title: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)

                Text(title)
                    .font(.system(size: 13))

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView(onClose: {})
}
