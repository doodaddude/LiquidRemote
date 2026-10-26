import Foundation

/// LG webOS SSAP over WebSocket (ws :3000 / wss :3001).
/// First connect shows a pairing prompt on the TV; the returned client-key is
/// persisted via `tokenSink` and reused silently afterwards.
final class LGWebOSController: NSObject, RemoteController, URLSessionDelegate, @unchecked Sendable {
    private(set) var device: RemoteDevice
    var capabilities: RemoteCapabilities { [.appLaunch, .pairing] }

    private let tokenSink: (String) -> Void
    private var session: URLSession!
    private var socket: URLSessionWebSocketTask?
    private var pointer: URLSessionWebSocketTask?
    private var pending: [String: CheckedContinuation<[String: Any], Error>] = [:]
    private let lock = NSLock()
    private var counter = 0
    private var muted = false

    init(device: RemoteDevice, tokenSink: @escaping (String) -> Void) {
        self.device = device; self.tokenSink = tokenSink
        super.init()
        session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)
    }

    // TVs use self-signed certs on :3001 — trust is limited to the paired LAN host.
    func urlSession(_ s: URLSession, didReceive c: URLAuthenticationChallenge,
                    completionHandler h: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let t = c.protectionSpace.serverTrust, c.protectionSpace.host == device.host {
            h(.useCredential, URLCredential(trust: t))
        } else { h(.performDefaultHandling, nil) }
    }

    func connect() async throws {
        if socket != nil { return }
        let scheme = device.port == 3000 ? "ws" : "wss"
        let port = device.port == 3000 ? 3000 : 3001
        socket = session.webSocketTask(with: URL(string: "\(scheme)://\(device.host):\(port)")!)
        socket?.resume()
        listen()

        var payload: [String: Any] = [
            "forcePairing": false, "pairingType": "PROMPT",
            "manifest": ["manifestVersion": 1,
                         "permissions": ["LAUNCH", "CONTROL_AUDIO", "CONTROL_POWER", "CONTROL_INPUT_MEDIA_PLAYBACK",
                                         "CONTROL_MOUSE_AND_KEYBOARD", "CONTROL_INPUT_TV", "READ_RUNNING_APPS"]]
        ]
        if let t = device.pairingToken { payload["client-key"] = t }
        let reg = try await call(type: "register", id: "register_0", uri: nil, payload: payload)
        if let key = (reg["payload"] as? [String: Any])?["client-key"] as? String {
            device.pairingToken = key; tokenSink(key)
        }
        // Pointer/button socket (D-pad, Back, Home)
        let r = try await call(type: "request", id: nil, uri: "ssap://com.webos.service.networkinput/getPointerInputSocket", payload: [:])
        if let path = (r["payload"] as? [String: Any])?["socketPath"] as? String, let url = URL(string: path) {
            pointer = session.webSocketTask(with: url); pointer?.resume()
        }
    }

    func disconnect() {
        socket?.cancel(with: .goingAway, reason: nil); socket = nil
        pointer?.cancel(with: .goingAway, reason: nil); pointer = nil
    }

    func send(_ key: RemoteKey) async throws {
        try await connect()
        func button(_ n: String) async throws { try await pointer?.send(.string("type:button\nname:\(n)\n\n")) }
        func ssap(_ uri: String, _ p: [String: Any] = [:]) async throws { _ = try await call(type: "request", id: nil, uri: uri, payload: p) }
        switch key {
        case .up: try await button("UP"); case .down: try await button("DOWN")
        case .left: try await button("LEFT"); case .right: try await button("RIGHT")
        case .select: try await button("ENTER"); case .back: try await button("BACK"); case .home: try await button("HOME")
        case .playPause: try await ssap("ssap://media.controls/play")   // webOS has no single toggle URI
        case .rewind: try await ssap("ssap://media.controls/rewind")
        case .fastForward: try await ssap("ssap://media.controls/fastForward")
        case .volumeUp: try await ssap("ssap://audio/volumeUp")
        case .volumeDown: try await ssap("ssap://audio/volumeDown")
        case .mute: muted.toggle(); try await ssap("ssap://audio/setMute", ["mute": muted])
        case .power: try await ssap("ssap://system/turnOff")           // can't wake over WS; use Wake-on-LAN
        case .star: try await button("INFO")
        case .sleep: try await ssap("ssap://system/turnOff")
        }
    }

    func launch(_ app: RemoteApp) async throws {
        guard let id = app.ids[.lgWebOS] else { return }
        try await connect()
        _ = try await call(type: "request", id: nil, uri: "ssap://system.launcher/launch", payload: ["id": id])
    }

    func setVolume(_ fraction: Double) async throws {
        try await connect()
        _ = try await call(type: "request", id: nil, uri: "ssap://audio/setVolume", payload: ["volume": Int(fraction * 100)])
    }

    // MARK: transport

    private func call(type: String, id: String?, uri: String?, payload: [String: Any]) async throws -> [String: Any] {
        guard let socket else { throw RemoteError.notConnected }
        let reqID: String = id ?? { lock.lock(); defer { lock.unlock() }; counter += 1; return "req_\(counter)" }()
        var msg: [String: Any] = ["type": type, "id": reqID, "payload": payload]
        if let uri { msg["uri"] = uri }
        let text = String(data: try JSONSerialization.data(withJSONObject: msg), encoding: .utf8)!
        return try await withCheckedThrowingContinuation { cont in
            lock.lock(); pending[reqID] = cont; lock.unlock()
            socket.send(.string(text)) { [weak self] err in
                guard let err, let self else { return }
                self.lock.lock(); let c = self.pending.removeValue(forKey: reqID); self.lock.unlock()
                c?.resume(throwing: err)
            }
        }
    }

    private func listen() {
        socket?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let m):
                if case .string(let s) = m,
                   let obj = try? JSONSerialization.jsonObject(with: Data(s.utf8)) as? [String: Any],
                   let id = obj["id"] as? String {
                    let type = obj["type"] as? String
                    // During pairing the TV first answers "response" (prompt shown), then "registered".
                    if !(id == "register_0" && type == "response") {
                        self.lock.lock(); let c = self.pending.removeValue(forKey: id); self.lock.unlock()
                        c?.resume(returning: obj)
                    }
                }
                self.listen()
            case .failure(let e):
                self.lock.lock(); let all = self.pending; self.pending = [:]; self.lock.unlock()
                all.values.forEach { $0.resume(throwing: e) }
                self.socket = nil
            }
        }
    }
}
