import Foundation
import OpenAI

final class OpenAIService: ObservableObject, @unchecked Sendable {
    static let shared = OpenAIService()

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
        _providers.contains { !$0.apiKey.isEmpty }
    }

    private init() {
        loadFromKeychain()
        _currentProvider = EncryptedStorage.currentSelection
        refreshAllClients()
    }
    
    private func loadFromKeychain() {
        _providers = EncryptedStorage.providerConfigs
    }

    func refreshAllClients() {
        clients.removeAll()
        for provider in availableProviders where !provider.apiKey.isEmpty {
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

    func chat(
        message: String,
        providerId: UUID? = nil,
        model: String? = nil
    ) async throws -> String {
        let targetProviderId = providerId ?? currentProvider?.providerId
        guard let pid = targetProviderId,
              let client = clients[pid] else {
            throw OpenAIError.notConfigured
        }

        let configs = availableProviders
        guard let config = configs.first(where: { $0.id == pid }) else {
            throw OpenAIError.providerNotFound
        }

        let targetModel = model ?? currentProvider?.model ?? config.defaultModel

        let query = ChatQuery(
            messages: [.user(.init(content: .string(message)))],
            model: targetModel
        )
        let result = try await client.chats(query: query)
        let rawContent = result.choices.first?.message.content ?? ""
        return AIResponseFilter.cleanThinkingTags(from: rawContent)
    }

    func chatStream(
        message: String,
        providerId: UUID? = nil,
        model: String? = nil
    ) -> AsyncThrowingStream<String, Error> {
        let targetProviderId = providerId ?? currentProvider?.providerId
        guard let pid = targetProviderId,
              let client = clients[pid] else {
            return .init { throw OpenAIError.notConfigured }
        }

        let configs = availableProviders
        guard let config = configs.first(where: { $0.id == pid }) else {
            return .init { throw OpenAIError.providerNotFound }
        }

        let targetModel = model ?? currentProvider?.model ?? config.defaultModel

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
            "AI service is not configured or invalid. Please check your API Key in settings.".localized()
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
