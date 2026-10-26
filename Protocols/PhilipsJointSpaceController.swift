import Foundation

/// Philips Smart TV & Ambilight controller via JointSpace REST API.
/// Supported across Philips Android TVs, Google TVs, and Saphi OS models.
/// Uses port 1925 (or 51978).
final class PhilipsJointSpaceController: RemoteController {
    let device: RemoteDevice
    var capabilities: RemoteCapabilities { [.absoluteVolume, .appLaunch] }

    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 3
        return URLSession(configuration: config)
    }()

    init(device: RemoteDevice) {
        self.device = device
    }

    func connect() async throws {
        guard let url = URL(string: "http://\(device.host):\(device.port)/6/system") ?? URL(string: "http://\(device.host):\(device.port)/1/system") else {
            throw RemoteError.badResponse
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 2
        let (_, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode >= 400 {
            throw RemoteError.badResponse
        }
    }

    func send(_ key: RemoteKey) async throws {
        let keyName: String = switch key {
        case .up: "CursorUp"
        case .down: "CursorDown"
        case .left: "CursorLeft"
        case .right: "CursorRight"
        case .select: "Confirm"
        case .back: "Back"
        case .home: "Home"
        case .volumeUp: "VolumeUp"
        case .volumeDown: "VolumeDown"
        case .mute: "Mute"
        case .power: "Standby"
        case .sleep: "Standby"
        case .playPause: "PlayPause"
        case .rewind: "Rewind"
        case .fastForward: "FastForward"
        case .star: "Options"
        }

        // Try API v6 then fallback to v1
        let urls = [
            URL(string: "http://\(device.host):\(device.port)/6/input/key"),
            URL(string: "http://\(device.host):\(device.port)/1/input/key")
        ].compactMap { $0 }

        let payload = "{\"key\":\"\(keyName)\"}".data(using: .utf8)!

        for url in urls {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = payload
            if let (_, resp) = try? await session.data(for: req),
               (resp as? HTTPURLResponse)?.statusCode == 200 {
                return
            }
        }
    }

    func setVolume(_ fraction: Double) async throws {
        let maxVol = 60
        let target = Int(fraction * Double(maxVol))
        let payload = "{\"current\":\(target),\"muted\":false}".data(using: .utf8)!

        guard let url = URL(string: "http://\(device.host):\(device.port)/6/audio/volume") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = payload
        _ = try? await session.data(for: req)
    }
}
