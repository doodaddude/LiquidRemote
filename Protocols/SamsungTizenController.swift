import Foundation
import AppKit

/// Samsung Smart TV (Tizen OS 2016+) WebSocket controller.
/// Connects to wss://<host>:8002/api/v2/channels/samsung.remote.control (or ws://:8001).
/// When connecting for the first time, a prompt appears on the TV screen asking to allow LiquidRemote.
/// The returned authorization token is saved and reused for subsequent connections.
final class SamsungTizenController: NSObject, RemoteController, URLSessionDelegate, @unchecked Sendable {
    private(set) var device: RemoteDevice
    var capabilities: RemoteCapabilities { [.appLaunch, .pairing] }

    private let tokenSink: (String) -> Void
    private var session: URLSession!
    private var socket: URLSessionWebSocketTask?
    private let queue = DispatchQueue(label: "com.liquidremote.samsung")
    private var isConnected = false
    private var connectContinuation: CheckedContinuation<Void, Error>?

    init(device: RemoteDevice, tokenSink: @escaping (String) -> Void) {
        self.device = device
        self.tokenSink = tokenSink
        super.init()
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    // Samsung TVs use self-signed TLS certificates on port 8002
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let trust = challenge.protectionSpace.serverTrust, challenge.protectionSpace.host == device.host {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }

    func connect() async throws {
        if socket != nil && isConnected { return }
        disconnect()

        let appName = "LiquidRemote"
        let base64Name = Data(appName.utf8).base64EncodedString()
        let port = device.port == 8001 ? 8001 : 8002
        let scheme = port == 8001 ? "ws" : "wss"

        var urlString = "\(scheme)://\(device.host):\(port)/api/v2/channels/samsung.remote.control?name=\(base64Name)"
        if let token = device.pairingToken, !token.isEmpty {
            urlString += "&token=\(token)"
        }

        guard let url = URL(string: urlString) else { throw RemoteError.badResponse }

        let ws = session.webSocketTask(with: url)
        self.socket = ws
        ws.resume()
        listen()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                self.connectContinuation = continuation
            }

            // Timeout after 8 seconds if TV prompt not accepted
            queue.asyncAfter(deadline: .now() + 8.0) {
                if let cont = self.connectContinuation {
                    self.connectContinuation = nil
                    cont.resume(throwing: RemoteError.pairingRequired("Pairing Prompt: Please select 'Allow' on your Samsung TV screen to authorize LiquidRemote."))
                }
            }
        }
    }

    func disconnect() {
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        isConnected = false
    }

    func send(_ key: RemoteKey) async throws {
        try await connect()

        let keyName: String = switch key {
        case .up: "KEY_UP"
        case .down: "KEY_DOWN"
        case .left: "KEY_LEFT"
        case .right: "KEY_RIGHT"
        case .select: "KEY_ENTER"
        case .back: "KEY_RETURN"
        case .home: "KEY_HOME"
        case .playPause: "KEY_PLAY_BACK"
        case .rewind: "KEY_REWIND"
        case .fastForward: "KEY_FF"
        case .volumeUp: "KEY_VOLUP"
        case .volumeDown: "KEY_VOLDOWN"
        case .mute: "KEY_MUTE"
        case .power: "KEY_POWER"
        case .star: "KEY_INFO"
        case .sleep: "KEY_SLEEP"
        }

        let payload: [String: Any] = [
            "method": "ms.remote.control",
            "params": [
                "Cmd": "Click",
                "DataOfCmd": keyName,
                "Option": "false",
                "TypeOfRemote": "SendRemoteKey"
            ]
        ]

        let data = try JSONSerialization.data(withJSONObject: payload)
        guard let text = String(data: data, encoding: .utf8) else { throw RemoteError.badResponse }
        try await socket?.send(.string(text))
    }

    func launch(_ app: RemoteApp) async throws {
        guard let appId = app.ids[.samsungTizen] else { return }
        // Launch via REST API on port 8001
        guard let url = URL(string: "http://\(device.host):8001/api/v2/applications/\(appId)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 3
        _ = try? await URLSession.shared.data(for: request)
    }

    // MARK: - WebSocket Listener

    private func listen() {
        socket?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                if case .string(let text) = message,
                   let data = text.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    self.handleMessage(json)
                }
                self.listen()
            case .failure(let error):
                self.queue.async {
                    self.isConnected = false
                    if let cont = self.connectContinuation {
                        self.connectContinuation = nil
                        cont.resume(throwing: error)
                    }
                }
            }
        }
    }

    private func handleMessage(_ json: [String: Any]) {
        let event = json["event"] as? String

        if event == "ms.channel.connect" {
            queue.async {
                self.isConnected = true
                if let data = json["data"] as? [String: Any],
                   let token = data["token"] as? String {
                    self.device.pairingToken = token
                    self.tokenSink(token)
                }
                if let cont = self.connectContinuation {
                    self.connectContinuation = nil
                    cont.resume()
                }
            }
        } else if event == "ms.channel.unauthorized" {
            queue.async {
                if let cont = self.connectContinuation {
                    self.connectContinuation = nil
                    cont.resume(throwing: RemoteError.pairingRequired("Access Denied: Please remove LiquidRemote in your TV's External Device Manager and reconnect."))
                }
            }
        }
    }
}
