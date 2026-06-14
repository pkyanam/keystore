import Testing
import Foundation
import CryptoKit
@testable import KeyStore

/// A deterministic key provider that never touches the Keychain or biometrics.
struct FakeKeyProvider: VaultKeyProviding {
    let key: SymmetricKey
    func keyExists() -> Bool { true }
    func loadOrCreateKey(reason: String) throws -> SymmetricKey { key }
    func deleteKey() throws {}
}

@MainActor
struct VaultStoreTests {

    private func makeStore() -> (VaultStore, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("keystore-tests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("vault.dat")
        let provider = FakeKeyProvider(key: SymmetricKey(size: .bits256))
        return (VaultStore(fileURL: url, keyProvider: provider), url)
    }

    @Test func unlockEmptyVault() async {
        let (store, _) = makeStore()
        await store.unlock()
        #expect(store.isUnlocked)
        #expect(store.entries.isEmpty)
    }

    @Test func addPersistsAcrossReload() async {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("keystore-tests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("vault.dat")
        let provider = FakeKeyProvider(key: SymmetricKey(size: .bits256))

        let store1 = VaultStore(fileURL: url, keyProvider: provider)
        await store1.unlock()
        store1.add(Entry(key: "GitHub", value: "ghp_xxx", category: "API Keys"))
        #expect(store1.entries.count == 1)

        let store2 = VaultStore(fileURL: url, keyProvider: provider)
        await store2.unlock()
        #expect(store2.entries.count == 1)
        #expect(store2.entries[0].key == "GitHub")
        #expect(store2.entries[0].value == "ghp_xxx")
    }

    @Test func searchFilters() async {
        let (store, _) = makeStore()
        await store.unlock()
        store.add(Entry(key: "OpenAI", value: "1", category: "API Keys"))
        store.add(Entry(key: "Bank Recovery", value: "2", category: "Recovery Codes", tags: ["finance"]))

        store.searchText = "recovery"
        #expect(store.filteredEntries.count == 1)
        #expect(store.filteredEntries[0].key == "Bank Recovery")

        store.searchText = "finance"
        #expect(store.filteredEntries.count == 1)

        store.searchText = ""
        #expect(store.filteredEntries.count == 2)
    }

    @Test func searchNeverMatchesValue() async {
        let (store, _) = makeStore()
        await store.unlock()
        store.add(Entry(key: "Token", value: "supersecretvalue"))
        store.searchText = "supersecret"
        #expect(store.filteredEntries.isEmpty)
    }

    @Test func updateAndDelete() async {
        let (store, _) = makeStore()
        await store.unlock()
        let entry = Entry(key: "X", value: "1")
        store.add(entry)

        var edited = entry
        edited.key = "Y"
        store.update(edited)
        #expect(store.entries[0].key == "Y")

        store.delete(edited)
        #expect(store.entries.isEmpty)
    }

    @Test func lockClearsMemory() async {
        let (store, _) = makeStore()
        await store.unlock()
        store.add(Entry(key: "X", value: "1"))
        store.lock()
        #expect(!store.isUnlocked)
        #expect(store.entries.isEmpty)
    }

    @Test func categoriesAreDistinctAndSorted() async {
        let (store, _) = makeStore()
        await store.unlock()
        store.add(Entry(key: "a", value: "1", category: "Zeta"))
        store.add(Entry(key: "b", value: "2", category: "Alpha"))
        store.add(Entry(key: "c", value: "3", category: "Alpha"))
        #expect(store.categories == ["Alpha", "Zeta"])
    }
}
