import SwiftUI

/// Shown when the vault is locked. Triggers the single per-session Touch ID prompt.
struct UnlockView: View {
    @Environment(VaultStore.self) private var store

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
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
