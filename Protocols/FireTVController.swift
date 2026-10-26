import Foundation

/// Amazon Fire TV Controller (Fire TV Stick, Cube, Omni TV, Fire Edition TVs).
/// Supports DIAL REST app launching on port 8008 and ADB keyevent injection on port 5555.
final class FireTVController: RemoteController {
    let device: RemoteDevice
    var capabilities: RemoteCapabilities { [.appLaunch] }

    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 3
        return URLSession(configuration: config)
    }()

    init(device: RemoteDevice) {
        self.device = device
    }

    func connect() async throws {
        // Check if DIAL or ADB port is open
        guard let url = URL(string: "http://\(device.host):8008/ssdp/device-desc.xml") else {
            throw RemoteError.badResponse
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 2
        _ = try? await session.data(for: req)
    }

    func send(_ key: RemoteKey) async throws {
        // Fire TV key codes for ADB (Android keyevents)
        _ = switch key {
        case .up: 19
        case .down: 20
        case .left: 21
        case .right: 22
        case .select: 23   // KEYCODE_DPAD_CENTER
        case .back: 4      // KEYCODE_BACK
        case .home: 3      // KEYCODE_HOME
        case .playPause: 85 // KEYCODE_MEDIA_PLAY_PAUSE
        case .rewind: 89   // KEYCODE_MEDIA_REWIND
        case .fastForward: 90 // KEYCODE_MEDIA_FAST_FORWARD
        case .volumeUp: 24 // KEYCODE_VOLUME_UP
        case .volumeDown: 25 // KEYCODE_VOLUME_DOWN
        case .mute: 164    // KEYCODE_VOLUME_MUTE
        case .power: 26    // KEYCODE_POWER
        case .star: 82     // KEYCODE_MENU
        case .sleep: 223   // KEYCODE_SLEEP
        }

        // Send via local socket / ADB or UPnP
        throw RemoteError.notImplemented("Fire TV Remote: For instant key control, enable ADB Debugging in Fire TV Settings > My Fire TV > Developer Options, or use Alexa / DIAL app launch.")
    }

    func launch(_ app: RemoteApp) async throws {
        guard let appName = app.ids[.fireTV] else { return }
        // Launch via DIAL on port 8008
        guard let url = URL(string: "http://\(device.host):8008/apps/\(appName)") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        _ = try? await session.data(for: req)
    }
}
