import SwiftUI
import AppKit

/// A panel that can become the key/main window even though it is borderless,
/// so SwiftUI text fields inside it receive focus and clicks.
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Owns the status-bar item and the popover panel.
///
/// We use AppKit directly instead of SwiftUI's `MenuBarExtra(.window)` because
/// that API renders a transient popover that dismisses as soon as it loses key
/// status — which breaks multi-field forms and modal sheets. A real key-capable
/// `NSPanel` gives us proper focus handling and full control over dismissal.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = VaultStore()
    private var statusItem: NSStatusItem!
    private var panel: KeyablePanel!
    private var clickMonitor: Any?
    private var autoLockTask: Task<Void, Never>?

    private let panelSize = NSSize(width: 360, height: 480)
    private let autoLockInterval: Duration = .seconds(300)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupPanel()
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "key.fill", accessibilityDescription: "KeyStore")
            button.action = #selector(togglePanel)
            button.target = self
        }
    }

    private func setupPanel() {
        let hosting = NSHostingView(rootView: MenuContentView().environment(store))
        hosting.frame = NSRect(origin: .zero, size: panelSize)

        let panel = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        panel.contentView = hosting
        self.panel = panel
    }

    // MARK: - Show / hide

    @objc private func togglePanel() {
        if panel.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        positionPanel()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        startClickMonitor()
        autoUnlockIfNeeded()
    }

    private func hidePanel() {
        stopClickMonitor()
        panel.orderOut(nil)
    }

    private func positionPanel() {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }
        let buttonRect = button.convert(button.bounds, to: nil)
        let screenRect = buttonWindow.convertToScreen(buttonRect)
        let x = screenRect.midX - panelSize.width / 2
        let y = screenRect.minY - 6
        panel.setFrameTopLeftPoint(NSPoint(x: x, y: y))
    }

    /// Offer the Touch ID prompt automatically when opening, unless the user
    /// just locked manually (then show the locked screen so they can opt in).
    private func autoUnlockIfNeeded() {
        guard store.lockState == .locked else { return }
        if store.suppressAutoUnlock {
            store.suppressAutoUnlock = false
        } else {
            Task { await store.unlock() }
        }
    }

    // MARK: - Dismiss on outside click

    private func startClickMonitor() {
        stopClickMonitor()
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self else { return }
            // Never dismiss while a biometric prompt is in flight.
            guard self.store.lockState != .unlocking else { return }
            self.hidePanel()
        }
    }

    private func stopClickMonitor() {
        if let clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
            self.clickMonitor = nil
        }
    }

    // MARK: - Auto-lock

    func applicationDidResignActive(_ notification: Notification) {
        // Don't start the lock countdown during authentication.
        guard store.lockState != .unlocking else { return }
        scheduleAutoLock()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        autoLockTask?.cancel()
        autoLockTask = nil
    }

    private func scheduleAutoLock() {
        autoLockTask?.cancel()
        autoLockTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: self.autoLockInterval)
            guard !Task.isCancelled else { return }
            self.store.lock()
        }
    }
}
