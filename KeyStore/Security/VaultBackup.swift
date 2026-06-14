import Foundation
import CryptoKit
import CommonCrypto

/// Passphrase-based encrypted backup of a vault, for portable backup/restore
/// across machines or after the device master key changes.
///
/// Format (`.json` envelope):
/// - A random salt + PBKDF2-HMAC-SHA256 derive a 256-bit key from the passphrase.
/// - The vault JSON is sealed with AES-GCM under that derived key.
///
/// This is intentionally independent of the device Keychain master key: anyone
/// with the passphrase can restore the backup anywhere.
enum VaultBackup {
    /// Current OWASP-recommended PBKDF2-HMAC-SHA256 iteration count.
    static let defaultIterations = 600_000
    static let saltByteCount = 16
    static let formatVersion = 1

    /// The on-disk envelope. `Data` fields encode as base64 via JSONEncoder.
    struct Envelope: Codable {
        var format: Int
        var kdf: String          // e.g. "PBKDF2-HMAC-SHA256"
        var iterations: Int
        var salt: Data
        var ciphertext: Data     // AES-GCM combined box (nonce + ciphertext + tag)
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: - Export / import

    /// Encrypts a vault with a passphrase, returning the JSON envelope bytes.
    static func export(_ vault: Vault, passphrase: String) throws -> Data {
        let salt = try randomBytes(saltByteCount)
        let key = try deriveKey(passphrase: passphrase, salt: salt, iterations: defaultIterations)

        let plaintext = try encoder.encode(vault)
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else { throw BackupError.sealingFailed }

        let envelope = Envelope(
            format: formatVersion,
            kdf: "PBKDF2-HMAC-SHA256",
            iterations: defaultIterations,
            salt: salt,
            ciphertext: combined
        )
        return try encoder.encode(envelope)
    }

    /// Decrypts a backup envelope with a passphrase, returning the vault.
    /// Throws `BackupError.wrongPassphraseOrCorrupt` if the passphrase is wrong
    /// or the file has been tampered with.
    static func `import`(_ data: Data, passphrase: String) throws -> Vault {
        let envelope: Envelope
        do {
            envelope = try decoder.decode(Envelope.self, from: data)
        } catch {
            throw BackupError.unrecognizedFormat
        }
        guard envelope.format == formatVersion else { throw BackupError.unrecognizedFormat }

        let key = try deriveKey(
            passphrase: passphrase,
            salt: envelope.salt,
            iterations: envelope.iterations
        )
        do {
            let box = try AES.GCM.SealedBox(combined: envelope.ciphertext)
            let plaintext = try AES.GCM.open(box, using: key)
            return try decoder.decode(Vault.self, from: plaintext)
        } catch {
            throw BackupError.wrongPassphraseOrCorrupt
        }
    }

    // MARK: - Primitives

    private static func deriveKey(passphrase: String, salt: Data, iterations: Int) throws -> SymmetricKey {
        var derived = [UInt8](repeating: 0, count: 32)
        let pwBytes = Array(passphrase.utf8)

        let status: Int32 = pwBytes.withUnsafeBytes { pwRaw in
            salt.withUnsafeBytes { saltRaw in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    pwRaw.bindMemory(to: Int8.self).baseAddress, pwBytes.count,
                    saltRaw.bindMemory(to: UInt8.self).baseAddress, salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    UInt32(iterations),
                    &derived, derived.count
                )
            }
        }
        guard status == kCCSuccess else { throw BackupError.keyDerivationFailed }
        return SymmetricKey(data: Data(derived))
    }

    private static func randomBytes(_ count: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        guard SecRandomCopyBytes(kSecRandomDefault, count, &bytes) == errSecSuccess else {
            throw BackupError.randomGenerationFailed
        }
        return Data(bytes)
    }
}

enum BackupError: Error, LocalizedError {
    case sealingFailed
    case keyDerivationFailed
    case randomGenerationFailed
    case unrecognizedFormat
    case wrongPassphraseOrCorrupt

    var errorDescription: String? {
        switch self {
        case .sealingFailed: return "Failed to encrypt the backup."
        case .keyDerivationFailed: return "Failed to derive a key from the passphrase."
        case .randomGenerationFailed: return "Failed to generate secure random data."
        case .unrecognizedFormat: return "This file is not a KeyStore backup."
        case .wrongPassphraseOrCorrupt: return "Incorrect passphrase, or the backup file is corrupt."
        }
    }
}
