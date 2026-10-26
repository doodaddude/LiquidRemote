import Foundation
import Combine

/// Owns controllers, routes commands, resolves "Universal" to the active device, polls now-playing.
@MainActor
final class RemoteHub: ObservableObject {
    let store: DeviceStore
    @Published var nowPlaying: [UUID: NowPlaying] = [:]
    @Published var lastError: String?
    private var lastActive: UUID?
    private var controllers: [UUID: RemoteController] = [:]
    private var timer: Timer?

    init(store: DeviceStore) { self.store = store }

    /// Resolve to the specified device, or whichever device is playing, else the last one used, else the first.
    func resolve(_ id: UUID) -> RemoteDevice? {
        if let d = store.device(id), d.brand != .universal { return d }
        if let playing = store.devices.first(where: { nowPlaying[$0.id]?.isPlaying == true }) { return playing }
        if let last = lastActive, let d = store.device(last) { return d }
        return store.devices.first
    }

    private func controller(for d: RemoteDevice) -> RemoteController {
        if let c = controllers[d.id] { return c }
        let c = ControllerFactory.make(for: d) { [weak self] token in
            Task { @MainActor in self?.store.update(d.id) { $0.pairingToken = token } }
        }
        controllers[d.id] = c
        return c
    }

    func capabilities(for id: UUID) -> RemoteCapabilities {
        resolve(id).map { controller(for: $0).capabilities } ?? []
    }

    func wake(_ id: UUID) {
        guard let d = resolve(id), let mac = d.macAddress, !mac.isEmpty else { return }
        Task {
            _ = await WakeOnLAN.wake(mac: mac, ip: d.host)
        }
    }

    func send(_ key: RemoteKey, to id: UUID) {
        guard let d = resolve(id) else { lastError = "No device available"; return }
        lastActive = d.id

        // Transmit Wake-on-LAN magic packet on power key
        if key == .power, let mac = d.macAddress, !mac.isEmpty {
            Task {
                _ = await WakeOnLAN.wake(mac: mac, ip: d.host)
            }
        }

        let c = controller(for: d)
        Task {
            do { try await c.send(key); lastError = nil }
            catch { lastError = error.localizedDescription }
        }
    }

    func launch(_ app: RemoteApp, on id: UUID) {
        guard let d = resolve(id) else { return }
        let c = controller(for: d)
        Task {
            do { try await c.launch(app) }
            catch { lastError = error.localizedDescription }
        }
    }

    func setVolume(_ fraction: Double, on id: UUID) {
        guard let d = resolve(id) else { return }
        let c = controller(for: d)
        Task { try? await c.setVolume(fraction) }
    }

    // MARK: polling

    func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.poll() }
        }
    }

    private func poll() async {
        for d in store.devices where d.brand != .universal {
            let c = controller(for: d)
            guard c.capabilities.contains(.nowPlaying) else { continue }
            nowPlaying[d.id] = await c.nowPlaying()
        }
    }
}
