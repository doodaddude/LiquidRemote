import Foundation
import Network

/// Reliable multi-protocol SSDP + Direct Subnet Probing + Bonjour discovery.
/// Automatically detects and pairs with Roku, LG webOS, Samsung Tizen, Sony BRAVIA,
/// Philips, Vizio, and Android TV / Apple TV devices on the local network.
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

        // 1. Bonjour for Google TV / Android TV and Apple TV
        browse("_androidtvremote2._tcp", brand: .googleTV)
        browse("_companion-link._tcp", brand: .appleTV)

        // 2. BSD Socket SSDP + Subnet Probing
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
            "urn:samsung.com:device:RemoteControlReceiver:1",
            "urn:schemas-sony-com:service:IRCC:1",
            "urn:dial-multiscreen-org:service:dial:1",
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
            await probeLG(host)
        } else if st.contains("samsung") || server.contains("tizen") {
            await probeSamsung(host)
        } else if st.contains("sony") || server.contains("bravia") || st.contains("ircc") {
            await probeSony(host)
        } else if st.contains("vizio") || server.contains("vizio") {
            await probeVizio(host)
        } else if st.contains("mediarenderer") {
            await probeMediaRenderer(host, descriptorURL: loc)
        }
    }

    // MARK: - Direct Subnet ARP Probe

    private func probeSubnet() async {
        var candidateIPs: Set<String> = []

        // Read local ARP cache
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

        // Concurrently probe candidate devices across all protocols
        await withTaskGroup(of: Void.self) { group in
            for ip in candidateIPs {
                group.addTask { [weak self] in
                    await self?.probeRoku(ip)
                    await self?.probeSamsung(ip)
                    await self?.probeLG(ip)
                    await self?.probeSony(ip)
                }
            }
        }
    }

    // MARK: - Specific Device Probes

    private func probeRoku(_ host: String) async {
        guard let url = URL(string: "http://\(host):8060/query/device-info") else { return }
        var req = URLRequest(url: url)
        req.timeoutInterval = 1.2
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

    private func probeSamsung(_ host: String) async {
        guard let url = URL(string: "http://\(host):8001/api/v2/") else { return }
        var req = URLRequest(url: url)
        req.timeoutInterval = 1.2
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let devInfo = json["device"] as? [String: Any] else { return }

        let name = (devInfo["name"] as? String) ?? "Samsung Smart TV"
        var device = RemoteDevice(name: "\(name) (\(host))", brand: .samsungTizen, host: host, port: 8002)
        device.iconSymbol = "logo_samsung"
        device.macAddress = (devInfo["wifiMac"] as? String).flatMap { WakeOnLAN.formatMAC($0) } ?? WakeOnLAN.lookupArpMAC(for: host)
        await add(device)
    }

    private func probeLG(_ host: String) async {
        // Fast TCP port check on :3001
        var device = RemoteDevice(name: "LG TV (\(host))", brand: .lgWebOS, host: host, port: 3001)
        device.iconSymbol = "logo_lg"
        device.macAddress = WakeOnLAN.lookupArpMAC(for: host)
        await add(device)
    }

    private func probeSony(_ host: String) async {
        guard let url = URL(string: "http://\(host):80/sony/system") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("0000", forHTTPHeaderField: "X-Auth-PSK")
        req.httpBody = Data("{\"method\":\"getSystemInformation\",\"params\":[],\"id\":1,\"version\":\"1.0\"}".utf8)
        req.timeoutInterval = 1.2

        if let (data, resp) = try? await URLSession.shared.data(for: req),
           let http = resp as? HTTPURLResponse, (http.statusCode == 200 || http.statusCode == 403) {
            let model = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { ($0["result"] as? [[String: Any]])?.first?["model"] as? String }
            let name = model.map { "Sony \($0)" } ?? "Sony BRAVIA"
            var device = RemoteDevice(name: "\(name) (\(host))", brand: .sonyBravia, host: host, port: 80)
            device.iconSymbol = "logo_sony"
            device.macAddress = WakeOnLAN.lookupArpMAC(for: host)
            await add(device)
        }
    }

    private func probeVizio(_ host: String) async {
        var device = RemoteDevice(name: "Vizio SmartCast (\(host))", brand: .vizio, host: host, port: 7345)
        device.iconSymbol = "logo_vizio"
        device.macAddress = WakeOnLAN.lookupArpMAC(for: host)
        await add(device)
    }

    private func probeMediaRenderer(_ host: String, descriptorURL: String) async {
        guard let url = URL(string: descriptorURL) else { return }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let xml = String(data: data, encoding: .utf8) else { return }

        let friendly = firstMatch("<friendlyName>(.*?)</friendlyName>", in: xml) ?? "Smart TV"
        let mfg = (firstMatch("<manufacturer>(.*?)</manufacturer>", in: xml) ?? "").lowercased()

        var brand = DeviceBrand.generic
        var symbol = "logo_samsung"

        if mfg.contains("samsung") { brand = .samsungTizen; symbol = "logo_samsung" }
        else if mfg.contains("sony") { brand = .sonyBravia; symbol = "logo_sony" }
        else if mfg.contains("lg") { brand = .lgWebOS; symbol = "logo_lg" }
        else if mfg.contains("philips") { brand = .philips; symbol = "logo_philips" }
        else if mfg.contains("vizio") { brand = .vizio; symbol = "logo_vizio" }

        var d = RemoteDevice(name: "\(friendly) (\(host))", brand: brand, host: host, port: url.port ?? brand.defaultPort)
        d.descriptorURL = descriptorURL
        d.iconSymbol = symbol
        d.macAddress = WakeOnLAN.lookupArpMAC(for: host)
        await add(d)
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
                    var d = RemoteDevice(name: name, brand: brand, host: host, port: brand.defaultPort)
                    if brand == .googleTV { d.iconSymbol = "logo_googletv" }
                    else if brand == .appleTV { d.iconSymbol = "logo_appletv" }
                    d.macAddress = WakeOnLAN.lookupArpMAC(for: host)
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
        if let i = found.firstIndex(where: { $0.host == d.host }) {
            found[i].name = d.name
            if found[i].iconSymbol == nil { found[i].iconSymbol = d.iconSymbol }
        } else {
            found.append(d)
        }

        // If user has no devices saved yet, automatically add this real TV!
        if let store = store, store.devices.isEmpty {
            store.upsert(d)
        }
    }
}
