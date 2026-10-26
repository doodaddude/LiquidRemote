import SwiftUI
import AppKit

// MARK: - Liquid Glass surface with adjustable Translucency

struct LiquidGlass: ViewModifier {
    var accent: Color
    var radius: CGFloat = 32
    var translucency: Double = 0.75

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Frost glass material with dynamic opacity controlled by slider
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(0.3 + (1.0 - translucency) * 0.7)

                    // Deep tone backing layer that adapts to translucency
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(Color.black.opacity(max(0.08, (1.0 - translucency) * 0.85)))

                    // Ambient accent bloom through the liquid glass
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(RadialGradient(colors: [accent.opacity(0.12 + translucency * 0.28), .clear],
                                             center: .top, startRadius: 0, endRadius: 360))
                }
            )
            .overlay(      // Specular edge highlights that brighten with higher translucency
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.25 + translucency * 0.5),
                                                         .white.opacity(0.04),
                                                         .white.opacity(0.15 + translucency * 0.3)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing),
                                  lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.2 + (1.0 - translucency) * 0.25), radius: 20, y: 10)
    }
}

extension View {
    func liquidGlass(accent: Color, radius: CGFloat = 32, translucency: Double = 0.75) -> some View {
        modifier(LiquidGlass(accent: accent, radius: radius, translucency: translucency))
    }
}

// MARK: - Button style: scale 0.95 + glowing border pulse

struct GlassPressStyle: ButtonStyle {
    var accent: Color
    var radius: CGFloat = 999

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(configuration.isPressed ? accent.opacity(0.95) : Color.white.opacity(0.28),
                                  lineWidth: configuration.isPressed ? 1.5 : 0.5)
            )
            .shadow(color: accent.opacity(configuration.isPressed ? 0.7 : 0), radius: 12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.interpolatingSpring(stiffness: 300, damping: 25), value: configuration.isPressed)
    }
}

enum Haptics {
    static func tap() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }
}

// MARK: - Trackpad scroll → swipe gestures

/// Two-finger swipes on the open panel: up/down = volume, left/right = scrub.
final class ScrollGestureMonitor: ObservableObject {
    var onVertical: ((Int) -> Void)?     // +1 up, -1 down
    var onHorizontal: ((Int) -> Void)?   // +1 forward, -1 back
    private var monitor: Any?
    private var accX: CGFloat = 0
    private var accY: CGFloat = 0
    private let step: CGFloat = 36

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] e in
            guard let self, e.window is RemotePanel else { return e }
            if e.phase == .began { self.accX = 0; self.accY = 0 }
            self.accX += e.scrollingDeltaX
            self.accY += e.scrollingDeltaY
            if abs(self.accY) > abs(self.accX), abs(self.accY) >= self.step {
                self.onVertical?(self.accY > 0 ? 1 : -1)
                self.accY = 0
            } else if abs(self.accX) > abs(self.accY), abs(self.accX) >= self.step {
                self.onHorizontal?(self.accX > 0 ? -1 : 1)
                self.accX = 0
            }
            return e
        }
    }

    func stop() {
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
    }
}
