import SwiftUI
import AppKit

// MARK: - Keys & capabilities

enum RemoteKey: String, CaseIterable {
    case up, down, left, right, select, back, home
    case playPause, rewind, fastForward
    case volumeUp, volumeDown, mute, power
    case star, sleep
}

struct RemoteCapabilities: OptionSet {
    let rawValue: Int
    static let absoluteVolume = RemoteCapabilities(rawValue: 1 << 0)
    static let nowPlaying     = RemoteCapabilities(rawValue: 1 << 1)
    static let appLaunch      = RemoteCapabilities(rawValue: 1 << 2)
    static let pairing        = RemoteCapabilities(rawValue: 1 << 3)
}

struct NowPlaying: Equatable {
    var title: String
    var subtitle: String?
    var isPlaying: Bool
    var artworkURL: URL?
}

// MARK: - Brands

enum DeviceBrand: String, Codable, CaseIterable, Identifiable {
    case roku
    case samsungTizen
    case lgWebOS
    case sonyBravia
    case googleTV
    case vizio
    case philips
    case fireTV
    case appleTV
    case generic
    case universal

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .roku: "Roku"
        case .samsungTizen: "Samsung Tizen"
        case .lgWebOS: "LG webOS"
        case .sonyBravia: "Sony BRAVIA"
        case .googleTV: "Google TV"
        case .vizio: "Vizio SmartCast"
        case .philips: "Philips JointSpace"
        case .fireTV: "Amazon Fire TV"
        case .appleTV: "Apple TV"
        case .generic: "Smart TV"
        case .universal: "Universal"
        }
    }

    /// Brand logo symbols instead of generic TV
    var symbol: String {
        switch self {
        case .roku: "r.square.fill"
        case .samsungTizen: "s.circle.fill"
        case .lgWebOS: "l.circle.fill"
        case .sonyBravia: "play.tv.fill"
        case .googleTV: "g.circle.fill"
        case .vizio: "v.circle.fill"
        case .philips: "p.circle.fill"
        case .fireTV: "flame.fill"
        case .appleTV: "apple.logo"
        case .generic: "display"
        case .universal: "dot.radiowaves.left.and.right"
        }
    }

    /// Brand-preset accent (user can override per device).
    var defaultHex: String {
        switch self {
        case .roku: "#E5213B"       // Crimson
        case .samsungTizen: "#0066FF" // Samsung Electric Blue
        case .lgWebOS: "#A50034"    // LG Ruby
        case .sonyBravia: "#FFFFFF" // Sony Monochrome
        case .googleTV: "#19E3F5"   // Neon cyan
        case .vizio: "#FF6600"      // Vizio Orange
        case .philips: "#00A3E0"    // Philips Cyan
        case .fireTV: "#FF9900"     // Amazon Fire Amber
        case .appleTV: "#B8BCC4"    // Space gray / silver
        case .generic: "#7C8CFF"
        case .universal: "#FFFFFF"
        }
    }

    var defaultPort: Int {
        switch self {
        case .roku: 8060
        case .samsungTizen: 8002
        case .lgWebOS: 3001
        case .sonyBravia: 80
        case .googleTV: 6466
        case .vizio: 7345
        case .philips: 1925
        case .fireTV: 8008
        case .appleTV: 49153
        case .generic, .universal: 80
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        switch raw.lowercased() {
        case "roku": self = .roku
        case "samsung", "samsungtizen", "tizen": self = .samsungTizen
        case "lgwebos", "lg", "webos": self = .lgWebOS
        case "sony", "sonybravia", "bravia": self = .sonyBravia
        case "googletv", "androidtv", "android": self = .googleTV
        case "vizio", "smartcast": self = .vizio
        case "philips", "jointspace": self = .philips
        case "firetv", "fire": self = .fireTV
        case "appletv", "apple": self = .appleTV
        case "universal": self = .universal
        default: self = .generic
        }
    }
}

// MARK: - Device

struct RemoteDevice: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var brand: DeviceBrand
    var host: String
    var port: Int
    var colorHex: String?
    var pinned = false
    var descriptorURL: String?      // UPnP device description
    var pairingToken: String?       // webOS client-key etc.
    var macAddress: String?         // Wake-on-LAN MAC address
    var iconSymbol: String?         // Custom brand logo / icon symbol override

    var symbol: String { iconSymbol ?? brand.symbol }
    var accentColor: Color { Color(hex: colorHex ?? brand.defaultHex) }

    static let universalID = UUID(uuidString: "00000000-0000-0000-0000-00000000A11A")!
    static let universal = RemoteDevice(id: universalID, name: "Universal", brand: .universal, host: "", port: 0)
}

// MARK: - Device Icon Gallery (Top 20 TV Brands & Top 10 Streaming Devices)

struct DeviceIconOption: Identifiable, Hashable {
    let id: String
    let name: String
    let symbol: String
    let category: String

    var isBrandLogo: Bool { symbol.hasPrefix("logo_") }

    // Top 20 TV Brands
    static let tvBrands: [DeviceIconOption] = [
        .init(id: "tv_samsung", name: "Samsung", symbol: "logo_samsung", category: "Top 20 TV Brands"),
        .init(id: "tv_lg", name: "LG", symbol: "logo_lg", category: "Top 20 TV Brands"),
        .init(id: "tv_sony", name: "Sony", symbol: "logo_sony", category: "Top 20 TV Brands"),
        .init(id: "tv_tcl", name: "TCL", symbol: "logo_tcl", category: "Top 20 TV Brands"),
        .init(id: "tv_hisense", name: "Hisense", symbol: "logo_hisense", category: "Top 20 TV Brands"),
        .init(id: "tv_vizio", name: "Vizio", symbol: "logo_vizio", category: "Top 20 TV Brands"),
        .init(id: "tv_roku", name: "Roku TV", symbol: "logo_roku", category: "Top 20 TV Brands"),
        .init(id: "tv_philips", name: "Philips", symbol: "logo_philips", category: "Top 20 TV Brands"),
        .init(id: "tv_panasonic", name: "Panasonic", symbol: "logo_panasonic", category: "Top 20 TV Brands"),
        .init(id: "tv_sharp", name: "Sharp", symbol: "logo_sharp", category: "Top 20 TV Brands"),
        .init(id: "tv_toshiba", name: "Toshiba", symbol: "logo_toshiba", category: "Top 20 TV Brands"),
        .init(id: "tv_insignia", name: "Insignia", symbol: "logo_insignia", category: "Top 20 TV Brands"),
        .init(id: "tv_jvc", name: "JVC", symbol: "logo_jvc", category: "Top 20 TV Brands"),
        .init(id: "tv_pioneer", name: "Pioneer", symbol: "logo_pioneer", category: "Top 20 TV Brands"),
        .init(id: "tv_sceptre", name: "Sceptre", symbol: "logo_sceptre", category: "Top 20 TV Brands"),
        .init(id: "tv_xiaomi", name: "Xiaomi", symbol: "logo_xiaomi", category: "Top 20 TV Brands"),
        .init(id: "tv_oneplus", name: "OnePlus", symbol: "logo_oneplus", category: "Top 20 TV Brands"),
        .init(id: "tv_skyworth", name: "Skyworth", symbol: "logo_skyworth", category: "Top 20 TV Brands"),
        .init(id: "tv_haier", name: "Haier", symbol: "logo_haier", category: "Top 20 TV Brands"),
        .init(id: "tv_hitachi", name: "Hitachi", symbol: "logo_hitachi", category: "Top 20 TV Brands"),
    ]

    // Top 10 Android / Streaming Devices
    static let streamingDevices: [DeviceIconOption] = [
        .init(id: "stream_nvidia", name: "NVIDIA Shield", symbol: "logo_nvidia", category: "Top 10 Streaming Devices"),
        .init(id: "stream_googletv", name: "Google TV", symbol: "logo_googletv", category: "Top 10 Streaming Devices"),
        .init(id: "stream_firetv", name: "Amazon Fire TV", symbol: "logo_firetv", category: "Top 10 Streaming Devices"),
        .init(id: "stream_mibox", name: "Xiaomi Mi Box", symbol: "logo_mibox", category: "Top 10 Streaming Devices"),
        .init(id: "stream_onn", name: "onn. Google TV", symbol: "logo_onn", category: "Top 10 Streaming Devices"),
        .init(id: "stream_tivo", name: "TiVo Stream 4K", symbol: "logo_tivo", category: "Top 10 Streaming Devices"),
        .init(id: "stream_mecool", name: "MECOOL", symbol: "logo_mecool", category: "Top 10 Streaming Devices"),
        .init(id: "stream_formuler", name: "Formuler", symbol: "logo_formuler", category: "Top 10 Streaming Devices"),
        .init(id: "stream_nokia", name: "Nokia Streaming", symbol: "logo_nokia", category: "Top 10 Streaming Devices"),
        .init(id: "stream_appletv", name: "Apple TV", symbol: "logo_appletv", category: "Top 10 Streaming Devices"),
    ]

    // Alternative Setup Icons
    static let setupIcons: [DeviceIconOption] = [
        .init(id: "living_room", name: "Living Room", symbol: "sofa.fill", category: "Room Setup"),
        .init(id: "bedroom", name: "Bedroom", symbol: "bed.double.fill", category: "Room Setup"),
        .init(id: "theater", name: "Home Theater", symbol: "theatermasks.fill", category: "Room Setup"),
        .init(id: "cinema", name: "Movie Player", symbol: "film.fill", category: "Room Setup"),
        .init(id: "gaming", name: "Game Console", symbol: "gamecontroller.fill", category: "Room Setup"),
        .init(id: "soundbar", name: "HiFi Soundbar", symbol: "hifispeaker.fill", category: "Room Setup"),
        .init(id: "entertainment", name: "Popcorn / Fun", symbol: "popcorn.fill", category: "Room Setup"),
        .init(id: "display", name: "Cinema Screen", symbol: "display", category: "Displays"),
        .init(id: "display_2", name: "Dual Display", symbol: "display.2", category: "Displays"),
        .init(id: "frameless", name: "Frameless OLED", symbol: "tv.inset.filled", category: "Displays"),
        .init(id: "media_box", name: "Media Center", symbol: "tv.and.mediabox.fill", category: "Displays"),
    ]

    static var all: [DeviceIconOption] {
        tvBrands + streamingDevices + setupIcons
    }
}

// MARK: - Apps & Catalog

struct RemoteApp: Identifiable, Hashable {
    let id: String
    let name: String
    let symbol: String
    var dialName: String? = nil
    let ids: [DeviceBrand: String]

    static let defaultPresetIDs = ["netflix", "youtube", "spotify", "appletv", "disneyplus", "primevideo", "hulu", "max"]

    static let catalog: [RemoteApp] = [
        .init(id: "netflix", name: "Netflix", symbol: "play.rectangle.fill", dialName: "Netflix",
              ids: [.roku: "12", .lgWebOS: "netflix", .samsungTizen: "3201907018807", .sonyBravia: "com.sony.dtv.com.netflix.ninja", .googleTV: "com.netflix.ninja", .fireTV: "Netflix", .appleTV: "com.netflix.Netflix"]),
        .init(id: "youtube", name: "YouTube", symbol: "play.tv.fill", dialName: "YouTube",
              ids: [.roku: "837", .lgWebOS: "youtube.leanback.v4", .samsungTizen: "111299001912", .sonyBravia: "com.sony.dtv.com.google.android.youtube.tv", .googleTV: "com.google.android.youtube.tv", .fireTV: "YouTube", .appleTV: "com.google.ios.youtube"]),
        .init(id: "primevideo", name: "Prime Video", symbol: "film.fill", dialName: "AmazonInstantVideo",
              ids: [.roku: "13", .lgWebOS: "amazon", .samsungTizen: "3201512006785", .sonyBravia: "com.sony.dtv.com.amazon.amazonvideo.livingroom", .googleTV: "com.amazon.amazonvideo.livingroom", .fireTV: "AmazonVideo", .appleTV: "com.amazon.aiv.AIVApp"]),
        .init(id: "disneyplus", name: "Disney+", symbol: "sparkles.tv.fill", dialName: "DisneyPlus",
              ids: [.roku: "291097", .lgWebOS: "com.disney.disneyplus-prod", .samsungTizen: "3201901017640", .sonyBravia: "com.sony.dtv.com.disney.disneyplus", .googleTV: "com.disney.disneyplus", .fireTV: "DisneyPlus", .appleTV: "com.disney.disneyplus"]),
        .init(id: "hulu", name: "Hulu", symbol: "play.circle.fill", dialName: "Hulu",
              ids: [.roku: "2285", .lgWebOS: "hulu", .samsungTizen: "3201601007625", .googleTV: "com.hulu.livingroomplus", .fireTV: "Hulu", .appleTV: "com.hulu.plus"]),
        .init(id: "max", name: "Max", symbol: "tv.fill", dialName: "Max",
              ids: [.roku: "61322", .lgWebOS: "com.wbd.stream", .samsungTizen: "3202302029707", .googleTV: "com.wbd.stream", .fireTV: "Max", .appleTV: "com.wbd.stream"]),
        .init(id: "appletv", name: "Apple TV", symbol: "appletv.fill",
              ids: [.roku: "551012", .lgWebOS: "com.apple.appletv", .samsungTizen: "3201807016597", .sonyBravia: "com.apple.atve.sony.appletv", .googleTV: "com.apple.atve.sony.appletv", .fireTV: "AppleTV", .appleTV: "com.apple.TVWatchList"]),
        .init(id: "spotify", name: "Spotify", symbol: "waveform.circle.fill", dialName: "Spotify",
              ids: [.roku: "22297", .lgWebOS: "spotify-beehive", .samsungTizen: "3201606009684", .googleTV: "com.spotify.tv.android", .fireTV: "Spotify", .appleTV: "com.spotify.client"]),
        .init(id: "paramountplus", name: "Paramount+", symbol: "mountain.2.fill", dialName: "ParamountPlus",
              ids: [.roku: "31440", .lgWebOS: "com.cbs.ott", .samsungTizen: "3201908019041", .googleTV: "com.cbs.app", .appleTV: "com.cbs.ott"]),
        .init(id: "peacock", name: "Peacock", symbol: "bird.fill", dialName: "Peacock",
              ids: [.roku: "593099", .lgWebOS: "com.peacocktv.peacock", .samsungTizen: "3202008021439", .googleTV: "com.peacocktv.peacockandroid", .appleTV: "com.peacocktv.peacock"]),
        .init(id: "plex", name: "Plex", symbol: "play.square.stack.fill", dialName: "Plex",
              ids: [.roku: "13535", .lgWebOS: "cdp-30", .samsungTizen: "3201512006963", .googleTV: "com.plexapp.android", .appleTV: "com.plexapp.plex"]),
        .init(id: "twitch", name: "Twitch", symbol: "bubble.left.and.bubble.right.fill",
              ids: [.roku: "8838", .lgWebOS: "tv.twitch", .googleTV: "tv.twitch.android.app", .appleTV: "tv.twitch"]),
        .init(id: "tubi", name: "Tubi", symbol: "display",
              ids: [.roku: "41468", .lgWebOS: "com.tubitv.ott", .samsungTizen: "3201806016390", .googleTV: "com.tubitv", .appleTV: "com.tubitv.ios"]),
        .init(id: "plutotv", name: "Pluto TV", symbol: "globe.americas.fill",
              ids: [.roku: "74519", .lgWebOS: "tv.pluto.android", .samsungTizen: "3201710015037", .googleTV: "tv.pluto.android", .appleTV: "tv.pluto.ios"]),
        .init(id: "espn", name: "ESPN", symbol: "sportscourt.fill",
              ids: [.roku: "34376", .lgWebOS: "com.espn.ott", .googleTV: "com.espn.score_center", .appleTV: "com.espn.SportCenter"]),
        .init(id: "crunchyroll", name: "Crunchyroll", symbol: "flame.fill",
              ids: [.roku: "24789", .lgWebOS: "com.crunchyroll.crv", .googleTV: "com.crunchyroll.crunchyroid", .appleTV: "com.crunchyroll.iphone"]),
    ]

    static func app(for id: String) -> RemoteApp {
        catalog.first { $0.id == id } ?? catalog[0]
    }

    static func available(for brand: DeviceBrand) -> [RemoteApp] {
        catalog.filter { $0.ids[brand] != nil }
    }
}

// MARK: - Color helpers

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        self.init(.sRGB,
                  red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255)
    }
}

// MARK: - Expanded Accent Presets (18 Vibrant Colors)

enum AccentPreset: String, CaseIterable, Identifiable {
    case crimson, ruby, sunset, amber, gold, lime, mint, teal, cyan, sky, indigo, purple, magenta, pink, rose, silver, graphite, obsidian
    var id: String { rawValue }

    var name: String {
        switch self {
        case .crimson: "Roku Crimson"
        case .ruby: "Vivid Ruby"
        case .sunset: "Sunset Orange"
        case .amber: "Amber Glow"
        case .gold: "Electric Gold"
        case .lime: "Neon Lime"
        case .mint: "Emerald Mint"
        case .teal: "Electric Teal"
        case .cyan: "Cyber Cyan"
        case .sky: "Sky Blue"
        case .indigo: "Royal Indigo"
        case .purple: "Ultraviolet"
        case .magenta: "Hot Magenta"
        case .pink: "Coral Pink"
        case .rose: "Rose Gold"
        case .silver: "Platinum Silver"
        case .graphite: "Stealth Graphite"
        case .obsidian: "Dark Obsidian"
        }
    }

    var hex: String {
        switch self {
        case .crimson: "#E5213B"
        case .ruby: "#FF2A55"
        case .sunset: "#FF5722"
        case .amber: "#FFB020"
        case .gold: "#FFD60A"
        case .lime: "#A6FF00"
        case .mint: "#3DF5A0"
        case .teal: "#00E5FF"
        case .cyan: "#19E3F5"
        case .sky: "#0A84FF"
        case .indigo: "#5E5CE6"
        case .purple: "#AF52DE"
        case .magenta: "#FF3DA5"
        case .pink: "#FF6B8B"
        case .rose: "#E0A899"
        case .silver: "#B8BCC4"
        case .graphite: "#636366"
        case .obsidian: "#3A3A3C"
        }
    }
}
