import SwiftUI

struct DPadView: View {
    var accent: Color
    var requireDoubleTapSelect: Bool
    var onKey: (RemoteKey) -> Void

    var body: some View {
        ZStack {
            Circle().fill(.thinMaterial)
                .overlay(Circle().strokeBorder(LinearGradient(colors: [.white.opacity(0.6), .white.opacity(0.05)],
                                                              startPoint: .top, endPoint: .bottom),
                                               lineWidth: 0.5))
            arrow("chevron.up", .up).offset(y: -74)
            arrow("chevron.down", .down).offset(y: 74)
            arrow("chevron.left", .left).offset(x: -74)
            arrow("chevron.right", .right).offset(x: 74)
            center
        }
        .frame(width: 220, height: 220)
    }

    private func arrow(_ symbol: String, _ key: RemoteKey) -> some View {
        Button { onKey(key) } label: {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
                .frame(width: 52, height: 52)
        }
        .buttonStyle(HoverGlowStyle(accent: accent))
    }

    @ViewBuilder private var center: some View {
        let disc = Circle()
            .fill(accent.opacity(0.35))
            .overlay(Text("OK").font(.system(size: 14, weight: .heavy)))
            .frame(width: 76, height: 76)
        if requireDoubleTapSelect {
            disc.contentShape(Circle()).onTapGesture(count: 2) { onKey(.select) }
        } else {
            Button { onKey(.select) } label: { disc }.buttonStyle(HoverGlowStyle(accent: accent))
        }
    }
}

/// Press = scale 0.95 + border pulse; hover = soft glow.
struct HoverGlowStyle: ButtonStyle {
    var accent: Color
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Circle().fill(accent.opacity(configuration.isPressed ? 0.45 : hovering ? 0.22 : 0)))
            .overlay(Circle().strokeBorder(accent.opacity(configuration.isPressed ? 0.95 : 0), lineWidth: 1.5))
            .shadow(color: accent.opacity(configuration.isPressed ? 0.7 : hovering ? 0.35 : 0), radius: 10)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .contentShape(Circle())
            .onHover { hovering = $0 }
            .animation(.interpolatingSpring(stiffness: 300, damping: 25), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.15), value: hovering)
    }
}
