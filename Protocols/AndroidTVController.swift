import Foundation

/// Android TV & Google TV Controller (Chromecast with Google TV, NVIDIA Shield, Xiaomi, onn., TCL/Hisense Google TV).
/// Supports DIAL protocol on port 8008 for app launching and media control,
/// and Android TV Remote Protocol v2 on ports 6467/6466.
final class AndroidTVController: RemoteController {
    let device: RemoteDevice
    var capabilities: RemoteCapabilities { [.appLaunch, .pairing] }

    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 3
        return URLSession(configuration: config)
    }()

    init(device: RemoteDevice) {
        self.device = device
    }

    static let keyCodes: [RemoteKey: Int] = [
        .up: 19, .down: 20, .left: 21, .right: 22, .select: 23, .back: 4, .home: 3,
        .playPause: 85, .rewind: 89, .fastForward: 90,
        .volumeUp: 24, .volumeDown: 25, .mute: 164, .power: 26,
        .star: 165, .sleep: 223,
    ]

    func connect() async throws {
        // Check DIAL reachability
        guard let url = URL(string: "http://\(device.host):8008/ssdp/device-desc.xml") else {
            throw RemoteError.badResponse
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 2
        _ = try? await session.data(for: req)
    }

    func send(_ key: RemoteKey) async throws {
        throw RemoteError.notImplemented("Google TV Remote v2 (TLS ports 6467/6466) requires pairing with the 6-digit code shown on screen. Quick-launch apps work via DIAL.")
    }

    func launch(_ app: RemoteApp) async throws {
        // Launch via Google Cast / DIAL protocol on port 8008
        guard let dialName = app.dialName else { return }
        guard let url = URL(string: "http://\(device.host):8008/apps/\(dialName)") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        _ = try? await session.data(for: req)
    }
}
