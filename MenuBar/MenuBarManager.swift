import AppKit
import SwiftUI
import Combine

/// Drives panel visibility + the spring-in animation inside SwiftUI.
final class PanelState: ObservableObject {
    @Published var isPresented = false
    var requestResize: (() -> Void)?
}

/// Borderless, transparent panel so the SwiftUI glass is the only chrome.
final class RemotePanel: NSPanel {
    let state = PanelState()
    override var canBecomeKey: Bool { true }

    init(content: (PanelState) -> AnyView) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: true)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false                      // SwiftUI draws the drop shadow
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let host = NSHostingView(rootView: content(state))
        contentView = host
        setContentSize(host.fittingSize)

        state.requestResize = { [weak self] in
            DispatchQueue.main.async {
                self?.updateSize()
            }
        }

        NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification,
                                               object: self, queue: .main) { [weak self] _ in
            self?.dismiss()
        }
    }

    func updateSize() {
        guard let host = contentView, let screen = screen ?? NSScreen.main else { return }
        let newSize = host.fittingSize
        guard newSize.width > 0, newSize.height > 0 else { return }

        let currentMaxY = frame.maxY
        var newY = currentMaxY - newSize.height

        // Clamping: ensure the bottom is never below visibleFrame.minY + 8
        if newY < screen.visibleFrame.minY + 8 {
            newY = screen.visibleFrame.minY + 8
        }
        if newY + newSize.height > screen.visibleFrame.maxY - 8 {
            newY = screen.visibleFrame.maxY - newSize.height - 8
        }

        let newFrame = NSRect(x: frame.minX, y: newY, width: newSize.width, height: newSize.height)
        setFrame(newFrame, display: true, animate: isVisible)
    }

    func present(below button: NSStatusBarButton? = nil) {
        guard let screen = NSScreen.main else { return }
        if let host = contentView { setContentSize(host.fittingSize) }
        var targetX: CGFloat
        var targetY: CGFloat

        if let button = button, let bw = button.window {
            let b = bw.frame
            var x = b.midX - frame.width / 2
            x = min(max(x, screen.visibleFrame.minX + 8), screen.visibleFrame.maxX - frame.width - 8)
            var y = b.minY - frame.height - 2
            // Clamp bottom so it NEVER gets cut off by the screen or Dock!
            if y < screen.visibleFrame.minY + 8 {
                y = screen.visibleFrame.minY + 8
            }
            targetX = x
            targetY = y
        } else {
            targetX = screen.visibleFrame.maxX - frame.width - 16
            targetY = max(screen.visibleFrame.minY + 8, screen.visibleFrame.maxY - frame.height - 8)
        }
        setFrameOrigin(NSPoint(x: targetX, y: targetY))
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
        state.isPresented = true
    }

    func dismiss() {
        guard isVisible else { return }
        state.isPresented = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            if self?.state.isPresented == false { self?.orderOut(nil) }
        }
    }
}

/// Owns one NSStatusItem + panel per pinned device (plus the optional Universal remote).
@MainActor
final class MenuBarManager: NSObject {
    private struct Entry { let item: NSStatusItem; let panel: RemotePanel }

    private let hub: RemoteHub
    private var entries: [UUID: Entry] = [:]
    private var bag = Set<AnyCancellable>()

    init(hub: RemoteHub) {
        self.hub = hub
        super.init()
    }

    func start() {
        sync()
        hub.store.$devices
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in DispatchQueue.main.async { self?.sync() } }
            .store(in: &bag)
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.sync() }
            .store(in: &bag)
    }

    func presentFirst() {
        if let entry = entries.values.first {
            entry.panel.present(below: entry.item.button)
        }
    }

    /// Reconcile status items with the pinned list (real devices only).
    func sync() {
        var wanted = hub.store.devices.filter(\.pinned)
        if wanted.isEmpty, let first = hub.store.devices.first {
            wanted.append(first)
        }
        if wanted.isEmpty {
            let placeholderID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
            let placeholder = RemoteDevice(id: placeholderID, name: "LiquidRemote", brand: .roku, host: "", port: 0)
            wanted.append(placeholder)
        }
        let wantedIDs = Set(wanted.map(\.id))

        for (id, e) in entries where !wantedIDs.contains(id) {
            e.panel.orderOut(nil)
            NSStatusBar.system.removeStatusItem(e.item)
            entries[id] = nil
        }

        let showLabels = UserDefaults.standard.bool(forKey: "showMenuBarLabels")
        for d in wanted {
            let entry = entries[d.id] ?? makeEntry(for: d)
            entries[d.id] = entry
            if let button = entry.item.button {
                button.image = icon(for: d)                 // tinted with the device's accent
                button.title = showLabels ? " \(d.name)" : ""
                button.imagePosition = showLabels ? .imageLeading : .imageOnly
                button.toolTip = d.name
            }
        }
    }

    private func makeEntry(for d: RemoteDevice) -> Entry {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(toggle(_:))
        item.button?.identifier = NSUserInterfaceItemIdentifier(d.id.uuidString)
        item.button?.sendAction(on: [.leftMouseUp])
        let hub = self.hub
        let panel = RemotePanel { state in
            AnyView(LiquidRemoteView(hub: hub, panel: state, initialDevice: d.id))
        }
        return Entry(item: item, panel: panel)
    }

    @objc private func toggle(_ sender: NSStatusBarButton) {
        guard let raw = sender.identifier?.rawValue,
              let id = UUID(uuidString: raw), let e = entries[id] else { return }
        for (other, entry) in entries where other != id { entry.panel.dismiss() }  // one open at a time
        if e.panel.isVisible { e.panel.dismiss() } else { e.panel.present(below: sender) }
    }

    private func icon(for d: RemoteDevice) -> NSImage? {
        if let brandImage = BrandLogoView.menuBarImage(for: d) {
            return brandImage
        }
        let cfg = NSImage.SymbolConfiguration(paletteColors: [NSColor(d.accentColor)])
        let img = NSImage(systemSymbolName: d.symbol, accessibilityDescription: d.name)?
            .withSymbolConfiguration(cfg)
        img?.isTemplate = false      // keep the color-coding instead of the system tint
        return img
    }
}
