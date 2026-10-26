import SwiftUI

struct SettingsView: View {
    @ObservedObject var hub: RemoteHub
    @ObservedObject var store: DeviceStore
    @ObservedObject var discovery: DeviceDiscovery
    @AppStorage("showMenuBarLabels") private var showLabels = false
    @AppStorage("glassTranslucency") private var translucency: Double = 0.75
    @AppStorage("presetAppCount") private var presetCount: Int = 4
    @AppStorage("presetAppIDs") private var presetAppIDs: String = "netflix,youtube,spotify,appletv,disneyplus,primevideo,hulu,max"

    @State private var manualHost = ""
    @State private var manualBrand = DeviceBrand.roku
    @State private var manualMAC = ""
    @State private var isConnecting = false
    @State private var statusMessage: String?
    @State private var wolSentID: UUID?

    private var currentPresetIDs: [String] {
        let list = presetAppIDs.split(separator: ",").map { String($0) }
        return list.isEmpty ? RemoteApp.defaultPresetIDs : list
    }

    private func bindingForSlot(_ index: Int) -> Binding<String> {
        Binding(
            get: {
                let ids = currentPresetIDs
                return index < ids.count ? ids[index] : (RemoteApp.catalog[index % RemoteApp.catalog.count].id)
            },
            set: { newID in
                var ids = currentPresetIDs
                while ids.count <= index {
                    ids.append(RemoteApp.catalog[ids.count % RemoteApp.catalog.count].id)
                }
                ids[index] = newID
                presetAppIDs = ids.joined(separator: ",")
            }
        )
    }

    var body: some View {
        Form {
            Section("Liquid Glass Translucency") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Glass Translucency", systemImage: "sparkles.rectangle.stack")
                            .font(.body.weight(.medium))
                        Spacer()
                        Text("\(Int(translucency * 100))%")
                            .font(.callout.monospacedDigit().bold())
                            .foregroundStyle(Color.accentColor)
                    }

                    Slider(value: $translucency, in: 0.15...1.0)
                        .tint(.accentColor)

                    HStack {
                        Text("Frosted Solid (15%)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Crystal Clear Liquid (100%)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Your Devices (Grouped by Brand)") {
                if store.devices.isEmpty {
                    Text("No devices added yet. Discovered devices appear below, or enter an IP address to connect.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    let grouped = Dictionary(grouping: store.devices, by: \.brand)
                    ForEach(DeviceBrand.allCases.filter { grouped[$0] != nil && $0 != .universal }, id: \.self) { brand in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                BrandLogoView(brand: brand, size: 16)
                                Text(brand.displayName.uppercased())
                                    .font(.caption.bold())
                                    .foregroundStyle(Color.secondary)
                            }

                            ForEach(grouped[brand] ?? []) { d in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 8) {
                                        // Real Brand Logo & Icon Picker Menu
                                        Menu {
                                            Menu("Top 20 TV Brands") {
                                                ForEach(DeviceIconOption.tvBrands) { opt in
                                                    Button {
                                                        store.update(d.id) {
                                                            $0.iconSymbol = opt.symbol
                                                            if opt.id == "tv_roku" { $0.brand = .roku }
                                                            else if opt.id == "tv_lg" { $0.brand = .lgWebOS }
                                                            else if opt.id == "tv_samsung" || opt.id == "tv_sony" { $0.brand = .generic }
                                                        }
                                                    } label: {
                                                        Label(opt.name, systemImage: "tv")
                                                    }
                                                }
                                            }

                                            Menu("Top 10 Streaming Devices") {
                                                ForEach(DeviceIconOption.streamingDevices) { opt in
                                                    Button {
                                                        store.update(d.id) {
                                                            $0.iconSymbol = opt.symbol
                                                            if opt.id == "stream_appletv" { $0.brand = .appleTV }
                                                            else if opt.id == "stream_googletv" { $0.brand = .googleTV }
                                                        }
                                                    } label: {
                                                        Label(opt.name, systemImage: "play.tv")
                                                    }
                                                }
                                            }

                                            Menu("Alternative Setup Icons") {
                                                ForEach(DeviceIconOption.setupIcons) { opt in
                                                    Button {
                                                        store.update(d.id) { $0.iconSymbol = opt.symbol }
                                                    } label: {
                                                        Label(opt.name, systemImage: opt.symbol)
                                                    }
                                                }
                                            }

                                            Divider()
                                            Button("Brand Default Logo") {
                                                store.update(d.id) { $0.iconSymbol = nil }
                                            }
                                        } label: {
                                            BrandLogoView(brand: d.brand, customSymbol: d.iconSymbol, size: 28)
                                        }
                                        .buttonStyle(.plain)
                                        .help("Change Brand Logo or Icon")

                                        // Name Field
                                        TextField("Name", text: Binding(get: { d.name },
                                                                        set: { n in store.update(d.id) { $0.name = n } }))
                                            .textFieldStyle(.roundedBorder)

                                        // Accent Color Picker Menu (18 Colors)
                                        Menu {
                                            Section("Warm & Crimson") {
                                                ForEach([AccentPreset.crimson, .ruby, .sunset, .amber, .gold]) { p in
                                                    Button(p.name) { store.update(d.id) { $0.colorHex = p.hex } }
                                                }
                                            }
                                            Section("Neon & Electric") {
                                                ForEach([AccentPreset.lime, .mint, .teal, .cyan]) { p in
                                                    Button(p.name) { store.update(d.id) { $0.colorHex = p.hex } }
                                                }
                                            }
                                            Section("Cool & Vivid") {
                                                ForEach([AccentPreset.sky, .indigo, .purple, .magenta, .pink, .rose]) { p in
                                                    Button(p.name) { store.update(d.id) { $0.colorHex = p.hex } }
                                                }
                                            }
                                            Section("Neutrals") {
                                                ForEach([AccentPreset.silver, .graphite, .obsidian]) { p in
                                                    Button(p.name) { store.update(d.id) { $0.colorHex = p.hex } }
                                                }
                                            }
                                            Divider()
                                            Button("Brand Default") { store.update(d.id) { $0.colorHex = nil } }
                                        } label: {
                                            Circle()
                                                .fill(d.accentColor)
                                                .frame(width: 16, height: 16)
                                                .overlay(Circle().stroke(Color.primary.opacity(0.2), lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                        .help("Change Accent Color")

                                        Text(d.host)
                                            .font(.caption.monospaced())
                                            .foregroundStyle(.secondary)

                                        Toggle("Pin", isOn: Binding(get: { d.pinned },
                                                                   set: { v in store.update(d.id) { $0.pinned = v } }))
                                            .toggleStyle(.switch)
                                            .controlSize(.small)

                                        Button(role: .destructive) { store.remove(d.id) } label: {
                                            Image(systemName: "trash")
                                        }
                                        .buttonStyle(.borderless)
                                    }

                                    // Wake-on-LAN Row
                                    HStack(spacing: 8) {
                                        Label("Wake-on-LAN MAC:", systemImage: "bolt.fill")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        TextField("e.g. 64:6E:69:21:A8:57", text: Binding(
                                            get: { d.macAddress ?? "" },
                                            set: { m in store.update(d.id) { $0.macAddress = m.trimmingCharacters(in: .whitespaces).isEmpty ? nil : m } }
                                        ))
                                        .textFieldStyle(.roundedBorder)
                                        .font(.caption.monospaced())

                                        Button {
                                            sendWoL(for: d)
                                        } label: {
                                            Label(wolSentID == d.id ? "Packet Sent!" : "Wake TV", systemImage: "bolt.horizontal.fill")
                                                .font(.caption.weight(.medium))
                                        }
                                        .controlSize(.small)
                                        .buttonStyle(.bordered)
                                        .tint(wolSentID == d.id ? .green : .accentColor)
                                    }
                                    .padding(.leading, 36)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("Discovered Devices (Grouped by Brand)") {
                if discovery.found.isEmpty {
                    if discovery.isScanning {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Searching local network for TVs and streaming players…")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("No devices discovered automatically yet.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    let groupedDiscovered = Dictionary(grouping: discovery.found, by: \.brand)
                    ForEach(DeviceBrand.allCases.filter { groupedDiscovered[$0] != nil && $0 != .universal }, id: \.self) { brand in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                BrandLogoView(brand: brand, size: 16)
                                Text(brand.displayName.uppercased())
                                    .font(.caption.bold())
                                    .foregroundStyle(Color.secondary)
                            }

                            ForEach(groupedDiscovered[brand] ?? []) { d in
                                HStack {
                                    HStack(spacing: 10) {
                                        BrandLogoView(brand: d.brand, customSymbol: d.iconSymbol, size: 24)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(d.name)
                                                .font(.body.weight(.medium))
                                            HStack(spacing: 6) {
                                                Text("\(d.brand.displayName) • \(d.host)")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                if let mac = d.macAddress {
                                                    Text("• WoL: \(mac)")
                                                        .font(.caption.monospaced())
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                        }
                                    }
                                    Spacer()
                                    if store.devices.contains(where: { $0.host == d.host }) {
                                        Label("Added", systemImage: "checkmark.circle.fill")
                                            .font(.caption.bold())
                                            .foregroundStyle(.green)
                                    } else {
                                        Button("Add to Remote") { store.upsert(d) }
                                            .buttonStyle(.borderedProminent)
                                            .controlSize(.small)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                Button(discovery.isScanning ? "Scanning…" : "Scan Network Again") {
                    discovery.start()
                }
                .disabled(discovery.isScanning)
            }

            Section("Add Device by IP") {
                Picker("Brand Category", selection: $manualBrand) {
                    Text("Roku").tag(DeviceBrand.roku)
                    Text("LG webOS").tag(DeviceBrand.lgWebOS)
                    Text("Google TV").tag(DeviceBrand.googleTV)
                    Text("Apple TV").tag(DeviceBrand.appleTV)
                    Text("Smart TV (UPnP)").tag(DeviceBrand.generic)
                }
                HStack {
                    TextField("IP Address (e.g. 192.168.68.102)", text: $manualHost)
                        .textFieldStyle(.roundedBorder)
                    TextField("MAC Address (Optional)", text: $manualMAC)
                        .textFieldStyle(.roundedBorder)
                    Button(isConnecting ? "Connecting…" : "Add Device") {
                        addManualDevice()
                    }
                    .disabled(manualHost.trimmingCharacters(in: .whitespaces).isEmpty || isConnecting)
                }
                if let msg = statusMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Preset Quick-Launch Apps") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Visible App Buttons:")
                            .font(.body.weight(.medium))
                        Spacer()
                        Picker("", selection: $presetCount) {
                            Text("2 Apps").tag(2)
                            Text("4 Apps").tag(4)
                            Text("6 Apps").tag(6)
                            Text("8 Apps").tag(8)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 250)
                    }

                    Divider()

                    Text("Customize App Buttons (1 to \(presetCount)):")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 8) {
                        ForEach(0..<presetCount, id: \.self) { slot in
                            HStack(spacing: 8) {
                                Text("Btn \(slot + 1):")
                                    .font(.caption.monospaced().bold())
                                    .frame(width: 44, alignment: .leading)

                                Picker("", selection: bindingForSlot(slot)) {
                                    ForEach(RemoteApp.catalog) { app in
                                        Label(app.name, systemImage: app.symbol).tag(app.id)
                                    }
                                }
                                .labelsHidden()
                            }
                        }
                    }

                    HStack {
                        Spacer()
                        Button("Reset to Default Apps") {
                            presetCount = 4
                            presetAppIDs = RemoteApp.defaultPresetIDs.joined(separator: ",")
                        }
                        .font(.caption)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Menu Bar Appearance") {
                Toggle("Show device name next to icon in menu bar", isOn: $showLabels)
            }
        }
        .formStyle(.grouped)
        .frame(width: 540, height: 600)
        .onAppear { discovery.start() }
    }

    private func sendWoL(for d: RemoteDevice) {
        let macToUse = d.macAddress ?? WakeOnLAN.lookupArpMAC(for: d.host)
        if let mac = macToUse {
            if d.macAddress == nil {
                store.update(d.id) { $0.macAddress = mac }
            }
            Task {
                await WakeOnLAN.wake(mac: mac, ip: d.host)
                await MainActor.run {
                    wolSentID = d.id
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        if wolSentID == d.id { wolSentID = nil }
                    }
                }
            }
        }
    }

    private func addManualDevice() {
        let host = manualHost.trimmingCharacters(in: .whitespaces)
        guard !host.isEmpty else { return }
        isConnecting = true
        statusMessage = nil

        let brand = manualBrand
        var device = RemoteDevice(name: "\(brand.displayName) (\(host))",
                                  brand: brand,
                                  host: host,
                                  port: brand.defaultPort)

        let macEntered = manualMAC.trimmingCharacters(in: .whitespaces)
        device.macAddress = !macEntered.isEmpty ? WakeOnLAN.formatMAC(macEntered) : WakeOnLAN.lookupArpMAC(for: host)

        if brand == .roku {
            Task {
                var friendlyName: String?
                if let url = URL(string: "http://\(host):8060/query/device-info"),
                   let (data, _) = try? await URLSession.shared.data(from: url),
                   let xml = String(data: data, encoding: .utf8) {
                    friendlyName = firstMatch("<friendly-device-name>(.*?)</friendly-device-name>", in: xml)
                        ?? firstMatch("<model-name>(.*?)</model-name>", in: xml)
                    if device.macAddress == nil {
                        let wifiMac = firstMatch("<wifi-mac>(.*?)</wifi-mac>", in: xml)
                        let ethMac = firstMatch("<ethernet-mac>(.*?)</ethernet-mac>", in: xml)
                        device.macAddress = (wifiMac ?? ethMac).flatMap { WakeOnLAN.formatMAC($0) }
                    }
                }
                await MainActor.run {
                    if let friendlyName {
                        device.name = friendlyName
                        statusMessage = "Connected to \(friendlyName)!"
                    } else {
                        statusMessage = "Added Roku at \(host)."
                    }
                    store.upsert(device)
                    manualHost = ""
                    manualMAC = ""
                    isConnecting = false
                }
            }
        } else {
            store.upsert(device)
            statusMessage = "Added \(device.name)."
            manualHost = ""
            manualMAC = ""
            isConnecting = false
        }
    }
}
