import Foundation

/// Sony BRAVIA Smart TV controller via IRCC-IP and Audio REST API.
/// Supported on all modern Sony BRAVIA TVs (both Linux-based and Google TV / Android TV models).
/// Authentication uses a Pre-Shared Key (PSK). Users can configure a PSK (default: "0000") in
/// Settings > Network > Home Network > IP Control > Pre-Shared Key.
final class SonyBraviaController: RemoteController {
    let device: RemoteDevice
    var capabilities: RemoteCapabilities { [.absoluteVolume, .appLaunch, .pairing] }

    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 4
        return URLSession(configuration: config)
    }()

    init(device: RemoteDevice) {
        self.device = device
    }

    private var psk: String {
        device.pairingToken ?? "0000"
    }

    func connect() async throws {
        // Ping Sony System REST API to verify reachability
        guard let url = URL(string: "http://\(device.host):\(device.port)/sony/system") else {
            throw RemoteError.badResponse
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(psk, forHTTPHeaderField: "X-Auth-PSK")
        let body = """
        {"method":"getSystemInformation","params":[],"id":1,"version":"1.0"}
        """
        req.httpBody = Data(body.utf8)

        let (_, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 403 || http.statusCode == 401 {
                throw RemoteError.pairingRequired("Sony PSK required: Set Pre-Shared Key to '0000' in TV Settings > Network > Home Network > IP Control.")
            }
            guard http.statusCode < 300 else { throw RemoteError.badResponse }
        }
    }

    func send(_ key: RemoteKey) async throws {
        let irccCode: String = switch key {
        case .power: "AAAAAQAAAAEAAAAVAw=="
        case .sleep: "AAAAAQAAAAEAAAAVAw=="
        case .up: "AAAAAQAAAAEAAAB0Aw=="
        case .down: "AAAAAQAAAAEAAAB1Aw=="
        case .left: "AAAAAQAAAAEAAAA0Aw=="
        case .right: "AAAAAQAAAAEAAAAzAw=="
        case .select: "AAAAAQAAAAEAAABlAw=="
        case .back: "AAAAAgAAAJcAAAAjAw=="
        case .home: "AAAAAQAAAAEAAABgAw=="
        case .volumeUp: "AAAAAQAAAAEAAAASAw=="
        case .volumeDown: "AAAAAQAAAAEAAAATAw=="
        case .mute: "AAAAAQAAAAEAAAAUAw=="
        case .playPause: "AAAAAgAAAJcAAAAaAw=="
        case .rewind: "AAAAAgAAAJcAAAAbAw=="
        case .fastForward: "AAAAAgAAAJcAAAAcAw=="
        case .star: "AAAAAgAAAJcAAAA8Aw=="  // Options
        }

        try await sendIRCC(irccCode)
    }

    func setVolume(_ fraction: Double) async throws {
        let volumeInt = Int(fraction * 100)
        guard let url = URL(string: "http://\(device.host):\(device.port)/sony/audio") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(psk, forHTTPHeaderField: "X-Auth-PSK")
        let json = """
        {"method":"setAudioVolume","params":[{"target":"speaker","volume":"\(volumeInt)"}],"version":"1.0","id":1}
        """
        req.httpBody = Data(json.utf8)
        _ = try? await session.data(for: req)
    }

    func launch(_ app: RemoteApp) async throws {
        guard let uri = app.ids[.sonyBravia] else { return }
        guard let url = URL(string: "http://\(device.host):\(device.port)/sony/appControl") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(psk, forHTTPHeaderField: "X-Auth-PSK")
        let json = """
        {"method":"setActiveApp","params":[{"uri":"\(uri)"}],"version":"1.0","id":1}
        """
        req.httpBody = Data(json.utf8)
        _ = try? await session.data(for: req)
    }

    private func sendIRCC(_ code: String) async throws {
        guard let url = URL(string: "http://\(device.host):\(device.port)/sony/ircc") else {
            throw RemoteError.badResponse
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("text/xml; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        req.setValue("\"urn:schemas-sony-com:service:IRCC:1#X_SendIRCC\"", forHTTPHeaderField: "SOAPACTION")
        req.setValue(psk, forHTTPHeaderField: "X-Auth-PSK")

        let xml = """
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
          <s:Body>
            <u:X_SendIRCC xmlns:u="urn:schemas-sony-com:service:IRCC:1">
              <IRCCCode>\(code)</IRCCCode>
            </u:X_SendIRCC>
          </s:Body>
        </s:Envelope>
        """
        req.httpBody = Data(xml.utf8)

        let (_, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse {
            if http.statusCode == 403 || http.statusCode == 401 {
                throw RemoteError.pairingRequired("Sony PSK Authentication Failed: Enable IP Control in Sony TV settings and set Pre-Shared Key to '0000'.")
            }
            guard http.statusCode < 300 else { throw RemoteError.badResponse }
        }
    }
}
