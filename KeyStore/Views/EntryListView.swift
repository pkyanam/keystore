import SwiftUI
import UniformTypeIdentifiers

/// The unlocked catalog: search, scroll, add, and edit entries.
struct EntryListView: View {
    @Environment(VaultStore.self) private var store

    @State private var showingAdd = false
    @State private var editingEntry: Entry?

    // Backup / restore state.
    @State private var showExportPassphrase = false
    @State private var exportDocument: BackupDocument?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var pendingImportData: Data?
    @State private var showImportPassphrase = false
    @State private var statusMessage: String?

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

            if let statusMessage {
                Divider()
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                    Text(statusMessage).font(.caption)
                    Spacer()
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
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
        .sheet(isPresented: $showExportPassphrase) {
            ExportPassphraseSheet { document in
                exportDocument = document
                showExporter = true
            }
        }
        .sheet(isPresented: $showImportPassphrase) {
            if let data = pendingImportData {
                ImportPassphraseSheet(data: data) { count in
                    statusMessage = "Imported \(count) \(count == 1 ? "entry" : "entries")."
                }
            }
        }
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: defaultBackupFilename()
        ) { result in
            if case .failure(let error) = result {
                statusMessage = "Export failed: \(error.localizedDescription)"
            } else {
                statusMessage = "Backup exported."
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json]
        ) { result in
            handleImportSelection(result)
        }
    }

    private func defaultBackupFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "KeyStore-Backup-\(formatter.string(from: Date()))"
    }

    private func handleImportSelection(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            do {
                pendingImportData = try Data(contentsOf: url)
                showImportPassphrase = true
            } catch {
                statusMessage = "Couldn't read file: \(error.localizedDescription)"
            }
        case .failure(let error):
            statusMessage = "Import canceled: \(error.localizedDescription)"
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
                Button("Export Backup…") {
                    statusMessage = nil
                    showExportPassphrase = true
                }
                Button("Import Backup…") {
                    statusMessage = nil
                    showImporter = true
                }
                Divider()
                Button("Lock Now") { store.lock() }
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
