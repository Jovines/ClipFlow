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
