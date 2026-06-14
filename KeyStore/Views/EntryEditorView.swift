import SwiftUI

/// Form used to create a new entry or edit an existing one, presented as a sheet.
struct EntryEditorView: View {
    enum Mode {
        case add
        case edit(Entry)
    }

    let mode: Mode
    let onSave: (Entry) -> Void
    let onDelete: ((Entry) -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var key: String = ""
    @State private var value: String = ""
    @State private var category: String = ""
    @State private var tagsText: String = ""
    @State private var notes: String = ""

    init(mode: Mode, onSave: @escaping (Entry) -> Void, onDelete: ((Entry) -> Void)? = nil) {
        self.mode = mode
        self.onSave = onSave
        self.onDelete = onDelete
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var canSave: Bool {
        !key.trimmingCharacters(in: .whitespaces).isEmpty &&
        !value.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isEditing ? "Edit Entry" : "New Entry")
                .font(.headline)

            Form {
                TextField("Name", text: $key, prompt: Text("e.g. OpenAI API Key"))
                TextField("Value", text: $value, prompt: Text("secret value"))
                TextField("Category", text: $category, prompt: Text("e.g. API Keys"))
                TextField("Tags", text: $tagsText, prompt: Text("comma separated"))
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
            }
            .formStyle(.grouped)

            HStack {
                if isEditing, let onDelete, case let .edit(entry) = mode {
                    Button(role: .destructive) {
                        onDelete(entry)
                        dismiss()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .help("Delete entry")
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
            }
        }
        .padding(16)
        .frame(width: 360)
        .onAppear(perform: populate)
    }

    private func populate() {
        if case let .edit(entry) = mode {
            key = entry.key
            value = entry.value
            category = entry.category
            tagsText = entry.tags.joined(separator: ", ")
            notes = entry.notes
        }
    }

    private func save() {
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let trimmedKey = key.trimmingCharacters(in: .whitespaces)

        switch mode {
        case .add:
            onSave(Entry(key: trimmedKey, value: value, category: category, tags: tags, notes: notes))
        case .edit(let existing):
            var updated = existing
            updated.key = trimmedKey
            updated.value = value
            updated.category = category
            updated.tags = tags
            updated.notes = notes
            onSave(updated)
        }
        dismiss()
    }
}
