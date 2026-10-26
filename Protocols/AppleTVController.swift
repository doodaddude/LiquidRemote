import Foundation

/// Apple TV — SCAFFOLD (not functional yet).
/// The Companion protocol requires HAP-style pairing (SRP + Ed25519/X25519 + ChaCha20-Poly1305),
/// OPACK-encoded frames, and HID events for D-pad/media keys. Practical options:
///   1. Port the open-source `pyatv` Companion implementation to Swift (CryptoKit has the primitives).
///   2. Ship a helper that runs `atvscript` from pyatv (not sandbox-friendly).
/// Credentials from pairing go in `device.pairingToken` (move to Keychain).
final class AppleTVController: RemoteController {
    let device: RemoteDevice
    var capabilities: RemoteCapabilities { [.pairing, .nowPlaying] }
    init(device: RemoteDevice) { self.device = device }

    func connect() async throws {
        throw RemoteError.notImplemented("Apple TV Companion pairing isn't wired up yet — see AppleTVController.swift.")
    }
    func send(_ key: RemoteKey) async throws { try await connect() }
}
