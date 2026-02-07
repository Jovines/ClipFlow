#!/usr/bin/env swift
import Foundation

// Generate EdDSA key pair for Sparkle
// This script generates a new Ed25519 key pair

let keyPair = generateKeyPair()
print("Public Key: \(keyPair.public)")
print("Private Key: \(keyPair.private)")
print("\nIMPORTANT: Save these keys securely!")
print("Add the public key to your Info.plist as SUPublicEDKey")
print("Keep the private key secret and use it to sign updates")

func generateKeyPair() -> (public: String, private: String) {
    // Generate Ed25519 key pair using Security framework
    let attributes: [String: Any] = [
        kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
        kSecAttrKeySizeInBits as String: 256
    ]
    
    var error: Unmanaged<CFError>?
    guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
        if let error = error?.takeRetainedValue() {
            fatalError("Failed to generate key: \(error)")
        }
        fatalError("Failed to generate key")
    }
    
    guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
        fatalError("Failed to extract public key")
    }
    
    // Export keys
    guard let privateData = SecKeyCopyExternalRepresentation(privateKey, &error) else {
        if let error = error?.takeRetainedValue() {
            fatalError("Failed to export private key: \(error)")
        }
        fatalError("Failed to export private key")
    }
    
    guard let publicData = SecKeyCopyExternalRepresentation(publicKey, &error) else {
        if let error = error?.takeRetainedValue() {
            fatalError("Failed to export public key: \(error)")
        }
        fatalError("Failed to export public key")
    }
    
    let privateBase64 = (privateData as Data).base64EncodedString()
    let publicBase64 = (publicData as Data).base64EncodedString()
    
    return (publicBase64, privateBase64)
}
