import SwiftUI
import UniformTypeIdentifiers

/// Wraps the encrypted backup bytes for SwiftUI's `fileExporter`.
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        data = contents
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// Collects a passphrase (with confirmation) and produces an encrypted backup.
struct ExportPassphraseSheet: View {
    @Environment(VaultStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// Called with the encrypted document once the passphrase is confirmed.
    let onReady: (BackupDocument) -> Void

    @State private var passphrase = ""
    @State private var confirm = ""
    @State private var error: String?

    private let minLength = 8

    private var canExport: Bool {
        passphrase.count >= minLength && passphrase == confirm
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export Encrypted Backup")
                .font(.headline)
            Text("Choose a passphrase. You'll need it to restore this backup — "
                + "it is not stored anywhere and cannot be recovered.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Form {
                SecureField("Passphrase", text: $passphrase)
                SecureField("Confirm passphrase", text: $confirm)
            }
            .formStyle(.grouped)

            if !passphrase.isEmpty && passphrase.count < minLength {
                Text("Use at least \(minLength) characters.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !confirm.isEmpty && passphrase != confirm {
                Text("Passphrases don't match.")
                    .font(.caption).foregroundStyle(.red)
            }
            if let error {
                Text(error).font(.callout).foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Export…") { export() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canExport)
            }
        }
        .padding(16)
        .frame(width: 360)
    }

    private func export() {
        do {
            let document = try store.makeBackup(passphrase: passphrase)
            onReady(BackupDocument(data: document))
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// Collects a passphrase and import strategy, then restores a backup.
struct ImportPassphraseSheet: View {
    @Environment(VaultStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let data: Data
    let onDone: (Int) -> Void

    @State private var passphrase = ""
    @State private var strategy: VaultStore.ImportStrategy = .merge
    @State private var error: String?
    @State private var working = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Restore Backup")
                .font(.headline)

            Form {
                SecureField("Passphrase", text: $passphrase)
                Picker("On import", selection: $strategy) {
                    Text("Merge with current entries").tag(VaultStore.ImportStrategy.merge)
                    Text("Replace all current entries").tag(VaultStore.ImportStrategy.replace)
                }
                .pickerStyle(.inline)
            }
            .formStyle(.grouped)

            if let error {
                Text(error).font(.callout).foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Restore") { performImport() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(passphrase.isEmpty || working)
            }
        }
        .padding(16)
        .frame(width: 360)
    }

    private func performImport() {
        error = nil
        working = true
        defer { working = false }
        do {
            let count = try store.importBackup(data: data, passphrase: passphrase, strategy: strategy)
            onDone(count)
            dismiss()
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
