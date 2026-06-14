import Testing
import Foundation
import CryptoKit
@testable import KeyStore

struct VaultCryptoTests {

    @Test func sealOpenRoundTrip() throws {
        let key = SymmetricKey(size: .bits256)
        let entry = Entry(key: "API", value: "s3cr3t", category: "Keys", tags: ["a", "b"], notes: "n")
        let vault = Vault(entries: [entry])

        let data = try VaultCrypto.seal(vault, with: key)
        let restored = try VaultCrypto.open(data, with: key)

        #expect(restored.entries.count == 1)
        #expect(restored.entries[0].key == "API")
        #expect(restored.entries[0].value == "s3cr3t")
        #expect(restored.entries[0].tags == ["a", "b"])
        #expect(restored.version == Vault.currentVersion)
    }

    @Test func ciphertextIsNotPlaintext() throws {
        let key = SymmetricKey(size: .bits256)
        let vault = Vault(entries: [Entry(key: "k", value: "VERYSECRET")])
        let data = try VaultCrypto.seal(vault, with: key)
        let asString = String(decoding: data, as: UTF8.self)
        #expect(!asString.contains("VERYSECRET"))
    }

    @Test func wrongKeyFails() throws {
        let key = SymmetricKey(size: .bits256)
        let wrongKey = SymmetricKey(size: .bits256)
        let data = try VaultCrypto.seal(Vault(entries: []), with: key)
        #expect(throws: (any Error).self) {
            _ = try VaultCrypto.open(data, with: wrongKey)
        }
    }

    @Test func tamperedDataFails() throws {
        let key = SymmetricKey(size: .bits256)
        var data = try VaultCrypto.seal(Vault(entries: [Entry(key: "k", value: "v")]), with: key)
        // Flip a byte near the end (within the ciphertext/tag region).
        let idx = data.count - 1
        data[idx] ^= 0xFF
        #expect(throws: (any Error).self) {
            _ = try VaultCrypto.open(data, with: key)
        }
    }
}
