import SwiftUI
import ServiceManagement
import AppKit

struct TitleBarConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                window.titlebarAppearsTransparent = true
                window.backgroundColor = NSColor(Color.flexokiSurface)
            }
        }
    }
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case aiService = "AIService"
    case tags = "Tags"
    case cache = "Cache"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gear"
        case .aiService: return "brain"
        case .tags: return "tag"
        case .cache: return "internaldrive"
        case .about: return "info.circle"
        }
    }

    var localizedName: String {
        switch self {
        case .general: return NSLocalizedString("General", comment: "")
        case .aiService: return NSLocalizedString("AI 服务", comment: "")
        case .tags: return NSLocalizedString("Tags", comment: "")
        case .cache: return NSLocalizedString("Cache", comment: "")
        case .about: return NSLocalizedString("About", comment: "")
        }
    }
}

struct SettingsView: View {
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

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 140)
                .background(Color.flexokiSurface)

            contentView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 560, height: 440)
        .background(Color.flexokiPaper)
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
        .background(
            TitleBarConfigurator()
        )
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
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
            .padding(.top, 12)

            Spacer()
        }
    }

    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                switch selectedTab {
                case .general:
                    generalSettingsContent
                case .aiService:
                    AIProviderSettingsView()
                case .tags:
                    TagsManagementView()
                case .cache:
                    CacheManagementView()
                case .about:
                    AboutView()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .background(Color.flexokiPaper)
    }

    private var generalSettingsContent: some View {
        VStack(alignment: .leading, spacing: 24) {
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

struct AIProviderSettingsView: View {
    @StateObject private var service = OpenAIService.shared
    @State private var showPresetSheet = false
    @State private var showAddSheet = false
    @State private var editingProvider: AIProviderConfig?
    @State private var newProviderFromPreset: AIProviderConfig?
    @State private var testMessage = ""
    @State private var testResponse = ""
    @State private var isTesting = false

    private var providers: [AIProviderConfig] {
        service.availableProviders
    }

    private var currentSelection: AIProviderSelection? {
        service.currentProvider
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "brain")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                    Text("AI 服务商")
                        .font(.system(size: 14, weight: .semibold))
                }

                Text("配置和管理多个 AI 服务商，支持 OpenAI、Minimax、DeepSeek 等")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "server.rack")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 14))
                        Text("服务商列表")
                            .font(.system(size: 14, weight: .semibold))
                    }

                    Spacer()

                    Button {
                        showPresetSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }

                if providers.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 32))
                            .foregroundStyle(.tertiary)
                        Text("暂无服务商")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .background(Color.flexokiSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    VStack(spacing: 0) {
                        ForEach(providers) { provider in
                            ProviderRow(
                                provider: provider,
                                isSelected: currentSelection?.providerId == provider.id,
                                onSelect: { selectProvider(provider) },
                                onEdit: { editingProvider = provider },
                                onDelete: { deleteProvider(provider) }
                            )

                            if provider.id != providers.last?.id {
                                Divider()
                                    .padding(.leading, 40)
                            }
                        }
                    }
                    .background(Color.flexokiSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            Divider()

            if let selection = currentSelection,
               let provider = providers.first(where: { $0.id == selection.providerId }) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "cpu")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 14))
                        Text("模型选择")
                            .font(.system(size: 14, weight: .semibold))
                    }

                    Picker("模型", selection: Binding(
                        get: { selection.model },
                        set: { updateCurrentModel($0) }
                    )) {
                        ForEach(provider.models, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .pickerStyle(.menu)
                    .controlSize(.small)
                    .padding(12)
                    .background(Color.flexokiSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "testtube.2")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                    Text("测试连接")
                        .font(.system(size: 14, weight: .semibold))
                }

                VStack(spacing: 12) {
                    TextField("输入测试消息...", text: $testMessage)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.flexokiSurfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.flexokiBorder, lineWidth: 1)
                        )

                    Button("发送测试请求") {
                        testConnection()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(currentSelection == nil || testMessage.isEmpty || isTesting)

                    if !testResponse.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("响应:")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(testResponse)
                                .font(.system(size: 12))
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.flexokiSurfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
                .padding(12)
                .background(Color.flexokiSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Spacer()
        }
        .sheet(isPresented: $showPresetSheet) {
            ProviderPresetSheet { preset in
                showPresetSheet = false
                newProviderFromPreset = AIProviderConfig.fromPreset(preset)
                showAddSheet = true
            }
        }
        .sheet(isPresented: $showAddSheet) {
            if let presetProvider = newProviderFromPreset {
                ProviderEditSheet(provider: presetProvider, isNew: true) { newProvider in
                    addProvider(newProvider)
                    newProviderFromPreset = nil
                }
            }
        }
        .sheet(item: $editingProvider) { provider in
            ProviderEditSheet(provider: provider, isNew: false) { updated in
                updateProvider(updated)
            }
        }
    }

    private func selectProvider(_ provider: AIProviderConfig) {
        let selection = AIProviderSelection(
            providerId: provider.id,
            model: provider.defaultModel
        )
        service.currentProvider = selection
    }

    private func updateCurrentModel(_ model: String) {
        guard let selection = currentSelection else { return }
        let updated = AIProviderSelection(providerId: selection.providerId, model: model)
        service.currentProvider = updated
    }

    private func addProvider(_ provider: AIProviderConfig) {
        do {
            try service.updateProvider(provider)
        } catch {
            print("Failed to add provider: \(error)")
        }
    }

    private func updateProvider(_ provider: AIProviderConfig) {
        do {
            try service.updateProvider(provider)
        } catch {
            print("Failed to update provider: \(error)")
        }
    }

    private func deleteProvider(_ provider: AIProviderConfig) {
        do {
            try service.deleteProvider(id: provider.id)
        } catch {
            print("Failed to delete provider: \(error)")
        }
    }

    private func testConnection() {
        isTesting = true
        testResponse = ""

        Task {
            do {
                let response = try await service.chat(message: testMessage)
                await MainActor.run {
                    testResponse = response
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testResponse = "错误: \(error.localizedDescription)"
                    isTesting = false
                }
            }
        }
    }
}

struct ProviderRow: View {
    let provider: AIProviderConfig
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? .green : .secondary)
                .font(.system(size: 14))
                .onTapGesture { onSelect() }

            VStack(alignment: .leading, spacing: 2) {
                Text(provider.name)
                    .font(.system(size: 13))

                Text(provider.baseURL)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 6) {
                if !provider.apiKey.isEmpty {
                    Image(systemName: "checkmark.shield")
                        .foregroundStyle(.green)
                        .font(.system(size: 11))
                }

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
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background(isSelected ? Color.flexokiAccent.opacity(0.1) : Color.clear)
    }
}

struct ProviderPresetSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onSelect: (ProviderPreset) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("选择服务商")
                    .font(.headline)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()
                .padding(.horizontal, 20)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(ProviderPreset.allPresets) { preset in
                        PresetRow(preset: preset) {
                            onSelect(preset)
                            dismiss()
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 380, height: 520)
    }
}

struct PresetRow: View {
    let preset: ProviderPreset
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: preset.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(Color.flexokiAccent)
                    .frame(width: 36, height: 36)
                    .background(Color.flexokiSurfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.flexokiText)

                    Text(preset.description)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.flexokiSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.flexokiBorder.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ProviderEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    var provider: AIProviderConfig?
    var isNew: Bool
    var onSave: (AIProviderConfig) -> Void

    @State private var name = ""
    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var models = ""
    @State private var defaultModel = ""

    init(provider: AIProviderConfig? = nil, isNew: Bool = true, onSave: @escaping (AIProviderConfig) -> Void) {
        self.provider = provider
        self.isNew = isNew
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(isNew ? "添加服务商" : "编辑服务商")
                .font(.headline)

            VStack(spacing: 12) {
                TextField("名称 (如: OpenAI)", text: $name)
                    .textFieldStyle(.roundedBorder)

                TextField("Base URL (如: https://api.openai.com/v1)", text: $baseURL)
                    .textFieldStyle(.roundedBorder)

                SecureField("API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)

                TextField("模型列表 (用逗号分隔)", text: $models)
                    .textFieldStyle(.roundedBorder)

                TextField("默认模型", text: $defaultModel)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 12) {
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Button("保存") {
                    saveProvider()
                }
                .keyboardShortcut(.return, modifiers: [])
                .disabled(name.isEmpty || baseURL.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400, height: 300)
        .onAppear {
            if let p = provider {
                name = p.name
                baseURL = p.baseURL
                apiKey = p.apiKey
                models = p.models.joined(separator: ", ")
                defaultModel = p.defaultModel
            }
        }
    }

    private func saveProvider() {
        let modelList = models.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let provider = AIProviderConfig(
            id: provider?.id ?? UUID(),
            name: name,
            baseURL: baseURL,
            apiKey: apiKey,
            models: modelList.isEmpty ? [defaultModel] : modelList,
            defaultModel: defaultModel
        )
        onSave(provider)
        dismiss()
    }
}

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

            HStack(spacing: 8) {
                TextField("New tag name...", text: $newTagName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.flexokiSurfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.flexokiBorder, lineWidth: 1)
                    )

                Button("Add") {
                    addTag()
                }
                .disabled(newTagName.isEmpty)
                .controlSize(.small)
            }
            .padding(12)
            .background(Color.flexokiSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8))

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
                .textFieldStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.flexokiSurfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.flexokiBorder, lineWidth: 1)
                )

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
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "internaldrive")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 14))
                Text("Image Cache")
                    .font(.system(size: 14, weight: .semibold))
            }

            VStack(spacing: 16) {
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
            .background(Color.flexokiSurface)
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
        .background(Color.flexokiSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
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

            VStack(spacing: 0) {
                LinkRow(
                    icon: "globe",
                    title: "GitHub Repository",
                    url: URL(string: "https://github.com/Jovines/ClipFlow") ?? URL(string: "https://github.com")!
                )

                Divider()
                    .padding(.leading, 44)

                LinkRow(
                    icon: "exclamationmark.bubble",
                    title: "Report Issue",
                    url: URL(string: "https://github.com/Jovines/ClipFlow/issues") ?? URL(string: "https://github.com")!
                )
            }
            .background(Color.flexokiSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Spacer()

            Text("© 2026 ClipFlow. All rights reserved.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 8)
        }
    }
}

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
    SettingsView()
}
