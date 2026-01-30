import Foundation
import KeychainAccess

enum KeychainManager {
    private static let service = "com.clipflow.app"
    private static let keychain = Keychain(service: service)
        .accessibility(.whenUnlockedThisDeviceOnly)

    enum Key: String {
        case openAIAPIKey = "openai_api_key"
    }

    static func save(_ value: String, for key: Key) throws {
        try keychain.set(value, key: key.rawValue)
    }

    static func get(for key: Key) -> String? {
        try? keychain.get(key.rawValue)
    }

    static func remove(for key: Key) throws {
        try keychain.remove(key.rawValue)
    }

    static var openAIAPIKey: String? {
        get {
            get(for: .openAIAPIKey)
        }
    }
}
