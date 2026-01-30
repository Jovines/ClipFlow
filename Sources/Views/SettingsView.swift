import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("shortcutKey") private var shortcutKey = "v"
    @AppStorage("useCommandKey") private var useCommandKey = true
    @AppStorage("useShiftKey") private var useShiftKey = true
    @AppStorage("maxHistoryItems") private var maxHistoryItems = 100
    @AppStorage("saveImages") private var saveImages = true
    @AppStorage("autoStart") private var autoStart = false

    @State private var showConflictAlert = false
    @State private var conflictMessage = ""
    @State private var autoStartStatus: AutoStartStatus = .unknown

    enum AutoStartStatus {
        case unknown
        case enabled
        case disabled
        case error(String)
    }

    var body: some View {
        TabView {
            GeneralSettingsView(
                shortcutKey: $shortcutKey,
                useCommandKey: $useCommandKey,
                useShiftKey: $useShiftKey,
                maxHistoryItems: $maxHistoryItems,
                saveImages: $saveImages,
                autoStart: $autoStart,
                autoStartStatus: $autoStartStatus,
                showConflictAlert: $showConflictAlert,
                conflictMessage: $conflictMessage
            )
            .tabItem {
                Label("General", systemImage: "gear")
            }

            TagsManagementView()
                .tabItem {
                    Label("Tags", systemImage: "tag")
                }

            CacheManagementView()
                .tabItem {
                    Label("Cache", systemImage: "internaldrive")
                }

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 520, height: 420)
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
}

struct GeneralSettingsView: View {
    @Binding var shortcutKey: String
    @Binding var useCommandKey: Bool
    @Binding var useShiftKey: Bool
    @Binding var maxHistoryItems: Int
    @Binding var saveImages: Bool
    @Binding var autoStart: Bool
    @Binding var autoStartStatus: SettingsView.AutoStartStatus
    @Binding var showConflictAlert: Bool
    @Binding var conflictMessage: String

    var body: some View {
        Form {
            Section("Shortcut") {
                Toggle("Use Command Key", isOn: $useCommandKey)
                Toggle("Use Shift Key", isOn: $useShiftKey)

                HStack {
                    Text("Action Key")
                    Spacer()
                    Text(shortcutKey.uppercased())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(NSColor.textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                Button("Apply Shortcut") {
                    applyShortcut()
                }
            }

            Section("History") {
                Stepper(value: $maxHistoryItems, in: 10...1000, step: 10) {
                    HStack {
                        Text("Max Items")
                        Spacer()
                        Text("\(maxHistoryItems)")
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle("Save Images", isOn: $saveImages)
            }

            Section("Launch") {
                Toggle("Start at Login", isOn: $autoStart)

                HStack {
                    Text("Status")
                    Spacer()
                    statusBadge
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch autoStartStatus {
        case .unknown:
            Text("Unknown")
                .foregroundStyle(.secondary)
        case .enabled:
            Text("Enabled")
                .foregroundStyle(.green)
        case .disabled:
            Text("Disabled")
                .foregroundStyle(.secondary)
        case .error(let message):
            Text("Error: \(message)")
                .foregroundStyle(.red)
                .font(.caption)
        }
    }

    private func applyShortcut() {
        var modifiers: NSEvent.ModifierFlags = []
        if useCommandKey { modifiers.insert(.command) }
        if useShiftKey { modifiers.insert(.shift) }

        let keyCode: UInt16 = shortcutKey.utf16.first ?? 0

        let shortcut = Shortcut(keyCode: keyCode, modifiers: modifiers)

        if shortcut.isValid && !shortcut.modifiers.isEmpty {
            if HotKeyManager.shared.register(shortcut) {
            } else {
                conflictMessage = "Unable to register this shortcut. It may be in use by another application."
                showConflictAlert = true
            }
        } else {
            conflictMessage = "Please include at least one modifier key (Command, Shift, Control, or Option)."
            showConflictAlert = true
        }
    }
}

struct TagsManagementView: View {
    @State private var tags: [Tag] = []
    @State private var newTagName = ""
    @State private var editingTag: Tag?
    @State private var showEditSheet = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("New Tag...", text: $newTagName)
                    .textFieldStyle(.plain)
                Button("Add") {
                    addTag()
                }
                .disabled(newTagName.isEmpty)
            }
            .padding()

            Divider()

            List {
                ForEach(tags) { tag in
                    HStack {
                        Circle()
                            .fill(colorForName(tag.color))
                            .frame(width: 12, height: 12)
                        Text(tag.name)
                        Spacer()
                        Button(action: { editTag(tag) }) {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        Button(action: { removeTag(tag) }) {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red)
                    }
                }
                .onDelete(perform: deleteTags)
            }
            .listStyle(.inset)
        }
        .tabItem {
            Label("Tags", systemImage: "tag")
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
        let tagEntities = PersistenceController.shared.fetchAllTags()
        tags = tagEntities.compactMap { entity -> Tag? in
            guard let name = entity.value(forKey: "name") as? String,
                  let color = entity.value(forKey: "color") as? String,
                  let id = entity.value(forKey: "id") as? UUID else {
                return nil
            }
            return Tag(id: id, name: name, color: color)
        }
    }

    private func addTag() {
        let entity = PersistenceController.shared.createTag(name: newTagName, color: "blue")
        if let tag = mapTagEntity(entity) {
            tags.append(tag)
        }
        newTagName = ""
    }

    private func removeTag(_ tag: Tag) {
        if let entity = PersistenceController.shared.fetchTag(byId: tag.id) {
            PersistenceController.shared.deleteTag(entity)
        }
        tags.removeAll { $0.id == tag.id }
    }

    private func deleteTags(at offsets: IndexSet) {
        for index in offsets {
            let tag = tags[index]
            if let entity = PersistenceController.shared.fetchTag(byId: tag.id) {
                PersistenceController.shared.deleteTag(entity)
            }
        }
        tags.remove(atOffsets: offsets)
    }

    private func editTag(_ tag: Tag) {
        editingTag = tag
        showEditSheet = true
    }

    private func updateTag(_ oldTag: Tag, with newTag: Tag) {
        if let entity = PersistenceController.shared.fetchTag(byId: oldTag.id) {
            PersistenceController.shared.updateTagName(entity, name: newTag.name)
            PersistenceController.shared.updateTagColor(entity, color: newTag.color)
        }
        if let index = tags.firstIndex(where: { $0.id == oldTag.id }) {
            tags[index] = newTag
        }
    }

    private func mapTagEntity(_ entity: NSManagedObject) -> Tag? {
        guard let name = entity.value(forKey: "name") as? String,
              let color = entity.value(forKey: "color") as? String,
              let id = entity.value(forKey: "id") as? UUID else {
            return nil
        }
        return Tag(id: id, name: name, color: color)
    }

    private func colorForName(_ name: String) -> Color {
        Color.fromHex(Tag.colorForName(name))
    }
}

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

struct CacheManagementView: View {
    @State private var cacheSize: Int64 = 0
    @State private var itemCount: Int = 0
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Image Cache")
                        .font(.headline)
                    Text("\(itemCount) items")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(formattedCacheSize)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Divider()

            Button("Clear Cache", role: .destructive) {
                clearCache()
            }
            .disabled(isLoading)

            Spacer()
        }
        .padding()
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

struct AboutView: View {
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }

                Link("GitHub Repository", destination: URL(string: "https://github.com/clipflow/clipflow") ?? URL(string: "https://github.com")!)

                Link("Report Issue", destination: URL(string: "https://github.com/clipflow/clipflow/issues") ?? URL(string: "https://github.com")!)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

#Preview {
    SettingsView()
}
