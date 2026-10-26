import Foundation

/// Generic UPnP/DLNA MediaRenderer — volume & mute via RenderingControl SOAP.
/// (Most UPnP renderers don't expose D-pad/navigation; those keys throw `.unsupported`.)
final class UPnPController: RemoteController {
    let device: RemoteDevice
    var capabilities: RemoteCapabilities { [.absoluteVolume] }
    private var controlURL: URL?
    private let svc = "urn:schemas-upnp-org:service:RenderingControl:1"

    init(device: RemoteDevice) { self.device = device }

    func connect() async throws {
        guard controlURL == nil else { return }
        guard let d = device.descriptorURL, let descURL = URL(string: d) else { throw RemoteError.badResponse }
        let (data, _) = try await URLSession.shared.data(from: descURL)
        let xml = String(data: data, encoding: .utf8) ?? ""
        guard let path = firstMatch("RenderingControl:1</serviceType>.*?<controlURL>(.*?)</controlURL>", in: xml) else {
            throw RemoteError.badResponse
        }
        controlURL = URL(string: path, relativeTo: descURL)?.absoluteURL
    }

    func send(_ key: RemoteKey) async throws {
        try await connect()
        switch key {
        case .volumeUp: try await setVolumeRaw(try await getVolume() + 2)
        case .volumeDown: try await setVolumeRaw(try await getVolume() - 2)
        case .mute:
            let reply = try await soap("GetMute", "<Channel>Master</Channel>")
            let muted = firstMatch("<CurrentMute>(\\d)</CurrentMute>", in: reply) == "1"
            _ = try await soap("SetMute", "<Channel>Master</Channel><DesiredMute>\(muted ? 0 : 1)</DesiredMute>")
        default: throw RemoteError.unsupported(key)
        }
    }

    func setVolume(_ fraction: Double) async throws {
        try await connect()
        try await setVolumeRaw(Int(fraction * 100))
    }

    private func getVolume() async throws -> Int {
        let reply = try await soap("GetVolume", "<Channel>Master</Channel>")
        return Int(firstMatch("<CurrentVolume>(\\d+)</CurrentVolume>", in: reply) ?? "") ?? 0
    }

    private func setVolumeRaw(_ v: Int) async throws {
        _ = try await soap("SetVolume", "<Channel>Master</Channel><DesiredVolume>\(max(0, min(100, v)))</DesiredVolume>")
    }

    private func soap(_ action: String, _ args: String) async throws -> String {
        guard let url = controlURL else { throw RemoteError.notConnected }
        let body = """
        <?xml version="1.0"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:\(action) xmlns:u="\(svc)"><InstanceID>0</InstanceID>\(args)</u:\(action)></s:Body></s:Envelope>
        """
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("text/xml; charset=\"utf-8\"", forHTTPHeaderField: "Content-Type")
        req.setValue("\"\(svc)#\(action)\"", forHTTPHeaderField: "SOAPACTION")
        req.httpBody = Data(body.utf8)
        let (data, _) = try await URLSession.shared.data(for: req)
        return String(data: data, encoding: .utf8) ?? ""
    }
}
