import Foundation

/// Persists paired devices with auto-MAC discovery and WoL support.
@MainActor
final class DeviceStore: ObservableObject {
    @Published var devices: [RemoteDevice] = [] { didSet { save() } }
    private let key = "liquidremote.devices.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([RemoteDevice].self, from: data) {
            devices = decoded
            // Retroactively fill MAC address if missing
            for i in devices.indices {
                if devices[i].macAddress == nil && !devices[i].host.isEmpty {
                    devices[i].macAddress = WakeOnLAN.lookupArpMAC(for: devices[i].host)
                }
                if devices[i].iconSymbol == nil || devices[i].iconSymbol == "logo_roku" {
                    let lower = devices[i].name.lowercased()
                    if lower.contains("sharp") {
                        devices[i].iconSymbol = "logo_sharp"
                    }
                }
            }
        }
    }

    func device(_ id: UUID) -> RemoteDevice? {
        devices.first { $0.id == id }
    }

    func upsert(_ d: RemoteDevice) {
        if let i = devices.firstIndex(where: { $0.host == d.host && $0.brand == d.brand }) {
            devices[i].name = d.name
            if let icon = d.iconSymbol {
                devices[i].iconSymbol = icon
            }
            if let mac = d.macAddress, !mac.isEmpty {
                devices[i].macAddress = mac
            } else if devices[i].macAddress == nil {
                devices[i].macAddress = WakeOnLAN.lookupArpMAC(for: d.host)
            }
        } else {
            var new = d
            if new.macAddress == nil && !new.host.isEmpty {
                new.macAddress = WakeOnLAN.lookupArpMAC(for: new.host)
            }
            new.pinned = devices.isEmpty
            devices.append(new)
        }
    }

    func update(_ id: UUID, _ mutate: (inout RemoteDevice) -> Void) {
        guard let i = devices.firstIndex(where: { $0.id == id }) else { return }
        mutate(&devices[i])
    }

    func remove(_ id: UUID) { devices.removeAll { $0.id == id } }

    private func save() {
        if let data = try? JSONEncoder().encode(devices) { UserDefaults.standard.set(data, forKey: key) }
    }
}
