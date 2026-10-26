import SwiftUI
import Carbon.HIToolbox

@main
struct LiquidRemoteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        Settings {
            SettingsView(hub: delegate.hub, store: delegate.store, discovery: delegate.discovery)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?

    let store = DeviceStore()
    lazy var hub = RemoteHub(store: store)
    let discovery = DeviceDiscovery()
    private var menuBar: MenuBarManager?
    private var settingsWindow: NSWindow?

    override init() {
        super.init()
        AppDelegate.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        NSApp.setActivationPolicy(.accessory)      // menu bar only (also set LSUIElement = YES)
        discovery.store = store
        menuBar = MenuBarManager(hub: hub)
        menuBar?.start()
        hub.startPolling()
        registerHotKeys()
        discovery.start()

        // Automatically present the remote panel on screen on launch!
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.menuBar?.presentFirst()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        menuBar?.presentFirst()
        return true
    }

    func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 540, height: 600),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "LiquidRemote — Devices & Settings"
            window.center()
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(hub: hub, store: store, discovery: discovery))
            self.settingsWindow = window
        }
        if let window = settingsWindow {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }

    /// ⌃⌥⌘ + ↑ / ↓ / M / Space → Active target device.
    private func registerHotKeys() {
        let mods = controlKey | optionKey | cmdKey
        let hk = HotKeyManager.shared
        hk.register(keyCode: kVK_UpArrow, modifiers: mods)   { [hub] in
            if let target = hub.store.devices.first?.id { hub.send(.volumeUp, to: target) }
        }
        hk.register(keyCode: kVK_DownArrow, modifiers: mods) { [hub] in
            if let target = hub.store.devices.first?.id { hub.send(.volumeDown, to: target) }
        }
        hk.register(keyCode: kVK_ANSI_M, modifiers: mods)    { [hub] in
            if let target = hub.store.devices.first?.id { hub.send(.mute, to: target) }
        }
        hk.register(keyCode: kVK_Space, modifiers: mods)     { [hub] in
            if let target = hub.store.devices.first?.id { hub.send(.playPause, to: target) }
        }
    }
}
