import SwiftUI

struct LiquidRemoteView: View {
    @ObservedObject var hub: RemoteHub
    @ObservedObject var panel: PanelState
    @ObservedObject private var store: DeviceStore
    @State private var selectedID: UUID
    @State private var volumeLevel: Double = 0.5
    @State private var isDraggingVolume: Bool = false
    @State private var dragAnchorVolume: Double = 0.5
    @StateObject private var scroll = ScrollGestureMonitor()
    @AppStorage("requireDoubleTapSelect") private var requireDoubleTap = false
    @AppStorage("glassTranslucency") private var translucency: Double = 0.75
    @AppStorage("presetAppCount") private var presetCount: Int = 4
    @AppStorage("presetAppIDs") private var presetAppIDs: String = "netflix,youtube,spotify,appletv,disneyplus,primevideo,hulu,max"

    init(hub: RemoteHub, panel: PanelState, initialDevice: UUID) {
        self.hub = hub
        self.panel = panel
        self.store = hub.store
        let defaultID = hub.store.devices.first?.id ?? initialDevice
        _selectedID = State(initialValue: defaultID)
    }

    private var device: RemoteDevice {
        store.device(selectedID) ?? store.devices.first ?? RemoteDevice(name: "No TV Connected", brand: .roku, host: "", port: 8060)
    }
    private var accent: Color { device.accentColor }
    private var caps: RemoteCapabilities { hub.capabilities(for: device.id) }
    private var target: RemoteDevice? { store.devices.isEmpty ? nil : device }

    private var currentPresetIDs: [String] {
        let list = presetAppIDs.split(separator: ",").map { String($0) }
        return list.isEmpty ? RemoteApp.defaultPresetIDs : list
    }

    private var activeApps: [RemoteApp] {
        let ids = currentPresetIDs
        let count = [2, 4, 6, 8].contains(presetCount) ? presetCount : 4
        var list: [RemoteApp] = []
        for i in 0..<count {
            if i < ids.count {
                list.append(RemoteApp.app(for: ids[i]))
            } else {
                list.append(RemoteApp.catalog[i % RemoteApp.catalog.count])
            }
        }
        return list
    }

    private func setPresetApp(_ id: String, at index: Int) {
        var ids = currentPresetIDs
        while ids.count <= index {
            ids.append(RemoteApp.catalog[ids.count % RemoteApp.catalog.count].id)
        }
        ids[index] = id
        presetAppIDs = ids.joined(separator: ",")
    }

    var body: some View {
        VStack(spacing: 14) {
            deviceBar
            header
            DPadView(accent: accent, requireDoubleTapSelect: requireDoubleTap) { send($0) }
            homeAndActionRow
            mediaRow
            volumeRow
            appGrid
            if let err = hub.lastError {
                errorBanner(err)
            }
        }
        .padding(20)
        .frame(width: 320)
        .liquidGlass(accent: accent, translucency: translucency)
        .padding(24)                                          // room for the drop shadow
        .scaleEffect(panel.isPresented ? 1 : 0.9, anchor: .top)
        .opacity(panel.isPresented ? 1 : 0)
        .offset(y: panel.isPresented ? 0 : -12)
        .animation(.interpolatingSpring(stiffness: 300, damping: 25), value: panel.isPresented)
        .animation(.interpolatingSpring(stiffness: 300, damping: 25), value: selectedID)
        .animation(.easeInOut(duration: 0.2), value: translucency)
        .onAppear(perform: bindGestures)
        .onDisappear { scroll.stop() }
        .onChange(of: panel.isPresented) { _, shown in
            if shown { scroll.start() } else { scroll.stop() }
        }
        .onChange(of: store.devices) { _, newDevices in
            if store.device(selectedID) == nil, let first = newDevices.first {
                selectedID = first.id
            }
        }
        .onChange(of: hub.lastError) { _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                panel.requestResize?()
            }
        }
        .onChange(of: presetCount) { _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                panel.requestResize?()
            }
        }
    }

    // MARK: Brand / device selector (pill bar)

    private var deviceBar: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    let grouped = Dictionary(grouping: store.devices, by: \.brand)
                    if store.devices.isEmpty {
                        Text("No TV Connected")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 6)
                    } else {
                        ForEach(DeviceBrand.allCases.filter { grouped[$0] != nil && $0 != .universal }, id: \.self) { brand in
                            HStack(spacing: 5) {
                                // Real brand logo badge header
                                BrandLogoView(brand: brand, size: 14)
                                    .padding(.leading, 3)

                                Text(brand.displayName.uppercased())
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundStyle(.secondary)
                                    .padding(.trailing, 2)

                                ForEach(grouped[brand] ?? []) { d in
                                    Button { selectedID = d.id } label: {
                                        HStack(spacing: 5) {
                                            BrandLogoView(brand: d.brand, customSymbol: d.iconSymbol, size: 14)
                                            Text(d.name)
                                                .font(.system(size: 11, weight: .semibold))
                                        }
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 6)
                                        .foregroundStyle(selectedID == d.id ? Color.white : Color.secondary)
                                        .background(Capsule().fill(selectedID == d.id ? d.accentColor.opacity(0.65) : .white.opacity(0.08)))
                                        .overlay(Capsule().strokeBorder(selectedID == d.id ? .white.opacity(0.4) : .white.opacity(0.12), lineWidth: 0.5))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.05)))
                        }
                    }

                    Button {
                        AppDelegate.shared?.showSettings()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .foregroundStyle(Color.secondary)
                            .background(Capsule().fill(.white.opacity(0.08)))
                            .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .help("Add or manage devices")
                }
            }
            optionsMenu
        }
    }

    private var optionsMenu: some View {
        Menu {
            if !store.devices.isEmpty {
                // Wake-on-LAN option
                Button {
                    wakeCurrentDevice()
                } label: {
                    Label(device.macAddress != nil ? "Wake TV (Wake-on-LAN)" : "Wake TV (Send WoL)", systemImage: "bolt.fill")
                }

                Divider()

                // Preset Apps Menu (2, 4, 6, or 8 Apps)
                Menu("Preset Apps (\(presetCount))") {
                    Section("Number of App Buttons") {
                        ForEach([2, 4, 6, 8], id: \.self) { count in
                            Button {
                                presetCount = count
                            } label: {
                                HStack {
                                    Text("\(count) Apps")
                                    if presetCount == count {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }

                    Divider()

                    Section("Select Preset Apps") {
                        ForEach(0..<presetCount, id: \.self) { slotIndex in
                            let currentID = slotIndex < currentPresetIDs.count ? currentPresetIDs[slotIndex] : ""
                            let currentApp = RemoteApp.app(for: currentID)
                            Menu("Button \(slotIndex + 1): \(currentApp.name)") {
                                ForEach(RemoteApp.catalog) { app in
                                    Button {
                                        setPresetApp(app.id, at: slotIndex)
                                    } label: {
                                        HStack {
                                            Label(app.name, systemImage: app.symbol)
                                            if app.id == currentID {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Divider()

                    Button("Reset to Default Apps") {
                        presetCount = 4
                        presetAppIDs = RemoteApp.defaultPresetIDs.joined(separator: ",")
                    }
                }

                // Real Brand Logos Picker (Top 20 TV & Top 10 Streaming)
                Menu("Brand Logo") {
                    Menu("Top 20 TV Brands") {
                        ForEach(DeviceIconOption.tvBrands) { opt in
                            Button {
                                store.update(device.id) {
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
                                store.update(device.id) {
                                    $0.iconSymbol = opt.symbol
                                    if opt.id == "stream_appletv" { $0.brand = .appleTV }
                                    else if opt.id == "stream_googletv" { $0.brand = .googleTV }
                                }
                            } label: {
                                Label(opt.name, systemImage: "play.tv")
                            }
                        }
                    }

                    Menu("Setup & Room Icons") {
                        ForEach(DeviceIconOption.setupIcons) { opt in
                            Button {
                                store.update(device.id) { $0.iconSymbol = opt.symbol }
                            } label: {
                                Label(opt.name, systemImage: opt.symbol)
                            }
                        }
                    }

                    Divider()
                    Button("Brand Default Logo") {
                        store.update(device.id) { $0.iconSymbol = nil }
                    }
                }

                // 18 Accent Color Presets
                Menu("Accent Color") {
                    Section("Warm & Crimson") {
                        colorButton(.crimson)
                        colorButton(.ruby)
                        colorButton(.sunset)
                        colorButton(.amber)
                        colorButton(.gold)
                    }
                    Section("Neon & Electric") {
                        colorButton(.lime)
                        colorButton(.mint)
                        colorButton(.teal)
                        colorButton(.cyan)
                    }
                    Section("Cool & Vivid") {
                        colorButton(.sky)
                        colorButton(.indigo)
                        colorButton(.purple)
                        colorButton(.magenta)
                        colorButton(.pink)
                        colorButton(.rose)
                    }
                    Section("Modern Neutrals") {
                        colorButton(.silver)
                        colorButton(.graphite)
                        colorButton(.obsidian)
                    }
                    Divider()
                    Button("Brand Default") { store.update(device.id) { $0.colorHex = nil } }
                }

                // Translucency Quick-steps
                Menu("Glass Translucency (\(Int(translucency * 100))%)") {
                    Button("Ultra Clear (90%)") { translucency = 0.90 }
                    Button("Liquid Glass (75%) — Default") { translucency = 0.75 }
                    Button("Medium Frost (60%)") { translucency = 0.60 }
                    Button("Frosted Dark (40%)") { translucency = 0.40 }
                    Button("Solid Slate (20%)") { translucency = 0.20 }
                }

                Toggle("Pin to menu bar", isOn: Binding(
                    get: { device.pinned },
                    set: { v in store.update(device.id) { $0.pinned = v } }))
            }

            Toggle("Double-tap center to select", isOn: $requireDoubleTap)
            Divider()
            Button("Devices & Settings…") {
                AppDelegate.shared?.showSettings()
            }
            Button("Quit LiquidRemote") { NSApp.terminate(nil) }
        } label: {
            Image(systemName: "ellipsis.circle").font(.system(size: 15))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private func colorButton(_ p: AccentPreset) -> some View {
        Button {
            store.update(device.id) { $0.colorHex = p.hex }
        } label: {
            HStack {
                Text(p.name)
                Spacer()
                Circle().fill(Color(hex: p.hex)).frame(width: 8, height: 8)
            }
        }
    }

    // MARK: Header — status / now playing

    private var header: some View {
        let np = hub.nowPlaying[device.id]
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(accent.opacity(0.25))
                if let url = np?.artworkURL {
                    AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: {
                        Image(systemName: "play.fill")
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    BrandLogoView(brand: device.brand, customSymbol: device.iconSymbol, size: 36)
                }
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 2) {
                Text(store.devices.isEmpty ? "No TV Connected" : (np?.title ?? device.name))
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(store.devices.isEmpty ? "Click + to scan or add TV" : (np?.subtitle ?? "\(device.brand.displayName) • Ready"))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if device.macAddress != nil {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(accent.opacity(0.85))
                            .help("Wake-on-LAN Ready")
                    }
                }
            }
            Spacer()
            Button { send(.power) } label: {
                Image(systemName: "power")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(GlassPressStyle(accent: .red))
            .help("Power / Wake-on-LAN")
        }
        .padding(12)
        .background(.thinMaterial.opacity(0.85), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: Home & Action Row (Star *, Home, Sleep Mode)

    private var homeAndActionRow: some View {
        HStack(spacing: 8) {
            // Star / Options Button (*)
            Button { send(.star) } label: {
                Image(systemName: "star.fill")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 44, height: 36)
            }
            .buttonStyle(GlassPressStyle(accent: accent, radius: 12))
            .help("Star / Options (*)")

            // Home Button (House)
            Button { send(.home) } label: {
                HStack(spacing: 6) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Home")
                        .font(.system(size: 13, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 36)
            }
            .buttonStyle(GlassPressStyle(accent: accent, radius: 12))
            .help("Home")

            // Sleep Mode Button
            Button { send(.sleep) } label: {
                HStack(spacing: 4) {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("Sleep")
                        .font(.system(size: 12, weight: .bold))
                }
                .frame(width: 66, height: 36)
            }
            .buttonStyle(GlassPressStyle(accent: accent, radius: 12))
            .help("Sleep Mode / Standby")
        }
    }

    // MARK: Media row

    private var mediaRow: some View {
        HStack(spacing: 10) {
            round("chevron.backward", .back)
            round("backward.fill", .rewind)
            round("playpause.fill", .playPause, big: true)
            round("forward.fill", .fastForward)
            round("speaker.slash.fill", .mute)
        }
    }

    private func round(_ symbol: String, _ key: RemoteKey, big: Bool = false) -> some View {
        Button { send(key) } label: {
            Image(systemName: symbol)
                .font(.system(size: big ? 17 : 13, weight: .semibold))
                .frame(width: big ? 46 : 36, height: big ? 46 : 36)
        }
        .buttonStyle(GlassPressStyle(accent: accent))
    }

    // MARK: Liquid Glass Volume Control (No Numbers, Pure Elegance)

    private var volumeRow: some View {
        HStack(spacing: 8) {
            // Volume Down Button
            Button {
                send(.volumeDown)
                withAnimation(.easeOut(duration: 0.15)) {
                    volumeLevel = max(0.05, volumeLevel - 0.04)
                }
            } label: {
                Image(systemName: "speaker.minus.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 36, height: 34)
            }
            .buttonStyle(GlassPressStyle(accent: accent, radius: 11))
            .help("Volume Down")

            // Custom Interactive Liquid Glass Bar (No Numbers)
            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height
                let fillW = max(height, min(width, width * CGFloat(volumeLevel)))

                ZStack(alignment: .leading) {
                    // Glass Pill Track
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.07))
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                        )

                    // Luminous Accent Fill
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.6), accent.opacity(0.95)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: fillW, height: height)
                        .shadow(color: accent.opacity(0.4), radius: isDraggingVolume ? 6 : 3, x: 0, y: 0)

                    // Subtle Glass Thumb Handle
                    Circle()
                        .fill(Color.white)
                        .frame(width: height - 4, height: height - 4)
                        .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 1)
                        .offset(x: max(2, min(width - height + 2, fillW - height + 2)))
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            isDraggingVolume = true
                            let progress = max(0.0, min(1.0, Double(val.location.x / width)))
                            let delta = progress - dragAnchorVolume
                            volumeLevel = progress

                            if abs(delta) >= 0.04 {
                                let key: RemoteKey = delta > 0 ? .volumeUp : .volumeDown
                                send(key)
                                dragAnchorVolume = progress
                            }
                        }
                        .onEnded { _ in
                            isDraggingVolume = false
                            dragAnchorVolume = volumeLevel
                        }
                )
            }
            .frame(height: 20)
            .padding(.vertical, 7)

            // Volume Up Button
            Button {
                send(.volumeUp)
                withAnimation(.easeOut(duration: 0.15)) {
                    volumeLevel = min(1.0, volumeLevel + 0.04)
                }
            } label: {
                Image(systemName: "speaker.plus.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 36, height: 34)
            }
            .buttonStyle(GlassPressStyle(accent: accent, radius: 11))
            .help("Volume Up")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        )
    }

    // MARK: Error Banner (Fully visible, wrapped, dismissible)

    private func errorBanner(_ err: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(hex: "#FF5252"))
                .padding(.top, 2)

            Text(err)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.95))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    hub.lastError = nil
                    panel.requestResize?()
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
            .help("Dismiss error")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hex: "#2C1214").opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color(hex: "#FF5252").opacity(0.45), lineWidth: 1)
                )
        )
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    // MARK: Configurable Apps Grid (2, 4, 6, or 8 Apps)

    private var appGrid: some View {
        let apps = activeApps
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
            ForEach(Array(apps.enumerated()), id: \.offset) { _, app in
                Button {
                    Haptics.tap()
                    hub.launch(app, on: device.id)
                } label: {
                    Label(app.name, systemImage: app.symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(GlassPressStyle(accent: accent, radius: 14))
            }
        }
    }

    // MARK: Actions

    private func send(_ key: RemoteKey) {
        guard !store.devices.isEmpty else {
            AppDelegate.shared?.showSettings()
            return
        }
        Haptics.tap()
        hub.send(key, to: device.id)
    }

    private func wakeCurrentDevice() {
        Haptics.tap()
        if let mac = device.macAddress, !mac.isEmpty {
            hub.wake(device.id)
        } else if let arpMac = WakeOnLAN.lookupArpMAC(for: device.host) {
            store.update(device.id) { $0.macAddress = arpMac }
            hub.wake(device.id)
        }
    }

    private func bindGestures() {
        scroll.onVertical = { dir in
            let key: RemoteKey = dir > 0 ? .volumeUp : .volumeDown
            send(key)
            withAnimation(.easeOut(duration: 0.15)) {
                volumeLevel = dir > 0 ? min(1.0, volumeLevel + 0.04) : max(0.05, volumeLevel - 0.04)
            }
        }
        scroll.onHorizontal = { [device] dir in hub.send(dir > 0 ? .fastForward : .rewind, to: device.id) }
        if panel.isPresented { scroll.start() }
    }
}
