import SwiftUI

@main
struct KeyStoreApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The UI is driven entirely by the status-bar panel in AppDelegate.
        // This empty Settings scene keeps SwiftUI happy without showing a window.
        Settings {
            EmptyView()
        }
    }
}
