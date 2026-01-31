import Foundation
import CryptoKit

final class EncryptedStorage {
    private static let fileName = "provider_configs.encrypted"
    private static var fileURL: URL {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let appDir = supportDir.appendingPathComponent("ClipFlow", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent(fileName)
    }

    private static let selectionFileName = "provider_selection.encrypted"

    private static var selectionFileURL: URL {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let appDir = supportDir.appendingPathComponent("ClipFlow", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent(selectionFileName)
    }

    private static let keyFileName = "encryption.key"

    private static var keyFileURL: URL {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let appDir = supportDir.appendingPathComponent("ClipFlow", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent(keyFileName)
    }

    private static var key: SymmetricKey {
        if let keyData = try? Data(contentsOf: keyFileURL), keyData.count == 32 {
            return SymmetricKey(data: keyData)
        }

        let newKey = SymmetricKey(size: .bits256)
        let newKeyData = newKey.withUnsafeBytes { Data($0) }
        try? newKeyData.write(to: keyFileURL, options: .atomic)
        return newKey
    }

    static var providerConfigs: [AIProviderConfig] {
        get {
            guard let data = try? Data(contentsOf: fileURL) else {
                return []
            }

            do {
                let sealedBox = try AES.GCM.SealedBox(combined: data)
                let decryptedData = try AES.GCM.open(sealedBox, using: key)
                let configs = try JSONDecoder().decode([AIProviderConfig].self, from: decryptedData)
                return configs
            } catch {
                return []
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                let sealedBox = try AES.GCM.seal(data, using: key)
                try sealedBox.combined?.write(to: fileURL, options: .atomic)
            } catch {
                print("Failed to save encrypted configs: \(error)")
            }
        }
    }

    static var currentSelection: AIProviderSelection? {
        get {
            guard let data = try? Data(contentsOf: selectionFileURL) else {
                return nil
            }

            do {
                let sealedBox = try AES.GCM.SealedBox(combined: data)
                let decryptedData = try AES.GCM.open(sealedBox, using: key)
                let selection = try JSONDecoder().decode(AIProviderSelection.self, from: decryptedData)
                return selection
            } catch {
                return nil
            }
        }
        set {
            do {
                if let selection = newValue {
                    let data = try JSONEncoder().encode(selection)
                    let sealedBox = try AES.GCM.seal(data, using: key)
                    try sealedBox.combined?.write(to: selectionFileURL, options: .atomic)
                } else {
                    try? FileManager.default.removeItem(at: selectionFileURL)
                }
            } catch {
                print("Failed to save encrypted selection: \(error)")
            }
        }
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
        try? FileManager.default.removeItem(at: selectionFileURL)
    }
}
