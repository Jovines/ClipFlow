import SwiftUI

struct ProviderEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var aiService = OpenAIService.shared

    var provider: AIProviderConfig?
    var isNew: Bool
    var onSave: (AIProviderConfig) -> Void

    @State private var name = ""
    @State private var providerType: AIProviderType = .api
    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var models = ""
    @State private var defaultModel = ""
    @State private var cliCommandTemplate = CLIOutputDefaults.commandTemplate
    @State private var cliOutputRegex = CLIOutputDefaults.extractionRegex
    @State private var cliOutputTemplate = CLIOutputDefaults.outputTemplate
    @State private var cliTestInput = ""
    @State private var cliTestResult = ""
    @State private var isTestingCLI = false

    private var canSave: Bool {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        switch providerType {
        case .api:
            return !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .cli:
            return !cliCommandTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var providerTypeDescription: String {
        switch providerType {
        case .api:
            return "API mode: call remote OpenAI-compatible services with Base URL + API Key.".localized
        case .cli:
            return "CLI mode: run a local command and extract answer text from command output.".localized
        }
    }

    init(provider: AIProviderConfig? = nil, isNew: Bool = true, onSave: @escaping (AIProviderConfig) -> Void) {
        self.provider = provider
        self.isNew = isNew
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(isNew ? "Add Provider".localized() : "Edit Provider".localized())
                .font(.headline)

            ScrollView {
                VStack(spacing: 12) {
                    TextField("Name (e.g.: OpenAI)".localized(), text: $name)
                        .textFieldStyle(.roundedBorder)

                    Picker("Provider Type".localized(), selection: $providerType) {
                        ForEach(AIProviderType.allCases, id: \.rawValue) { type in
                            Text(type == .api ? "API Mode".localized() : "CLI Mode".localized()).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(providerTypeDescription)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if providerType == .api {
                        Text("Base URL: provider endpoint, such as https://api.openai.com/v1".localized)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        TextField("Base URL (e.g.: https://api.openai.com/v1)".localized(), text: $baseURL)
                            .textFieldStyle(.roundedBorder)

                        Text("API Key: credential used to authorize requests.".localized)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        SecureField("API Key".localized(), text: $apiKey)
                            .textFieldStyle(.roundedBorder)

                        Text("Model List: available models separated by commas.".localized)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        TextField("Model List (comma-separated)".localized(), text: $models)
                            .textFieldStyle(.roundedBorder)

                        Text("Default Model: model used when no model is explicitly specified.".localized)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        TextField("Default Model".localized(), text: $defaultModel)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        Text("CLI Command Template: use {{input}} for shell-escaped prompt, {{input_raw}} for raw text.".localized)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        TextField("CLI Command Template".localized(), text: $cliCommandTemplate)
                            .textFieldStyle(.roundedBorder)

                        Text("Output Extraction Regex: first regex match is used from stdout/stderr output.".localized)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        TextField("Output Extraction Regex".localized(), text: $cliOutputRegex)
                            .textFieldStyle(.roundedBorder)

                        Text("Output Template: use {{match}}/{{g0}}/{{g1}}... to build the final response.".localized)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        TextField("Output Template".localized(), text: $cliOutputTemplate)
                            .textFieldStyle(.roundedBorder)

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Test CLI Configuration".localized)
                                .font(.system(size: 12, weight: .semibold))

                            TextField("Test Input".localized(), text: $cliTestInput)
                                .textFieldStyle(.roundedBorder)

                            HStack(spacing: 10) {
                                Button(isTestingCLI ? "Testing...".localized : "Run Test".localized) {
                                    runCLITest()
                                }
                                .buttonStyle(.bordered)
                                .disabled(isTestingCLI || cliTestInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                                if isTestingCLI {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                            }

                            if !cliTestResult.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Test Result".localized)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.secondary)
                                    Text(cliTestResult)
                                        .font(.system(size: 11))
                                        .padding(8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(NSColor.textBackgroundColor).opacity(0.45))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 2)
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
                .disabled(!canSave)
            }
        }
        .padding(24)
        .frame(width: 520, height: 560)
        .onAppear {
            if let p = provider {
                name = p.name
                providerType = p.providerType
                baseURL = p.baseURL
                apiKey = p.apiKey
                models = p.models.joined(separator: ", ")
                defaultModel = p.defaultModel
                cliCommandTemplate = p.cliCommandTemplate
                cliOutputRegex = p.cliOutputRegex
                cliOutputTemplate = p.cliOutputTemplate
            }
        }
    }

    private func saveProvider() {
        let modelList = models.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let provider = AIProviderConfig(
            id: provider?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            providerType: providerType,
            baseURL: providerType == .api ? baseURL : "",
            apiKey: providerType == .api ? apiKey : "",
            models: providerType == .api ? (modelList.isEmpty ? [defaultModel] : modelList) : [],
            defaultModel: providerType == .api ? defaultModel : "",
            cliCommandTemplate: providerType == .cli ? cliCommandTemplate : CLIOutputDefaults.commandTemplate,
            cliOutputRegex: providerType == .cli ? cliOutputRegex : "",
            cliOutputTemplate: providerType == .cli ? cliOutputTemplate : ""
        )
        onSave(provider)
        dismiss()
    }

    private func runCLITest() {
        let trimmedInput = cliTestInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return }

        ClipFlowLogger.debug("[ProviderEdit] Starting CLI test with input: \(trimmedInput.prefix(100))...")
        isTestingCLI = true
        cliTestResult = ""

        Task {
            do {
                let result = try await aiService.testCLIConfiguration(
                    commandTemplate: cliCommandTemplate,
                    outputRegex: cliOutputRegex,
                    outputTemplate: cliOutputTemplate,
                    input: trimmedInput
                )
                ClipFlowLogger.debug("[ProviderEdit] CLI test succeeded, result len=\(result.count)")
                await MainActor.run {
                    cliTestResult = result
                    isTestingCLI = false
                }
            } catch {
                ClipFlowLogger.error("[ProviderEdit] CLI test failed: \(error)")
                await MainActor.run {
                    cliTestResult = "Test Connection Error: %1$@".localized(error.localizedDescription)
                    isTestingCLI = false
                }
            }
        }
    }
}
