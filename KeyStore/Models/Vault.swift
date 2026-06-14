import Foundation

/// The Codable container that is serialized and encrypted to disk.
struct Vault: Codable {
    /// Schema version to allow future migrations.
    var version: Int
    var entries: [Entry]

    static let currentVersion = 1

    init(version: Int = Vault.currentVersion, entries: [Entry] = []) {
        self.version = version
        self.entries = entries
    }
}
