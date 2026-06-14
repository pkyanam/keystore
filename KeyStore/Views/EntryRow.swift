import SwiftUI
import AppKit

/// A single row in the catalog: shows the key name and metadata, with
/// reveal and copy actions for the secret value.
struct EntryRow: View {
    let entry: Entry
    let onEdit: () -> Void

    @State private var revealed = false
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.key)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if !entry.category.isEmpty {
                    Text(entry.category)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
            }

            HStack(spacing: 8) {
                Text(revealed ? entry.value : "••••••••••••")
                    .font(.system(.callout, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .foregroundStyle(revealed ? .primary : .secondary)

                Spacer()

                Button {
                    revealed.toggle()
                } label: {
                    Image(systemName: revealed ? "eye.slash" : "eye")
                }
                .buttonStyle(.borderless)
                .help(revealed ? "Hide value" : "Reveal value")

                Button {
                    copyValue()
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("Copy value")
            }

            if !entry.tags.isEmpty {
                Text(entry.tags.map { "#\($0)" }.joined(separator: " "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Copy Value") { copyValue() }
            Button("Edit…", action: onEdit)
        }
    }

    private func copyValue() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(entry.value, forType: .string)
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            copied = false
        }
    }
}
