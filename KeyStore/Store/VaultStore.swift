import Foundation
import CryptoKit
import Observation

/// Abstraction over master-key acquisition so the store can be tested without
/// touching the real Keychain or biometrics.
protocol VaultKeyProviding: Sendable {
    func keyExists() -> Bool
    func loadOrCreateKey(reason: String) throws -> SymmetricKey
    func deleteKey() throws
}

extension MasterKeyStore: VaultKeyProviding {}

/// The app's central state: holds the decrypted entries in memory while
/// unlocked, persists changes as an encrypted file, and manages lock state.
@MainActor
@Observable
final class VaultStore {
    enum LockState: Equatable {
        case locked
        case unlocking
        case unlocked
    }

    private(set) var lockState: LockState = .locked
    private(set) var entries: [Entry] = []
    var searchText: String = ""
    var errorMessage: String?

    /// When the user explicitly locks, we suppress the next automatic unlock
    /// prompt so the locked screen is actually shown instead of immediately
    /// re-prompting for Touch ID.
    var suppressAutoUnlock: Bool = false

    /// Set when the master key was retrieved but the existing vault file could
    /// not be decrypted (key/vault mismatch or corruption). The UI offers a
    /// reset in this state. The (working) key is retained so reset can rebuild.
    private(set) var needsReset: Bool = false

    private let fileURL: URL
    private let keyProvider: VaultKeyProviding
    private var key: SymmetricKey?

    init(fileURL: URL? = nil, keyProvider: VaultKeyProviding = MasterKeyStore()) {
        self.fileURL = fileURL ?? VaultStore.defaultFileURL()
        self.keyProvider = keyProvider
    }

    var isUnlocked: Bool { lockState == .unlocked }

    /// Entries filtered by the current search text, sorted by key name.
    var filteredEntries: [Entry] {
        entries
            .filter { $0.matches(searchText) }
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
    }

    /// Distinct, sorted categories currently in use.
    var categories: [String] {
        let set = Set(entries.map(\.category).filter { !$0.isEmpty })
        return set.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    // MARK: - Lock / unlock

    /// Acquires the master key (prompting for biometrics off the main thread)
    /// and loads the decrypted vault into memory.
    func unlock(reason: String = "Unlock your KeyStore vault") async {
        guard lockState != .unlocked else { return }
        lockState = .unlocking
        errorMessage = nil
        needsReset = false

        // 1. Acquire the master key (biometric prompt, off the main thread).
        let provider = keyProvider
        let key: SymmetricKey
        do {
            key = try await Task.detached(priority: .userInitiated) {
                try provider.loadOrCreateKey(reason: reason)
            }.value
        } catch {
            self.key = nil
            self.lockState = .locked
            if case KeychainError.userCanceled = error {
                // User dismissed the prompt; stay silent.
            } else {
                self.errorMessage = error.localizedDescription
            }
            return
        }

        // 2. Decrypt the vault. A failure here means the key works but the file
        //    can't be authenticated — a mismatch/corruption, which we surface
        //    with a recovery path rather than a raw crypto error.
        self.key = key
        do {
            self.entries = try loadVault(with: key).entries
            self.lockState = .unlocked
        } catch {
            self.entries = []
            self.lockState = .locked
            self.needsReset = true
            self.errorMessage = "This vault can't be unlocked with the current key. "
                + "It was likely created by a different (differently signed) build of KeyStore."
        }
    }

    /// Recovery for the `needsReset` state: archives the unreadable vault file
    /// and starts a fresh, empty vault encrypted with the current key.
    /// Destroys access to the old entries — only used after a decrypt failure.
    func resetVault() {
        guard let key else {
            errorMessage = "Unlock first."
            return
        }
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let stamp = Int(Date().timeIntervalSince1970)
            let backup = fileURL.appendingPathExtension("unreadable-\(stamp).bak")
            try? FileManager.default.moveItem(at: fileURL, to: backup)
        }
        entries = []
        needsReset = false
        errorMessage = nil
        do {
            let data = try VaultCrypto.seal(Vault(entries: []), with: key)
            try VaultStore.ensureDirectoryExists(for: fileURL)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
            lockState = .unlocked
        } catch {
            errorMessage = "Failed to reset vault: \(error.localizedDescription)"
        }
    }

    /// Clears all secret material from memory and returns to the locked state.
    func lock() {
        key = nil
        entries = []
        searchText = ""
        errorMessage = nil
        suppressAutoUnlock = true
        lockState = .locked
    }

    // MARK: - CRUD

    func add(_ entry: Entry) {
        entries.append(entry)
        persist()
    }

    func update(_ entry: Entry) {
        guard let idx = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        var updated = entry
        updated.updatedAt = Date()
        entries[idx] = updated
        persist()
    }

    func delete(_ entry: Entry) {
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    func delete(at ids: Set<UUID>) {
        entries.removeAll { ids.contains($0.id) }
        persist()
    }

    // MARK: - Persistence

    private func loadVault(with key: SymmetricKey) throws -> Vault {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return Vault()
        }
        let data = try Data(contentsOf: fileURL)
        return try VaultCrypto.open(data, with: key)
    }

    private func persist() {
        guard let key else { return }
        do {
            let vault = Vault(entries: entries)
            let data = try VaultCrypto.seal(vault, with: key)
            try VaultStore.ensureDirectoryExists(for: fileURL)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }

    // MARK: - Locations

    static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("KeyStore", isDirectory: true)
        return dir.appendingPathComponent("vault.dat", isDirectory: false)
    }

    static func ensureDirectoryExists(for fileURL: URL) throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
}
