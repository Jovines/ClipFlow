import SwiftUI

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
            Text(isNew ? "Add Provider".localized() : "Edit Provider".localized())
                .font(.headline)

            VStack(spacing: 12) {
                TextField("Name (e.g.: OpenAI)".localized(), text: $name)
                    .textFieldStyle(.roundedBorder)

                TextField("Base URL (e.g.: https://api.openai.com/v1)".localized(), text: $baseURL)
                    .textFieldStyle(.roundedBorder)

                SecureField("API Key".localized(), text: $apiKey)
                    .textFieldStyle(.roundedBorder)

                TextField("Model List (comma-separated)".localized(), text: $models)
                    .textFieldStyle(.roundedBorder)

                TextField("Default Model".localized(), text: $defaultModel)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 12) {
                Button("Cancel".localized()) {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Button("Save".localized()) {
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
