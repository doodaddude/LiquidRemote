import Foundation

/// Android TV Remote Protocol v2 — SCAFFOLD (not functional yet).
/// Needs: (1) pairing on :6467 — TLS with a self-generated client cert, protobuf pairing
/// messages, 6-digit code shown on the TV, secret = SHA256(clientMod, clientExp, serverMod,
/// serverExp, code); (2) remote session on :6466 — TLS with that same client cert, protobuf
/// `RemoteMessage` containing `RemoteKeyInject { key_code, direction }`.
/// Add SwiftProtobuf and generate from the open remotemessage/pairingmessage .proto files
/// (the androidtvremote2 Python library ships them).
final class AndroidTVController: RemoteController {
    let device: RemoteDevice
    var capabilities: RemoteCapabilities { [.pairing] }
    init(device: RemoteDevice) { self.device = device }

    static let keyCodes: [RemoteKey: Int] = [
        .up: 19, .down: 20, .left: 21, .right: 22, .select: 23, .back: 4, .home: 3,
        .playPause: 85, .rewind: 89, .fastForward: 90,
        .volumeUp: 24, .volumeDown: 25, .mute: 164, .power: 26,
        .star: 165, .sleep: 223,
    ]

    func connect() async throws {
        throw RemoteError.notImplemented("Google TV pairing (TLS + protobuf, ports 6467/6466) isn't wired up yet — see AndroidTVController.swift.")
    }
    func send(_ key: RemoteKey) async throws { try await connect() }
}
