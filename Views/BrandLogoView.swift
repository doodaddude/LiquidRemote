import SwiftUI
import AppKit

/// Renders authentic, high-fidelity brand logos for all TV brands.
struct BrandLogoView: View {
    let brand: DeviceBrand
    var customSymbol: String? = nil
    var size: CGFloat = 32

    var body: some View {
        if let custom = customSymbol, !custom.isEmpty, !custom.hasPrefix("logo_") {
            // User selected an icon from the setup gallery
            Image(systemName: custom)
                .font(.system(size: size * 0.65, weight: .semibold))
                .frame(width: size, height: size)
        } else {
            logoContent
                .frame(width: size, height: size)
        }
    }

    @ViewBuilder
    private var logoContent: some View {
        if let image = loadBrandImage() {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
        } else {
            // High-fidelity native vector fallback
            vectorFallback
        }
    }

    private func loadBrandImage() -> NSImage? {
        let name: String
        if let custom = customSymbol, custom.hasPrefix("logo_") {
            name = custom
        } else {
            name = switch brand {
            case .roku: "logo_roku"
            case .appleTV: "logo_appletv"
            case .googleTV: "logo_googletv"
            case .lgWebOS: "logo_lg"
            case .generic: "logo_samsung"
            case .universal: "logo_roku"
            }
        }

        // 1. Try Bundle resources
        if let url = Bundle.main.url(forResource: name, withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            return img
        }

        // 2. Try file paths in bundle or installed app
        let candidatePaths = [
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/\(name).png").path,
            "/Applications/LiquidRemote.app/Contents/Resources/\(name).png",
            "/Users/mac/.gemini/antigravity/scratch/roku2/LiquidRemote/Resources/\(name).png"
        ]

        for path in candidatePaths {
            if FileManager.default.fileExists(atPath: path), let img = NSImage(contentsOfFile: path) {
                return img
            }
        }

        return nil
    }

    @ViewBuilder
    private var vectorFallback: some View {
        switch brand {
        case .roku:
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .fill(Color(hex: "#662D91"))
                Text("Roku")
                    .font(.system(size: size * 0.38, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
        case .appleTV:
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .fill(Color(hex: "#18181B"))
                HStack(spacing: 1) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: size * 0.40))
                    Text("tv")
                        .font(.system(size: size * 0.36, weight: .bold))
                }
                .foregroundStyle(.white)
            }
        case .googleTV:
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .fill(Color(hex: "#202124"))
                HStack(spacing: 2) {
                    Text("G")
                        .font(.system(size: size * 0.42, weight: .bold))
                        .foregroundStyle(Color(hex: "#4285F4"))
                    Text("tv")
                        .font(.system(size: size * 0.30, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        case .lgWebOS:
            ZStack {
                Circle()
                    .fill(Color(hex: "#A50034"))
                Text("LG")
                    .font(.system(size: size * 0.40, weight: .heavy))
                    .foregroundStyle(.white)
            }
        case .generic:
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .fill(Color(hex: "#1428A0"))
                Text("TV")
                    .font(.system(size: size * 0.40, weight: .black))
                    .foregroundStyle(.white)
            }
        case .universal:
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: size * 0.65))
        }
    }

    // MARK: - Menu Bar Image Provider

    static func menuBarImage(for d: RemoteDevice) -> NSImage? {
        let name: String
        if let icon = d.iconSymbol, icon.hasPrefix("logo_") {
            let key = icon.replacingOccurrences(of: "logo_", with: "")
            name = "menubar_\(key)"
        } else {
            name = switch d.brand {
            case .roku: "menubar_roku"
            case .appleTV: "menubar_appletv"
            case .googleTV: "menubar_googletv"
            case .lgWebOS: "menubar_lg"
            case .generic: "menubar_samsung"
            case .universal: "menubar_roku"
            }
        }

        let candidatePaths = [
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/\(name).png").path,
            "/Applications/LiquidRemote.app/Contents/Resources/\(name).png",
            "/Users/mac/.gemini/antigravity/scratch/roku2/LiquidRemote/Resources/\(name).png"
        ]

        for p in candidatePaths {
            if FileManager.default.fileExists(atPath: p), let img = NSImage(contentsOfFile: p) {
                img.size = NSSize(width: 22, height: 22)
                img.isTemplate = false
                return img
            }
        }

        if let url = Bundle.main.url(forResource: name, withExtension: "png"), let img = NSImage(contentsOf: url) {
            img.size = NSSize(width: 22, height: 22)
            img.isTemplate = false
            return img
        }

        // Dynamic drawn menu bar image with real brand styling
        let img = NSImage(size: NSSize(width: 22, height: 22), flipped: false) { rect in
            let path = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: 5, yRadius: 5)
            switch d.brand {
            case .roku:
                NSColor(srgbRed: 102/255, green: 45/255, blue: 145/255, alpha: 1).setFill()
                path.fill()
                let str = NSAttributedString(string: "R", attributes: [
                    .foregroundColor: NSColor.white,
                    .font: NSFont.boldSystemFont(ofSize: 13)
                ])
                str.draw(at: NSPoint(x: 6, y: 3))
            case .appleTV:
                NSColor.darkGray.setFill()
                path.fill()
                let str = NSAttributedString(string: "", attributes: [
                    .foregroundColor: NSColor.white,
                    .font: NSFont.systemFont(ofSize: 13)
                ])
                str.draw(at: NSPoint(x: 6, y: 3))
            case .lgWebOS:
                NSColor(srgbRed: 165/255, green: 0, blue: 52/255, alpha: 1).setFill()
                path.fill()
                let str = NSAttributedString(string: "LG", attributes: [
                    .foregroundColor: NSColor.white,
                    .font: NSFont.boldSystemFont(ofSize: 9)
                ])
                str.draw(at: NSPoint(x: 4, y: 5))
            default:
                NSColor.systemBlue.setFill()
                path.fill()
                let str = NSAttributedString(string: "TV", attributes: [
                    .foregroundColor: NSColor.white,
                    .font: NSFont.boldSystemFont(ofSize: 9)
                ])
                str.draw(at: NSPoint(x: 4, y: 5))
            }
            return true
        }
        img.isTemplate = false
        return img
    }
}
