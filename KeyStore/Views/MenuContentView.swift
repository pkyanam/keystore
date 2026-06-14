import SwiftUI

/// Root content of the status-bar panel. Routes between locked and unlocked UI.
/// Window activation, dismissal, auto-unlock, and auto-lock are handled by
/// `AppDelegate`, which owns the panel.
struct MenuContentView: View {
    @Environment(VaultStore.self) private var store

    var body: some View {
        Group {
            if store.isUnlocked {
                EntryListView()
            } else {
                UnlockView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
