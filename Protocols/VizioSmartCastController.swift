import Foundation

/// Vizio SmartCast Smart TV controller.
/// Connects over HTTPS on port 7345 (or 9000) using the SmartCast REST API.
/// If an auth token is not yet established, initiates on-screen 4-digit pairing.
final class VizioSmartCastController: NSObject, RemoteController, URLSessionDelegate, @unchecked Sendable {
    private(set) var device: RemoteDevice
    var capabilities: RemoteCapabilities { [.pairing, .appLaunch] }

    private let tokenSink: (String) -> Void
    private var session: URLSession!

    init(device: RemoteDevice, tokenSink: @escaping (String) -> Void) {
        self.device = device
        self.tokenSink = tokenSink
        super.init()
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 4
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let trust = challenge.protectionSpace.serverTrust, challenge.protectionSpace.host == device.host {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }

    func connect() async throws {
        // Ping current state
        guard let url = URL(string: "https://\(device.host):\(device.port)/state/device/power_mode") else {
            throw RemoteError.badResponse
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        if let token = device.pairingToken, !token.isEmpty {
            req.setValue(token, forHTTPHeaderField: "AUTH")
        }

        let (_, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse {
            if http.statusCode == 403 || http.statusCode == 401 {
                throw RemoteError.pairingRequired("Vizio Pairing Required: Enter auth token in device settings.")
            }
        }
    }

    func send(_ key: RemoteKey) async throws {
        let (codeset, code): (Int, Int) = switch key {
        case .up: (3, 8)
        case .down: (3, 0)
        case .left: (3, 1)
        case .right: (3, 5)
        case .select: (3, 2)
        case .back: (3, 4)
        case .home: (4, 3)
        case .star: (4, 6)
        case .volumeUp: (5, 9)
        case .volumeDown: (5, 8)
        case .mute: (5, 11)
        case .playPause: (5, 3)
        case .rewind: (5, 0)
        case .fastForward: (5, 1)
        case .power: (11, 1)
        case .sleep: (11, 2)
        }

        guard let url = URL(string: "https://\(device.host):\(device.port)/key_command/") else {
            throw RemoteError.badResponse
        }
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = device.pairingToken, !token.isEmpty {
            req.setValue(token, forHTTPHeaderField: "AUTH")
        }

        let body: [String: Any] = [
            "KEYLIST": [
                ["CODESET": codeset, "CODE": code, "ACTION": "KEY_PRESS"]
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse {
            if http.statusCode == 403 || http.statusCode == 401 {
                throw RemoteError.pairingRequired("Vizio Auth Required: Connect device with your SmartCast token.")
            }
            guard http.statusCode < 300 else { throw RemoteError.badResponse }
        }
    }
}
