import Foundation

/// Universal Wake-on-LAN engine supporting all smart TV brands.
/// Generates and broadcasts the standard 102-byte Magic Packet (6x 0xFF + 16x MAC).
enum WakeOnLAN {

    /// Transmit WoL Magic Packet over UDP broadcast.
    @discardableResult
    static func wake(mac: String, ip: String? = nil, port: UInt16 = 9) async -> Bool {
        guard let macBytes = parseMAC(mac) else { return false }

        // Build 102-byte magic packet: 6 bytes 0xFF followed by 16 repetitions of MAC
        var packet = [UInt8](repeating: 0xFF, count: 6)
        for _ in 0..<16 {
            packet.append(contentsOf: macBytes)
        }

        let sock = socket(AF_INET, SOCK_DGRAM, 0)
        guard sock >= 0 else { return false }
        defer { close(sock) }

        var broadcastOpt: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_BROADCAST, &broadcastOpt, socklen_t(MemoryLayout<Int32>.size))

        // Target standard global broadcast and local subnet broadcast if available
        var targets = ["255.255.255.255"]
        if let ip = ip, let dot = ip.lastIndex(of: ".") {
            targets.append(String(ip[..<dot]) + ".255")
        }

        let ports: [UInt16] = [port, 7] // Standard WoL ports 9 and 7

        for targetIP in targets {
            for targetPort in ports {
                var dest = sockaddr_in()
                dest.sin_family = sa_family_t(AF_INET)
                dest.sin_port = targetPort.bigEndian
                inet_pton(AF_INET, targetIP, &dest.sin_addr)

                withUnsafePointer(to: &dest) { ptr in
                    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                        // Send 3 times in quick succession to overcome wireless frame drops
                        for _ in 0..<3 {
                            _ = sendto(sock, packet, packet.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                        }
                    }
                }
            }
        }
        return true
    }

    /// Convert raw MAC string to 6 bytes.
    static func parseMAC(_ mac: String) -> [UInt8]? {
        let clean = mac.replacingOccurrences(of: ":", with: "")
                       .replacingOccurrences(of: "-", with: "")
                       .replacingOccurrences(of: ".", with: "")
                       .trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count == 12 else { return nil }

        var bytes = [UInt8]()
        for i in stride(from: 0, to: 12, by: 2) {
            let start = clean.index(clean.startIndex, offsetBy: i)
            let end = clean.index(start, offsetBy: 2)
            guard let byte = UInt8(clean[start..<end], radix: 16) else { return nil }
            bytes.append(byte)
        }
        return bytes.count == 6 ? bytes : nil
    }

    /// Standardize MAC to format "AA:BB:CC:DD:EE:FF".
    static func formatMAC(_ mac: String) -> String? {
        guard let bytes = parseMAC(mac) else { return nil }
        return bytes.map { String(format: "%02X", $0) }.joined(separator: ":")
    }

    /// Look up MAC address for any IP in the local ARP table.
    static func lookupArpMAC(for host: String) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/arp")
        p.arguments = ["-n", host]
        let pipe = Pipe()
        p.standardOutput = pipe
        try? p.run()
        p.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let out = String(data: data, encoding: .utf8) else { return nil }

        // Sample: "? (192.168.68.102) at 64:6e:69:21:a8:57 on en0 ifscope [ethernet]"
        let parts = out.components(separatedBy: " ")
        if let atIdx = parts.firstIndex(of: "at"), atIdx + 1 < parts.count {
            let rawMac = parts[atIdx + 1]
            return formatMAC(rawMac)
        }
        return nil
    }
}
