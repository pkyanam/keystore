import Foundation
import CryptoKit

/// Handles symmetric encryption of the vault using AES-GCM.
///
/// AES-GCM provides authenticated encryption: any tampering with the ciphertext
/// (or the wrong key) causes `open` to throw rather than return corrupt data.
enum VaultCrypto {
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    /// Encodes and encrypts a vault, returning the combined AES-GCM box
    /// (nonce + ciphertext + tag) suitable for writing to disk.
    static func seal(_ vault: Vault, with key: SymmetricKey) throws -> Data {
        let plaintext = try encoder.encode(vault)
        let sealedBox = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealedBox.combined else {
            throw VaultCryptoError.sealingFailed
        }
        return combined
    }

    /// Decrypts and decodes a vault from a combined AES-GCM box.
    static func open(_ data: Data, with key: SymmetricKey) throws -> Vault {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        let plaintext = try AES.GCM.open(sealedBox, using: key)
        return try decoder.decode(Vault.self, from: plaintext)
    }
}

enum VaultCryptoError: Error, LocalizedError {
    case sealingFailed

    var errorDescription: String? {
        switch self {
        case .sealingFailed:
            return "Failed to encrypt the vault."
        }
    }
}
