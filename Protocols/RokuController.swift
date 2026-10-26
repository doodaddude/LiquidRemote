import Foundation

/// Roku External Control Protocol — plain HTTP on :8060. No pairing needed
/// (user must have "Control by mobile apps" set to Default/Permissive).
final class RokuController: RemoteController {
    let device: RemoteDevice
    var capabilities: RemoteCapabilities { [.nowPlaying, .appLaunch] }

    private let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 3
        return URLSession(configuration: c)
    }()
    private var base: URL { URL(string: "http://\(device.host):\(device.port)")! }

    init(device: RemoteDevice) { self.device = device }

    func connect() async throws { _ = try await request("query/device-info", method: "GET") }

    func send(_ key: RemoteKey) async throws {
        let name: String = switch key {
        case .up: "Up"; case .down: "Down"; case .left: "Left"; case .right: "Right"
        case .select: "Select"; case .back: "Back"; case .home: "Home"
        case .playPause: "Play"; case .rewind: "Rev"; case .fastForward: "Fwd"
        case .volumeUp: "VolumeUp"; case .volumeDown: "VolumeDown"; case .mute: "VolumeMute"
        case .power: "Power"
        case .star: "Info"
        case .sleep: "PowerOff"
        }
        _ = try await request("keypress/\(name)", method: "POST")
    }

    func launch(_ app: RemoteApp) async throws {
        guard let id = app.ids[.roku] else { return }
        _ = try await request("launch/\(id)", method: "POST")
    }

    func nowPlaying() async -> NowPlaying? {
        guard let appXML = try? await request("query/active-app", method: "GET"),
              let name = firstMatch("<app[^>]*>(.*?)</app>", in: appXML), name != "Roku" else { return nil }
        let player = (try? await request("query/media-player", method: "GET")) ?? ""
        let state = firstMatch("state=\"(\\w+)\"", in: player) ?? "none"
        let appID = firstMatch("<app[^>]*id=\"(\\w+)\"", in: appXML)
        return NowPlaying(title: name,
                          subtitle: state == "play" ? "Playing" : state == "pause" ? "Paused" : nil,
                          isPlaying: state == "play",
                          artworkURL: appID.flatMap { URL(string: "http://\(device.host):\(device.port)/query/icon/\($0)") })
    }

    @discardableResult
    private func request(_ path: String, method: String) async throws -> String {
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = method
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse {
            if http.statusCode == 403 {
                throw RemoteError.badResponseDetail("TV Access Limited: On your TV, set Settings > System > Advanced > Control by mobile apps > Network access: Permissive")
            }
            guard http.statusCode < 300 else { throw RemoteError.badResponse }
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
