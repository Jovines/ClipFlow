import Foundation
import OpenAI

final class OpenAIService {
    static let shared = OpenAIService()

    private var openAI: OpenAI?

    private init() {
        refreshClient()
    }

    private func refreshClient() {
        guard let apiKey = KeychainManager.openAIAPIKey, !apiKey.isEmpty else {
            openAI = nil
            return
        }
        let configuration = OpenAI.Configuration(token: apiKey)
        openAI = OpenAI(configuration: configuration)
    }

    func setAPIKey(_ key: String) throws {
        try KeychainManager.save(key, for: .openAIAPIKey)
        refreshClient()
    }

    func clearAPIKey() throws {
        try KeychainManager.remove(for: .openAIAPIKey)
        openAI = nil
    }

    var hasAPIKey: Bool {
        KeychainManager.openAIAPIKey != nil
    }

    func chat(message: String, model: Model = .gpt4_o) async throws -> String {
        guard let client = openAI else {
            throw OpenAIError.notConfigured
        }

        let query = ChatQuery(
            messages: [.user(.init(content: .string(message)))],
            model: model
        )
        let result = try await client.chats(query: query)
        return result.choices.first?.message.content ?? ""
    }

    func chatStream(message: String, model: Model = .gpt4_o) -> AsyncThrowingStream<String, Error> {
        guard let client = openAI else {
            return .init { throw OpenAIError.notConfigured }
        }

        let query = ChatQuery(
            messages: [.user(.init(content: .string(message)))],
            model: model
        )

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await chunk in client.chatsStream(query: query) {
                        if let content = chunk.choices.first?.delta.content {
                            continuation.yield(content)
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
    case streamFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return NSLocalizedString("Please configure OpenAI API Key in Settings first", comment: "OpenAI not configured error")
        case .streamFailed(let error):
            return NSLocalizedString("Stream request failed: \(error.localizedDescription)", comment: "Stream failed error")
        }
    }
}
