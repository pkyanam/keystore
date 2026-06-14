import SwiftUI

/// The unlocked catalog: search, scroll, add, and edit entries.
struct EntryListView: View {
    @Environment(VaultStore.self) private var store

    @State private var showingAdd = false
    @State private var editingEntry: Entry?

    var body: some View {
        @Bindable var store = store

        VStack(spacing: 0) {
            header

            Divider()

            searchField

            Divider()

            if store.filteredEntries.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(store.filteredEntries) { entry in
                        EntryRow(entry: entry) { editingEntry = entry }
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showingAdd) {
            EntryEditorView(mode: .add) { store.add($0) }
        }
        .sheet(item: $editingEntry) { entry in
            EntryEditorView(
                mode: .edit(entry),
                onSave: { store.update($0) },
                onDelete: { store.delete($0) }
            )
        }
    }

    private var header: some View {
        HStack {
            Text("KeyStore")
                .font(.headline)
            Spacer()
            Button { showingAdd = true } label: {
                Image(systemName: "plus")
            }
            .help("Add entry")

            Menu {
                Button("Lock Now") { store.lock() }
                Divider()
                Button("Quit KeyStore") { NSApplication.shared.terminate(nil) }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 36)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var searchField: some View {
        @Bindable var store = store
        return HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search", text: $store.searchText)
                .textFieldStyle(.plain)
            if !store.searchText.isEmpty {
                Button {
                    store.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: store.entries.isEmpty ? "key" : "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text(store.entries.isEmpty ? "No entries yet" : "No matches")
                .foregroundStyle(.secondary)
            if store.entries.isEmpty {
                Button("Add your first entry") { showingAdd = true }
                    .buttonStyle(.link)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
