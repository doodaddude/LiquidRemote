import Foundation

enum RemoteError: LocalizedError {
    case unsupported(RemoteKey)
    case notConnected
    case pairingRequired(String)
    case notImplemented(String)
    case badResponse
    case badResponseDetail(String)

    var errorDescription: String? {
        switch self {
        case .unsupported(let k): "This device doesn't support \(k.rawValue)."
        case .notConnected: "Not connected."
        case .pairingRequired(let m): m
        case .notImplemented(let m): m
        case .badResponse: "Unexpected response from device."
        case .badResponseDetail(let m): m
        }
    }
}

/// One implementation per protocol. Everything the UI needs goes through here.
protocol RemoteController: AnyObject {
    var device: RemoteDevice { get }
    var capabilities: RemoteCapabilities { get }

    func connect() async throws
    func disconnect()
    func send(_ key: RemoteKey) async throws
    func launch(_ app: RemoteApp) async throws
    func nowPlaying() async -> NowPlaying?
    func setVolume(_ fraction: Double) async throws
}

extension RemoteController {
    var capabilities: RemoteCapabilities { [] }
    func connect() async throws {}
    func disconnect() {}
    func launch(_ app: RemoteApp) async throws { throw RemoteError.notImplemented("App launch not supported.") }
    func nowPlaying() async -> NowPlaying? { nil }
    func setVolume(_ fraction: Double) async throws { throw RemoteError.unsupported(.volumeUp) }
}

enum ControllerFactory {
    /// `tokenSink` lets controllers hand back pairing tokens for persistence.
    static func make(for d: RemoteDevice, tokenSink: @escaping (String) -> Void) -> RemoteController {
        switch d.brand {
        case .roku: RokuController(device: d)
        case .lgWebOS: LGWebOSController(device: d, tokenSink: tokenSink)
        case .googleTV: AndroidTVController(device: d)
        case .appleTV: AppleTVController(device: d)
        case .generic, .universal: UPnPController(device: d)
        }
    }
}

// MARK: - Tiny helpers

func firstMatch(_ pattern: String, in s: String) -> String? {
    guard let re = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
          let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
          m.numberOfRanges > 1, let r = Range(m.range(at: 1), in: s) else { return nil }
    return String(s[r])
}
