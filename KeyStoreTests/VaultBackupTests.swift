import Testing
import Foundation
@testable import KeyStore

struct VaultBackupTests {

    private func sampleVault() -> Vault {
        Vault(entries: [
            Entry(key: "OpenAI", value: "sk-123", category: "API Keys", tags: ["ai"]),
            Entry(key: "Bank", value: "999111", category: "Recovery Codes"),
        ])
    }

    @Test func exportImportRoundTrip() throws {
        let vault = sampleVault()
        let data = try VaultBackup.export(vault, passphrase: "correct horse battery staple")
        let restored = try VaultBackup.import(data, passphrase: "correct horse battery staple")

        #expect(restored.entries.count == 2)
        #expect(restored.entries.contains { $0.key == "OpenAI" && $0.value == "sk-123" })
        #expect(restored.entries.contains { $0.key == "Bank" && $0.value == "999111" })
    }

    @Test func wrongPassphraseFails() throws {
        let data = try VaultBackup.export(sampleVault(), passphrase: "right-passphrase")
        #expect(throws: BackupError.wrongPassphraseOrCorrupt) {
            _ = try VaultBackup.import(data, passphrase: "wrong-passphrase")
        }
    }

    @Test func tamperedBackupFails() throws {
        var data = try VaultBackup.export(sampleVault(), passphrase: "pw-12345678")
        // Corrupt a byte well inside the JSON (the base64 ciphertext region).
        data[data.count / 2] = data[data.count / 2] &+ 1
        #expect(throws: (any Error).self) {
            _ = try VaultBackup.import(data, passphrase: "pw-12345678")
        }
    }

    @Test func backupIsNotPlaintext() throws {
        let data = try VaultBackup.export(
            Vault(entries: [Entry(key: "k", value: "TOPSECRETVALUE")]),
            passphrase: "pw-12345678"
        )
        let text = String(decoding: data, as: UTF8.self)
        #expect(!text.contains("TOPSECRETVALUE"))
    }

    @Test func notABackupFileFails() throws {
        let junk = Data("not a backup".utf8)
        #expect(throws: BackupError.unrecognizedFormat) {
            _ = try VaultBackup.import(junk, passphrase: "whatever")
        }
    }
}

@MainActor
struct VaultStoreBackupTests {
    private func unlockedStore() async -> (VaultStore, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("keystore-tests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("vault.dat")
        let provider = FakeKeyProvider(key: .init(size: .bits256))
        let store = VaultStore(fileURL: url, keyProvider: provider)
        await store.unlock()
        return (store, url)
    }

    @Test func mergeKeepsExistingAndAddsImported() async throws {
        let (store, _) = await unlockedStore()
        store.add(Entry(key: "Existing", value: "1"))

        // Build a backup from a different store with a different entry.
        let (other, _) = await unlockedStore()
        other.add(Entry(key: "Imported", value: "2"))
        let backup = try other.makeBackup(passphrase: "pw-12345678")

        let count = try store.importBackup(data: backup, passphrase: "pw-12345678", strategy: .merge)
        #expect(count == 1)
        #expect(store.entries.contains { $0.key == "Existing" })
        #expect(store.entries.contains { $0.key == "Imported" })
    }

    @Test func replaceDiscardsExisting() async throws {
        let (store, _) = await unlockedStore()
        store.add(Entry(key: "Existing", value: "1"))

        let (other, _) = await unlockedStore()
        other.add(Entry(key: "OnlyThis", value: "2"))
        let backup = try other.makeBackup(passphrase: "pw-12345678")

        try store.importBackup(data: backup, passphrase: "pw-12345678", strategy: .replace)
        #expect(store.entries.count == 1)
        #expect(store.entries.first?.key == "OnlyThis")
    }

    @Test func importWrongPassphraseLeavesEntriesUntouched() async throws {
        let (store, _) = await unlockedStore()
        store.add(Entry(key: "Keep", value: "1"))

        let (other, _) = await unlockedStore()
        other.add(Entry(key: "X", value: "2"))
        let backup = try other.makeBackup(passphrase: "right")

        #expect(throws: (any Error).self) {
            try store.importBackup(data: backup, passphrase: "wrong", strategy: .replace)
        }
        #expect(store.entries.count == 1)
        #expect(store.entries.first?.key == "Keep")
    }
}
