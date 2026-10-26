# Changelog

All notable changes to **LiquidRemote** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.2.0] - 2026-10-25

### Added
- **Samsung Tizen OS Protocol (`SamsungTizenController`)**:
  - Full WebSocket control over `wss://:8002` and `ws://:8001` (`samsung.remote.control`).
  - Automatic self-signed TLS certificate trust for local LAN Samsung TVs.
  - On-screen pairing authorization prompt with persistent token storage.
  - Full remote key injection (`KEY_UP`, `KEY_DOWN`, `KEY_ENTER`, `KEY_RETURN`, `KEY_HOME`, `KEY_VOLUP`, `KEY_VOLDOWN`, `KEY_MUTE`, `KEY_POWER`, `KEY_INFO`, `KEY_SLEEP`, media keys).
  - Direct application launching via Tizen REST API (`:8001/api/v2/applications/`).
- **Sony BRAVIA Protocol (`SonyBraviaController`)**:
  - Full IRCC-IP (Infra-Red Compatible Control over IP) SOAP client on `/sony/ircc`.
  - Pre-Shared Key (`X-Auth-PSK`) authentication support.
  - Direct speaker volume fraction control via Sony Audio REST service (`/sony/audio`).
  - Direct application launching via Sony AppControl service (`/sony/appControl`).
- **Vizio SmartCast Protocol (`VizioSmartCastController`)**:
  - HTTPS REST client on port `7345` with local TLS certificate acceptance.
  - Full codeset key command mapping for D-pad, navigation, volume, power, sleep, and media playback.
- **Philips JointSpace Protocol (`PhilipsJointSpaceController`)**:
  - HTTP REST client for JointSpace v6 & v1 (`/6/input/key` and `/1/input/key`) on port `1925`.
  - Full navigation, standby, options, and direct audio volume control (`/6/audio/volume`) for Philips Smart TVs and Ambilight models.
- **Amazon Fire TV & Google TV DIAL App Launching (`FireTVController` & `AndroidTVController`)**:
  - Direct DIAL REST server (`:8008/apps/<App>`) integration to launch Netflix, YouTube, Prime Video, Disney+, Hulu, Spotify, Max, Peacock, Paramount+, and Plex on Android TV, Google TV, and Fire TV devices.
- **Expanded Multi-Protocol Network Discovery (`DeviceDiscovery`)**:
  - Added SSDP search targets for Samsung (`RemoteControlReceiver`), Sony (`IRCC`), DIAL (`dial-multiscreen-org`), LG (`webos-second-screen`), Roku (`roku:ecp`), and UPnP (`MediaRenderer`).
  - Added concurrent subnet ARP probing for Roku (`:8060`), Samsung (`:8001`), Sony (`:80`), and LG (`:3001`) with automatic vendor recognition and brand logo assignment.
- **Expanded App Catalog IDs**:
  - Added platform-specific application launch IDs for Samsung Tizen, Sony BRAVIA, Amazon Fire TV, and DIAL across 16 streaming services.

### Changed
- **Settings & Brand Picker**:
  - Expanded manual IP device setup and brand logo pickers to support all 10 protocol categories natively (`Roku`, `Samsung Tizen`, `LG webOS`, `Sony BRAVIA`, `Google TV / Android TV`, `Vizio SmartCast`, `Philips JointSpace`, `Amazon Fire TV`, `Apple TV`, `Smart TV UPnP`).
- **App Bundle & Code Signing**:
  - Recompiled universal binary and signed with Apple Developer ID (`Developer ID Application: Dakota Hilchey (2FCUC227QF)`) with Hardened Runtime.

---

## [1.1.0] - 2026-10-25

### Added
- **30 Authentic Brand Logos & Menu Bar Icons**:
  - Top 20 TV Brands: Samsung, LG, Sony, TCL, Hisense, Sharp, Vizio, Roku TV, Philips, Panasonic, Toshiba, Insignia, JVC, Pioneer, Sceptre, Xiaomi, OnePlus, Skyworth, Haier, Hitachi.
  - Top 10 Streaming Devices: Apple TV, Google TV, Amazon Fire TV, NVIDIA Shield, Xiaomi Mi Box, onn. Google TV, TiVo Stream 4K, MECOOL, Formuler, Nokia Streaming Box.
- **Liquid Glass Translucency Engine**:
  - Real-time translucency slider from 15% to 100% clarity.
  - 18 custom accent color presets.
- **Configurable Quick-Launch App Grid**:
  - Support for 2, 4, 6, or 8 customizable streaming app slots.
- **Dedicated Star & Sleep Mode Controls**:
  - Added `[ ★ ]` Info/Options and `[ ☾ Sleep ]` buttons flanking the centered Home button.
- **Edge-to-Edge macOS Squircle App Icon**:
  - Full-bleed 1024×1024 iconset without dark outer padding.

### Fixed
- **Volume Slider Redesign**:
  - Replaced inaccurate numerical readout with a fluid, glowing liquid glass level bar and `-` / `+` step buttons.
- **Error Banner Auto-Sizing**:
  - Dynamic window height calculation so multi-line diagnostic messages never clip at the bottom of the popover.

---

## [1.0.0] - 2026-10-12

### Added
- Initial release of **LiquidRemote** for macOS.
- Roku ECP, LG webOS SSAP, and UPnP RenderingControl support.
- Universal Wake-on-LAN (WoL) magic packet engine with ARP cache MAC resolution.
- Global keyboard shortcuts and two-finger trackpad scroll volume control.
