import Foundation

/// A single stored secret: a named key paired with a sensitive value,
/// plus organizational metadata.
struct Entry: Identifiable, Codable, Hashable {
    var id: UUID
    /// Human-readable name for the secret, e.g. "OpenAI API Key".
    var key: String
    /// The sensitive value. Only ever held in memory while the vault is unlocked.
    var value: String
    /// Optional grouping category, e.g. "API Keys" or "Recovery Codes".
    var category: String
    /// Free-form tags for filtering.
    var tags: [String]
    /// Optional notes.
    var notes: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        key: String,
        value: String,
        category: String = "",
        tags: [String] = [],
        notes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.key = key
        self.value = value
        self.category = category
        self.tags = tags
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension Entry {
    /// Returns true if the entry matches a case-insensitive search query
    /// across its non-secret fields (never the value itself).
    func matches(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }
        if key.lowercased().contains(q) { return true }
        if category.lowercased().contains(q) { return true }
        if notes.lowercased().contains(q) { return true }
        return tags.contains { $0.lowercased().contains(q) }
    }
}
