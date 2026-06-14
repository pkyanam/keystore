import SwiftUI

/// Shown when the vault is locked. Triggers the single per-session Touch ID prompt.
struct UnlockView: View {
    @Environment(VaultStore.self) private var store
    @State private var showResetConfirm = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 44))
                .foregroundStyle(.tint)

            Text("KeyStore")
                .font(.title2.bold())

            Text("Your vault is locked.")
                .foregroundStyle(.secondary)

            if let error = store.errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await store.unlock() }
            } label: {
                HStack {
                    if store.lockState == .unlocking {
                        ProgressView().controlSize(.small)
                    }
                    Text(Biometrics.unlockLabel())
                }
                .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .disabled(store.lockState == .unlocking)

            if store.needsReset {
                Button(role: .destructive) {
                    showResetConfirm = true
                } label: {
                    Text("Reset Vault…")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .confirmationDialog(
            "Reset the vault?",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Reset and Erase Entries", role: .destructive) {
                store.resetVault()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The existing vault can't be decrypted with the current key and "
                + "its entries cannot be recovered. Resetting archives the old file "
                + "and starts a new, empty vault.")
        }
    }
}
