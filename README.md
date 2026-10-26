<p align="center">
  <img src="Resources/AppIcon.png" width="128" height="128" alt="LiquidRemote Icon" />
</p>

<h1 align="center">LiquidRemote</h1>

<p align="center">
  <b>A native, ultra-modern macOS menu bar universal remote for Smart TVs and streaming devices.</b><br>
  Crafted with SwiftUI & AppKit • Liquid Glass Translucency • Universal Wake-on-LAN • Zero Third-Party Dependencies
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014.0%2B-blue?style=flat-square&logo=apple" alt="macOS 14.0+" />
  <img src="https://img.shields.io/badge/Swift-5.10-F05138?style=flat-square&logo=swift" alt="Swift 5" />
  <img src="https://img.shields.io/badge/Codesign-Developer%20ID-success?style=flat-square&logo=apple" alt="Developer ID Signed" />
  <img src="https://img.shields.io/badge/Dependencies-Zero-brightgreen?style=flat-square" alt="Zero Dependencies" />
  <img src="https://img.shields.io/badge/License-MIT-black?style=flat-square" alt="MIT License" />
</p>

---

## ✨ Overview

**LiquidRemote** brings tactile, responsive, and beautiful TV control directly to your macOS menu bar. Designed from the ground up for macOS Sonoma and Sequoia, it pairs a native **Liquid Glass** aesthetic with multi-protocol TV communication, intelligent network discovery, and universal Wake-on-LAN.

Whether you're adjusting volume with your trackpad, launching your favorite streaming app, waking a sleeping TV over Wi-Fi, or switching between multiple displays across rooms, LiquidRemote offers a seamless desktop experience without ever reaching for a physical remote.

---

## 🚀 Key Features

### 🪟 Dynamic Liquid Glass UI
- **Real-Time Translucency Engine**: Adjust glass frostedness from **15% (frosted dark)** to **100% (crystal clear liquid glass)** to match your desktop wallpaper and macOS appearance.
- **18 Vibrant Accent Palettes**:
  - *Warm & Crimson*: Roku Crimson, Vivid Ruby, Sunset Orange, Amber Glow, Electric Gold
  - *Neon & Electric*: Neon Lime, Emerald Mint, Electric Teal, Cyber Cyan
  - *Cool & Vivid*: Sky Blue, Royal Indigo, Ultraviolet, Hot Magenta, Coral Pink, Rose Gold
  - *Modern Neutrals*: Platinum Silver, Stealth Graphite, Dark Obsidian
- **Interactive Micro-Interactions**: Fluid glass hover states, spring-physics scaling, and macOS system haptic feedback on every press.

### ⚡ Universal Wake-on-LAN (WoL) Engine
- Transmits raw **102-byte UDP magic packets** simultaneously to broadcast ports 9 and 7.
- **Auto-ARP Probing**: Automatically discovers and resolves hardware MAC addresses for discovered network IPs via local subnet ARP tables.
- **Dedicated Wake Actions**: Wake TVs via one-click menu items, automatic wake on Power key, or the Settings manager.

### 📺 30 Authentic Brand Logos & Menu Bar Icons
- Authentic, pixel-perfect logos and customized 22×22 Retina menu bar icons for:
  - **Top 20 TV Brands**: Samsung, LG, Sony, TCL, Hisense, Sharp, Vizio, Roku TV, Philips, Panasonic, Toshiba, Insignia, JVC, Pioneer, Sceptre, Xiaomi, OnePlus, Skyworth, Haier, Hitachi.
  - **Top 10 Android & Streaming Devices**: Apple TV, Google TV, Amazon Fire TV, NVIDIA Shield, Xiaomi Mi Box, onn. Google TV, TiVo Stream 4K, MECOOL, Formuler, Nokia Streaming Box.
- **Smart Brand Detection**: Automatically detects local TV vendors (e.g., Sharp Roku TVs, LG webOS OLEDs) and applies matching brand logos automatically.

### 🔊 Bespoke Liquid Glass Volume Capsule
- **No Confusing Fake Numbers**: TV protocols (like Roku ECP) step volume relatively rather than reporting live absolute indices. LiquidRemote removes ugly, inaccurate numbers in favor of an elegant, tactile level bar.
- **Fluid Gradient Track**: Smooth glowing accent gradient with a translucent glass thumb handle.
- **Touch-Friendly Controls**: Stepping `-` / `+` buttons and smooth dragging support.
- **Two-Finger Scroll Gestures**: Scroll vertically with two fingers anywhere on the remote panel to adjust TV volume smoothly with haptic clicks.

### 📱 Configurable Quick-Launch App Grid
- **Customizable Layout**: Choose **2, 4, 6, or 8** quick-launch app buttons directly from the remote's `⋯` menu or Settings.
- **16 Supported Streaming Services**:
  - Netflix • YouTube • Disney+ • Prime Video • Hulu • Max • Apple TV • Spotify
  - Paramount+ • Peacock • Plex • Twitch • Tubi • Pluto TV • ESPN • Crunchyroll
- Instant deep-linking and launching via native platform app IDs.

### 🎮 Comprehensive Remote Controls
- **Precision D-Pad**: Fluid 5-way directional control with optional double-tap-to-select safety guard.
- **Home, Star & Sleep Action Row**:
  - `[ ★ ]` **Star Button**: Sends Roku Options / Info (`keypress/Info` on Roku, `INFO` on webOS, `KEYCODE_INFO` on Android TV).
  - `[ ⌂ Home ]` **Home Button**: Prominently centered.
  - `[ ☾ Sleep ]` **Sleep Mode Button**: Puts TV into low-power standby (`keypress/PowerOff`).
- **Media Controls**: Back, Rewind, Play/Pause, Fast-Forward, and Mute.
- **Dynamic Auto-Resizing Window**: Window frame dynamically expands and contracts to fit active app counts and unwrapped, dismissible alert banners without ever cutting off edges.

### ⌨️ Global Keyboard Hotkeys
Control your TV from anywhere in macOS, even while working in other apps:
- `⌃⌥⌘ ↑` — Volume Up
- `⌃⌥⌘ ↓` — Volume Down
- `⌃⌥⌘ M` — Mute Toggle
- `⌃⌥⌘ Space` — Play / Pause

---

## 📡 Protocol Support & Architecture

| Platform / Protocol | Port | Capabilities | State |
|---|:---:|---|:---:|
| **Roku TV & Players (ECP)** | `8060` | Keypress, App Launch, Now Playing Artwork, Power/Sleep | ✅ Production Ready |
| **LG webOS (SSAP / WebSocket)** | `3001` | Pairing handshake, Buttons, Absolute Volume, Launch | ✅ Production Ready |
| **UPnP / DLNA MediaRenderer** | `80` / `var` | SOAP RenderingControl, Volume, Mute | ✅ Production Ready |
| **Google TV / Android TV (v2)** | `6466` | TLS + Protobuf remote message injection | 🚧 Protocol Scaffold |
| **Apple TV (Companion Protocol)** | `49153` | SRP + ChaCha20-Poly1305 companion pairing | 🚧 Protocol Scaffold |

> [!TIP]
> **Roku Setup Note**: To allow local network commands, ensure your Roku TV has mobile control enabled:
> `Settings` → `System` → `Advanced system settings` → `Control by mobile apps` → `Network access` → set to **Permissive** (or Default).

---

## 🛠️ Building from Source

### Prerequisites
- macOS 14.0 (Sonoma) or macOS 15.0+ (Sequoia)
- Xcode 15+ or Command Line Tools (`xcode-select --install`)
- Swift 5.10+ toolchain

### Quick Build & Run

Clone the repository and run the automated build script:

```bash
git clone https://github.com/doodaddude/LiquidRemote.git
cd LiquidRemote

# Build, package, and sign with Developer ID (or ad-hoc fallback)
./build.sh

# Launch the app
open build/LiquidRemote.app
```

The `build.sh` script automatically:
1. Compiles Swift sources with optimizations (`-O -parse-as-library`).
2. Constructs the macOS `.app` bundle structure with `Info.plist` and all 60+ brand icon assets.
3. Signs the bundle with your **Apple Developer ID** certificate and Hardened Runtime enabled.

---

## 🗂️ Project Structure

```
LiquidRemote/
├── App/
│   ├── LiquidRemoteApp.swift      # Application entry point & AppDelegate
│   └── RemoteHub.swift            # Command routing & device state manager
├── Discovery/
│   └── DeviceDiscovery.swift      # BSD socket SSDP & subnet ARP discovery
├── Input/
│   └── HotKeyManager.swift        # Carbon global keyboard shortcuts
├── MenuBar/
│   └── MenuBarManager.swift       # NSStatusItem & dynamic auto-resizing NSPanel
├── Models/
│   ├── RemoteModels.swift         # Core data models, app catalog & brand gallery
│   └── DeviceStore.swift          # UserDefaults persistence & WoL MAC resolver
├── Protocols/
│   ├── RemoteController.swift     # Unified controller protocol & factory
│   ├── RokuController.swift       # Roku ECP HTTP protocol client
│   ├── LGWebOSController.swift    # LG webOS SSAP WebSocket client
│   ├── AndroidTVController.swift  # Android TV v2 scaffold
│   ├── AppleTVController.swift    # Apple TV Companion scaffold
│   ├── UPnPController.swift       # UPnP/DLNA SOAP RenderingControl client
│   └── WakeOnLAN.swift            # Universal Wake-on-LAN magic packet engine
├── Resources/                     # 30 brand logos, menu bar icons & AppIcon.icns
├── Views/
│   ├── LiquidRemoteView.swift     # Main liquid glass remote interface
│   ├── SettingsView.swift         # Device management, brand picker & preset apps
│   ├── BrandLogoView.swift        # High-fidelity brand vector/PNG renderer
│   ├── DPadView.swift             # 5-way directional control pad
│   └── GlassStyle.swift           # Liquid glass shaders, press styles & materials
├── Info.plist                     # Bundle metadata & network entitlement declarations
├── build.sh                       # One-click compilation & code-signing script
├── LICENSE                        # MIT License
└── README.md
```

---

## 🔒 Security & Code Signing

LiquidRemote is signed with a valid Apple Developer ID:
- **Developer ID Application**: `Dakota Hilchey (2FCUC227QF)`
- **Hardened Runtime**: Enabled (`flags=0x10000(runtime)`)
- **Sandboxing / Permissions**: Uses standard local network sockets for direct LAN communication with TVs.

Verify bundle integrity at any time via:
```bash
codesign -dvvv /Applications/LiquidRemote.app
```

---

## 📄 License

LiquidRemote is licensed under the **[MIT License](LICENSE)**.

Copyright (c) 2026 Dakota Hilchey ([@doodaddude](https://github.com/doodaddude)).
