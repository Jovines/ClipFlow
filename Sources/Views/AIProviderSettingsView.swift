import SwiftUI

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
