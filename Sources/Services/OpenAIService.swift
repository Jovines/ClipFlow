import Foundation
import OpenAI

final class OpenAIService: ObservableObject, @unchecked Sendable {
    static let shared = OpenAIService()
    private let legacyCLIRegex = "(?s)(?:^>.*\\R+)?(.*)"
    private let deprecatedCLIRegexes: Set<String> = [
        "(?s)(?:^>.*\\R+)?(.*?)(?:\\R*<system-reminder>[\\s\\S]*?</system-reminder>)?\\s*$",
        "(?s)^(?:[ \\t]*\\n)*(?:>[^\\n]*\\n+)?(.*)$",
        ".*",
        "(?s).*",
        "(?s)(.*)"
    ]

    private var clients: [UUID: OpenAI] = [:]
    
    @Published private var _providers: [AIProviderConfig] = []
    @Published private var _currentProvider: AIProviderSelection?
    
    var currentProvider: AIProviderSelection? {
        get {
            _currentProvider
        }
        set {
            _currentProvider = newValue
            EncryptedStorage.currentSelection = newValue
        }
    }

    var availableProviders: [AIProviderConfig] {
        _providers
    }

    var hasAnyConfiguredProvider: Bool {
        _providers.contains { provider in
            switch provider.providerType {
            case .api:
                return !provider.apiKey.isEmpty
            case .cli:
                return !provider.cliCommandTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        }
    }

    var isServiceAvailable: Bool {
        guard let selection = currentProvider,
              let provider = _providers.first(where: { $0.id == selection.providerId }) else {
            return false
        }

        switch provider.providerType {
        case .api:
            return !provider.apiKey.isEmpty
        case .cli:
            return !provider.cliCommandTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private init() {
        loadFromKeychain()
        _currentProvider = EncryptedStorage.currentSelection
        refreshAllClients()
    }
    
    private func loadFromKeychain() {
        let loadedProviders = EncryptedStorage.providerConfigs
        var didMigrate = false
        let migratedProviders = loadedProviders.map { provider -> AIProviderConfig in
            guard provider.providerType == .cli else {
                return provider
            }

            let regexText = provider.cliOutputRegex.trimmingCharacters(in: .whitespacesAndNewlines)
            let shouldMigrateRegex = regexText == legacyCLIRegex || deprecatedCLIRegexes.contains(regexText)
            var updated = provider

            if shouldMigrateRegex {
                didMigrate = true
                updated.cliOutputRegex = CLIOutputDefaults.extractionRegex
            }

            let templateText = updated.cliOutputTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
            let usesDefaultRegex = updated.cliOutputRegex.trimmingCharacters(in: .whitespacesAndNewlines) == CLIOutputDefaults.extractionRegex
            let shouldMigrateTemplate = templateText.isEmpty ||
                (usesDefaultRegex && (templateText == "{{match}}" || templateText == "{{g0}}"))

            if shouldMigrateTemplate {
                didMigrate = true
                updated.cliOutputTemplate = CLIOutputDefaults.outputTemplate
            }
            return updated
        }

        if didMigrate {
            EncryptedStorage.providerConfigs = migratedProviders
        }

        _providers = migratedProviders
    }

    func refreshAllClients() {
        clients.removeAll()
        for provider in availableProviders where provider.providerType == .api && !provider.apiKey.isEmpty {
            guard let url = URL(string: provider.baseURL) else {
                continue
            }
            let host = url.host ?? provider.baseURL
            let basePath = url.path.isEmpty ? "/v1" : url.path
            let configuration = OpenAI.Configuration(
                token: provider.apiKey,
                host: host,
                scheme: url.scheme ?? "https",
                basePath: basePath
            )
            clients[provider.id] = OpenAI(configuration: configuration)
        }
    }

    func updateProvider(_ provider: AIProviderConfig) throws {
        var configs = _providers
        if let index = configs.firstIndex(where: { $0.id == provider.id }) {
            configs[index] = provider
        } else {
            configs.append(provider)
        }
        EncryptedStorage.providerConfigs = configs
        _providers = configs
        refreshAllClients()
    }

    func deleteProvider(id: UUID) throws {
        var configs = _providers
        configs.removeAll { $0.id == id }
        EncryptedStorage.providerConfigs = configs
        _providers = configs
        clients.removeValue(forKey: id)

        if currentProvider?.providerId == id {
            currentProvider = nil
        }
    }
    
    func refreshProviders() {
        loadFromKeychain()
        refreshAllClients()
    }

    func getClient(for providerId: UUID) -> OpenAI? {
        clients[providerId]
    }

    func testCLIConfiguration(
        commandTemplate: String,
        outputRegex: String,
        outputTemplate: String,
        input: String
    ) async throws -> String {
        let provider = AIProviderConfig(
            name: "CLI Test",
            providerType: .cli,
            baseURL: "",
            apiKey: "",
            models: [],
            defaultModel: "",
            cliCommandTemplate: commandTemplate,
            cliOutputRegex: outputRegex,
            cliOutputTemplate: outputTemplate
        )

        return try await chatViaCLI(message: input, provider: provider, timeoutSeconds: 12)
    }

    func chat(
        message: String,
        providerId: UUID? = nil,
        model: String? = nil
    ) async throws -> String {
        let targetProviderId = providerId ?? currentProvider?.providerId
        guard let pid = targetProviderId else {
            throw OpenAIError.notConfigured
        }

        let configs = availableProviders
        guard let config = configs.first(where: { $0.id == pid }) else {
            throw OpenAIError.providerNotFound
        }

        if config.providerType == .cli {
            return try await chatViaCLI(message: message, provider: config)
        }

        guard let client = clients[pid] else {
            throw OpenAIError.notConfigured
        }

        let selectedModel = currentProvider?.providerId == pid ? currentProvider?.model : nil
        let targetModel = model ?? selectedModel ?? config.defaultModel

        let query = ChatQuery(
            messages: [.user(.init(content: .string(message)))],
            model: targetModel
        )
        let result = try await client.chats(query: query)
        let rawContent = result.choices.first?.message.content ?? ""
        return AIResponseFilter.cleanThinkingTags(from: rawContent)
    }

    private func chatViaCLI(message: String, provider: AIProviderConfig, timeoutSeconds: Int = 45) async throws -> String {
        let command = try renderCLICommand(input: message, provider: provider)
        ClipFlowLogger.debug("[CLI] Executing command (timeout=\(timeoutSeconds)s): \(command.prefix(200))...")
        let result = try await PersistentShellSession.shared.execute(command: command, timeoutSeconds: timeoutSeconds)
        ClipFlowLogger.debug("[CLI] Raw output (len=\(result.output.count)): \(result.output.prefix(300))...")
        let extracted = try extractCLIOutput(from: result.output, provider: provider)
        ClipFlowLogger.debug("[CLI] Extracted output (len=\(extracted.count)): \(extracted.prefix(300))...")
        return AIResponseFilter.cleanThinkingTags(from: extracted)
    }

    func chatStream(
        message: String,
        providerId: UUID? = nil,
        model: String? = nil
    ) -> AsyncThrowingStream<String, Error> {
        let targetProviderId = providerId ?? currentProvider?.providerId
        guard let pid = targetProviderId else {
            return .init { throw OpenAIError.notConfigured }
        }

        let configs = availableProviders
        guard let config = configs.first(where: { $0.id == pid }) else {
            return .init { throw OpenAIError.providerNotFound }
        }

        if config.providerType == .cli {
            return AsyncThrowingStream { continuation in
                Task {
                    do {
                        let response = try await chatViaCLI(message: message, provider: config)
                        continuation.yield(response)
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            }
        }

        guard let client = clients[pid] else {
            return .init { throw OpenAIError.notConfigured }
        }

        let selectedModel = currentProvider?.providerId == pid ? currentProvider?.model : nil
        let targetModel = model ?? selectedModel ?? config.defaultModel

        let query = ChatQuery(
            messages: [.user(.init(content: .string(message)))],
            model: targetModel
        )

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    var buffer = ""
                    var yieldedLength = 0
                    
                    for try await chunk in client.chatsStream(query: query) {
                        if let content = chunk.choices.first?.delta.content {
                            buffer += content
                            
                            let cleaned = AIResponseFilter.cleanThinkingTags(from: buffer)
                            
                            if cleaned.count > yieldedLength {
                                let startIndex = cleaned.index(cleaned.startIndex, offsetBy: yieldedLength)
                                let newContent = String(cleaned[startIndex...])
                                continuation.yield(newContent)
                                yieldedLength = cleaned.count
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func renderCLICommand(input: String, provider: AIProviderConfig) throws -> String {
        let template = provider.cliCommandTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !template.isEmpty else {
            ClipFlowLogger.error("[CLI] Command template is empty")
            throw OpenAIError.notConfigured
        }

        let escapedInput = shellSingleQuoted(input)
        let command = template
            .replacingOccurrences(of: "{{input}}", with: escapedInput)
            .replacingOccurrences(of: "{{input_raw}}", with: input)
        ClipFlowLogger.debug("[CLI] Rendered command: \(command.prefix(200))...")
        return command
    }

    private func extractCLIOutput(from rawOutput: String, provider: AIProviderConfig) throws -> String {
        let normalizedOutput = normalizeCLIRawOutput(rawOutput)
        let matchSource = stripANSIEscapeCodes(in: normalizedOutput)
        let displaySource = matchSource
        ClipFlowLogger.debug("[CLI] Match source output (len=\(matchSource.count)): \(matchSource.prefix(300))...")

        let regexText = provider.cliOutputRegex.trimmingCharacters(in: .whitespacesAndNewlines)
        ClipFlowLogger.debug("[CLI] Using output regex: \(regexText)")
        guard !regexText.isEmpty else {
            ClipFlowLogger.debug("[CLI] No output regex configured, returning full output")
            return displaySource.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let regex = try? NSRegularExpression(pattern: regexText, options: []) else {
            ClipFlowLogger.error("[CLI] Invalid regex pattern: \(regexText)")
            throw OpenAIError.invalidRequest
        }

        let range = NSRange(matchSource.startIndex..., in: matchSource)
        guard let match = regex.firstMatch(in: matchSource, options: [], range: range) else {
            ClipFlowLogger.warning("[CLI] Regex did not match output. Returning full output.")
            return displaySource.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        ClipFlowLogger.debug("[CLI] Regex matched successfully")

        let template = provider.cliOutputTemplate
        ClipFlowLogger.debug("[CLI] Using output template: \(template)")
        if template.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let fallback = captureGroup(match: match, index: 1, in: matchSource)
                ?? captureGroup(match: match, index: 0, in: matchSource)
                ?? matchSource
            let final = stripANSIEscapeCodes(in: fallback)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return final.isEmpty ? displaySource.trimmingCharacters(in: .whitespacesAndNewlines) : final
        }

        var rendered = template
        let full = captureGroup(match: match, index: 0, in: matchSource) ?? ""
        rendered = rendered
            .replacingOccurrences(of: "{{match}}", with: full)
            .replacingOccurrences(of: "{{g0}}", with: full)

        for index in 1..<match.numberOfRanges {
            let token = "{{g\(index)}}"
            let value = captureGroup(match: match, index: index, in: matchSource) ?? ""
            rendered = rendered.replacingOccurrences(of: token, with: value)
        }

        let final = stripANSIEscapeCodes(in: rendered)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if final.isEmpty {
            ClipFlowLogger.warning("[CLI] Extracted output is empty after template. Returning full output.")
            return displaySource.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return final
    }

    private func normalizeCLIRawOutput(_ rawOutput: String) -> String {
        rawOutput
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    private func stripANSIEscapeCodes(in text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"\u001B\[[0-?]*[ -/]*[@-~]"#, options: []) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
    }

    private func captureGroup(match: NSTextCheckingResult, index: Int, in text: String) -> String? {
        guard index < match.numberOfRanges,
              let range = Range(match.range(at: index), in: text) else {
            return nil
        }
        return String(text[range])
    }

    private func shellSingleQuoted(_ text: String) -> String {
        if text.isEmpty { return "''" }
        return "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

enum OpenAIError: LocalizedError {
    case notConfigured
    case providerNotFound
    case streamFailed(Error)
    case invalidAPIKey
    case networkError
    case rateLimitExceeded
    case invalidRequest
    case modelNotFound

    var errorDescription: String? {
        switch self {
        case .notConfigured, .invalidAPIKey:
            "AI service is not configured or invalid. Please check AI Service settings.".localized()
        case .providerNotFound:
            "Provider not found".localized()
        case .streamFailed(let error):
            "Stream failed: %1$@".localized(error.localizedDescription)
        case .networkError:
            "Network connection failed. Please check your network settings and try again.".localized()
        case .rateLimitExceeded:
            "API rate limit reached. Please wait a moment or upgrade your quota.".localized()
        case .invalidRequest:
            "Invalid request parameters. Please check your AI provider settings.".localized()
        case .modelNotFound:
            "AI model does not exist. Please check the model name in your settings.".localized()
        }
    }
}

enum AIResponseFilter {
    
    private static let thinkingPattern = #"<think(?:ing)?>\s*[\s\S]*?\s*</think(?:ing)?>"#
    
    static func cleanThinkingTags(from content: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: thinkingPattern,
            options: [.caseInsensitive]
        ) else {
            return content
        }
        
        let range = NSRange(content.startIndex..., in: content)
        let cleanedContent = regex.stringByReplacingMatches(
            in: content,
            options: [],
            range: range,
            withTemplate: ""
        )
        
        return cleanedContent
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n\n\n", with: "\n\n")
    }
    
    static func containsThinkingTags(_ content: String) -> Bool {
        guard let regex = try? NSRegularExpression(
            pattern: thinkingPattern,
            options: [.caseInsensitive]
        ) else {
            return false
        }
        
        let range = NSRange(content.startIndex..., in: content)
        return regex.firstMatch(in: content, options: [], range: range) != nil
    }
}
