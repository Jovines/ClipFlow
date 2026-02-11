import SwiftUI

struct AIProviderSettingsView: View {
    @StateObject private var service = OpenAIService.shared
    @State private var showPresetSheet = false
    @State private var pendingPreset: ProviderPreset?
    @State private var editingProvider: AIProviderConfig?
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
            headerSection
            Divider()
            providerListSection
            Divider()
            if let selection = currentSelection,
               let provider = providers.first(where: { $0.id == selection.providerId }) {
                modelSelectionSection(for: provider, selection: selection)
                Divider()
            }
            testConnectionSection
            Spacer()
        }
        .sheet(isPresented: $showPresetSheet) {
            ProviderPresetSheet { preset in
                showPresetSheet = false
                pendingPreset = preset
            }
        }
        .sheet(item: $pendingPreset) { preset in
            ProviderEditSheet(
                provider: AIProviderConfig.fromPreset(preset),
                isNew: true
            ) { newProvider in
                addProvider(newProvider)
                pendingPreset = nil
            }
        }
        .sheet(item: $editingProvider) { provider in
            ProviderEditSheet(provider: provider, isNew: false) { updated in
                updateProvider(updated)
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "brain")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 14))
                Text("AI Service".localized())
                    .font(.system(size: 14, weight: .semibold))
            }

            Text("Configure and manage multiple AI service providers, supporting OpenAI, Minimax, DeepSeek and more".localized())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var providerListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "server.rack")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                    Text("Provider List".localized())
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
                emptyProviderView
            } else {
                providerListView
            }
        }
    }

    private var emptyProviderView: some View {
        VStack(spacing: 8) {
            Image(systemName: "server.rack")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("No providers yet".localized())
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(ThemeManager.shared.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var providerListView: some View {
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
        .background(ThemeManager.shared.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func modelSelectionSection(for provider: AIProviderConfig, selection: AIProviderSelection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "cpu")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 14))
                Text("Model Selection".localized())
                    .font(.system(size: 14, weight: .semibold))
            }

            Picker("Model".localized(), selection: Binding(
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
            .background(ThemeManager.shared.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var testConnectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "testtube.2")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 14))
                Text("Test Connection".localized())
                    .font(.system(size: 14, weight: .semibold))
            }

            VStack(spacing: 12) {
                TextField("Enter test message...".localized(), text: $testMessage)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ThemeManager.shared.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(ThemeManager.shared.border, lineWidth: 1)
                    )

                Button("Send Test Request".localized()) {
                    testConnection()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(currentSelection == nil || testMessage.isEmpty || isTesting)

                if !testResponse.isEmpty {
                    testResponseView
                }
            }
            .padding(12)
            .background(ThemeManager.shared.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var testResponseView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Response:".localized())
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(testResponse)
                .font(.system(size: 12))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ThemeManager.shared.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 6))
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
