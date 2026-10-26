import Foundation
import Network

/// Reliable SSDP (BSD Socket) + Local Subnet ARP Probing + Bonjour discovery.
final class DeviceDiscovery: ObservableObject {
    @Published private(set) var found: [RemoteDevice] = []
    @Published private(set) var isScanning = false

    weak var store: DeviceStore?

    private var browsers: [NWBrowser] = []
    private var scanTask: Task<Void, Never>?

    func start() {
        stop()
        found = []
        isScanning = true

        // 1. Bonjour for Google TV and verified Apple TV
        browse("_androidtvremote2._tcp", brand: .googleTV)
        browse("_companion-link._tcp", brand: .appleTV)

        // 2. BSD Socket SSDP + Subnet ARP Probing
        scanTask = Task.detached(priority: .userInitiated) { [weak self] in
            await self?.runSSDP()
            await self?.probeSubnet()

            // Keep scanning for 6 seconds
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            await MainActor.run {
                self?.isScanning = false
            }
        }
    }

    func stop() {
        browsers.forEach { $0.cancel() }
        browsers = []
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
    }

    // MARK: - BSD Socket SSDP

    private func runSSDP() async {
        let sock = socket(AF_INET, SOCK_DGRAM, 0)
        guard sock >= 0 else { return }
        defer { close(sock) }

        var ttl: UInt8 = 2
        setsockopt(sock, IPPROTO_IP, IP_MULTICAST_TTL, &ttl, socklen_t(MemoryLayout<UInt8>.size))

        var tv = timeval(tv_sec: 1, tv_usec: 500_000)
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        var dest = sockaddr_in()
        dest.sin_family = sa_family_t(AF_INET)
        dest.sin_port = UInt16(1900).bigEndian
        inet_pton(AF_INET, "239.255.255.250", &dest.sin_addr)

        let searchTargets = [
            "roku:ecp",
            "urn:lge-com:service:webos-second-screen:1",
            "urn:schemas-upnp-org:device:MediaRenderer:1",
            "ssdp:all"
        ]

        for st in searchTargets {
            let msg = "M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: \"ssdp:discover\"\r\nMX: 2\r\nST: \(st)\r\n\r\n"
            msg.withCString { ptr in
                withUnsafePointer(to: &dest) { destPtr in
                    destPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                        _ = sendto(sock, ptr, strlen(ptr), 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                    }
                }
            }
        }

        var buf = [UInt8](repeating: 0, count: 4096)
        var from = sockaddr_storage()
        var fromLen = socklen_t(MemoryLayout<sockaddr_storage>.size)

        while !Task.isCancelled {
            let n = withUnsafeMutablePointer(to: &from) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    recvfrom(sock, &buf, buf.count, 0, $0, &fromLen)
                }
            }
            if n <= 0 { break }
            let resp = String(decoding: buf[0..<n], as: UTF8.self)
            await handleSSDP(resp)
        }
    }

    private func handleSSDP(_ response: String) async {
        var headers: [String: String] = [:]
        for line in response.components(separatedBy: "\r\n").dropFirst() {
            guard let i = line.firstIndex(of: ":") else { continue }
            headers[line[..<i].lowercased()] = line[line.index(after: i)...].trimmingCharacters(in: .whitespaces)
        }

        guard let loc = headers["location"], let url = URL(string: loc), let host = url.host else { return }
        let st = (headers["st"] ?? "").lowercased()
        let server = (headers["server"] ?? "").lowercased()

        if st.contains("roku") || server.contains("roku") {
            await probeRoku(host)
        } else if st.contains("lge") || server.contains("webos") {
            let d = RemoteDevice(name: "LG TV (\(host))", brand: .lgWebOS, host: host, port: 3001)
            await add(d)
        } else if st.contains("mediarenderer") {
            var d = RemoteDevice(name: "Smart TV (\(host))", brand: .generic, host: host, port: url.port ?? 80)
            d.descriptorURL = loc
            await add(d)
        }
    }

    // MARK: - Direct Subnet ARP Probe

    private func probeSubnet() async {
        var candidateIPs: Set<String> = []

        // 1. Read ARP table
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/arp")
        p.arguments = ["-a"]
        let pipe = Pipe()
        p.standardOutput = pipe
        try? p.run()
        p.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let out = String(data: data, encoding: .utf8) {
            for line in out.components(separatedBy: "\n") {
                if let start = line.firstIndex(of: "("), let end = line.firstIndex(of: ")"), start < end {
                    let ip = String(line[line.index(after: start)..<end])
                    if !ip.starts(with: "224.") && !ip.starts(with: "239.") && !ip.hasSuffix(".255") {
                        candidateIPs.insert(ip)
                    }
                }
            }
        }

        // 2. Also check common Roku IP if known
        candidateIPs.insert("192.168.68.102")

        // Concurrently probe candidate devices
        await withTaskGroup(of: Void.self) { group in
            for ip in candidateIPs {
                group.addTask { [weak self] in
                    await self?.probeRoku(ip)
                }
            }
        }
    }

    private func probeRoku(_ host: String) async {
        guard let url = URL(string: "http://\(host):8060/query/device-info") else { return }
        var req = URLRequest(url: url)
        req.timeoutInterval = 1.5
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let xml = String(data: data, encoding: .utf8) else { return }

        let friendly = firstMatch("<friendly-device-name>(.*?)</friendly-device-name>", in: xml)
        let vendor = firstMatch("<vendor-name>(.*?)</vendor-name>", in: xml)
        let model = firstMatch("<model-name>(.*?)</model-name>", in: xml)
        let nameCandidate = friendly ?? [vendor, model].compactMap { $0 }.joined(separator: " ")
        let displayName = nameCandidate.isEmpty ? "Roku (\(host))" : nameCandidate

        let wifiMac = firstMatch("<wifi-mac>(.*?)</wifi-mac>", in: xml)
        let ethMac = firstMatch("<ethernet-mac>(.*?)</ethernet-mac>", in: xml)
        let rawMac = wifiMac ?? ethMac ?? WakeOnLAN.lookupArpMAC(for: host)
        let mac = rawMac.flatMap { WakeOnLAN.formatMAC($0) }

        var device = RemoteDevice(name: displayName, brand: .roku, host: host, port: 8060)
        device.macAddress = mac

        let lower = "\(vendor ?? "") \(displayName)".lowercased()
        if lower.contains("sharp") { device.iconSymbol = "logo_sharp" }
        else if lower.contains("tcl") { device.iconSymbol = "logo_tcl" }
        else if lower.contains("hisense") { device.iconSymbol = "logo_hisense" }
        else if lower.contains("philips") { device.iconSymbol = "logo_philips" }
        else if lower.contains("insignia") { device.iconSymbol = "logo_insignia" }
        else if lower.contains("hitachi") { device.iconSymbol = "logo_hitachi" }
        else if lower.contains("jvc") { device.iconSymbol = "logo_jvc" }
        else if lower.contains("toshiba") { device.iconSymbol = "logo_toshiba" }
        else if lower.contains("sceptre") { device.iconSymbol = "logo_sceptre" }
        else { device.iconSymbol = "logo_roku" }

        await add(device)
    }

    // MARK: - Bonjour

    private func browse(_ type: String, brand: DeviceBrand) {
        let b = NWBrowser(for: .bonjourWithTXTRecord(type: type, domain: nil), using: .tcp)
        b.browseResultsChangedHandler = { [weak self] results, _ in
            for r in results {
                guard case let .service(name, _, _, _) = r.endpoint else { continue }
                if brand == .appleTV {
                    guard case let .bonjour(txt) = r.metadata,
                          let model = txt["rpMd"], model.hasPrefix("AppleTV") else { continue }
                }
                self?.resolve(r.endpoint) { host in
                    guard let host, !host.contains(":"), !host.hasPrefix("fe80") else { return }
                    let d = RemoteDevice(name: name, brand: brand, host: host, port: brand.defaultPort)
                    Task { @MainActor [weak self] in
                        self?.add(d)
                    }
                }
            }
        }
        b.start(queue: .main)
        browsers.append(b)
    }

    private func resolve(_ endpoint: NWEndpoint, _ done: @escaping (String?) -> Void) {
        let c = NWConnection(to: endpoint, using: .tcp)
        c.stateUpdateHandler = { state in
            switch state {
            case .ready:
                if case let .hostPort(host, _)? = c.currentPath?.remoteEndpoint {
                    done("\(host)".components(separatedBy: "%").first)
                } else { done(nil) }
                c.cancel()
            case .failed: done(nil)
            default: break
            }
        }
        c.start(queue: .main)
    }

    // MARK: - Add Found Device

    @MainActor
    private func add(_ d: RemoteDevice) {
        if let i = found.firstIndex(where: { $0.host == d.host && $0.brand == d.brand }) {
            found[i].name = d.name
        } else {
            found.append(d)
        }

        // If user has no devices saved yet, automatically add this real TV!
        if let store = store, store.devices.isEmpty {
            store.upsert(d)
        }
    }
}
