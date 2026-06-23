import SwiftUI

// MARK: - Color helper

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue:  Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

// MARK: - Palette
//
// A warm, tactile palette: brushed graphite in dark mode, aged linen in light
// mode, with brass accents. Tuned so highlights and shadows read as real depth.

struct SkeuoPalette {
    let isDark: Bool
    init(_ scheme: ColorScheme) { isDark = scheme == .dark }

    // Window background
    var bgTop: Color    { isDark ? Color(hex: 0x3C3F47) : Color(hex: 0xF7F3EB) }
    var bgBottom: Color { isDark ? Color(hex: 0x222429) : Color(hex: 0xDDD6C8) }

    // Raised surfaces (cards, buttons) — convex, lit from above
    var raisedTop: Color    { isDark ? Color(hex: 0x50545E) : Color(hex: 0xFFFFFF) }
    var raisedBottom: Color { isDark ? Color(hex: 0x383C44) : Color(hex: 0xEBE5D9) }

    // Recessed surfaces (search well, icon tiles) — engraved, dark at the top
    var wellTop: Color    { isDark ? Color(hex: 0x1A1C20) : Color(hex: 0xD3CCBE) }
    var wellBottom: Color { isDark ? Color(hex: 0x2B2E34) : Color(hex: 0xEDE8DE) }

    // Edges & light
    var stroke: Color       { isDark ? Color(hex: 0x121317, opacity: 0.85) : Color(hex: 0xB4AB98, opacity: 0.7) }
    var topHighlight: Color { Color.white.opacity(isDark ? 0.12 : 0.9) }
    var innerShadow: Color  { Color.black.opacity(isDark ? 0.55 : 0.24) }
    var dropShadow: Color   { Color.black.opacity(isDark ? 0.5 : 0.18) }

    // Accent (brass)
    var accent: Color       { isDark ? Color(hex: 0xE7B45A) : Color(hex: 0xB07B24) }
    var accentTop: Color    { isDark ? Color(hex: 0xF2C46E) : Color(hex: 0xD7A24A) }
    var accentBottom: Color { isDark ? Color(hex: 0xC9912F) : Color(hex: 0xA1701B) }

    // Text
    var textPrimary: Color   { isDark ? Color(hex: 0xECEAE5) : Color(hex: 0x2B2823) }
    var textSecondary: Color { isDark ? Color(hex: 0xA7ABB3) : Color(hex: 0x6B665C) }
    var textTertiary: Color  { isDark ? Color(hex: 0x70747C) : Color(hex: 0x9A9485) }
}

// MARK: - Window background

struct SkeuoWindow: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        let p = SkeuoPalette(scheme)
        content.background(
            ZStack {
                LinearGradient(colors: [p.bgTop, p.bgBottom], startPoint: .top, endPoint: .bottom)
                RadialGradient(
                    colors: [Color.white.opacity(scheme == .dark ? 0.05 : 0.55), .clear],
                    center: .top, startRadius: 0, endRadius: 300
                )
            }
            .ignoresSafeArea()
        )
    }
}

// MARK: - Raised card

struct SkeuoCard: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var cornerRadius: CGFloat = 10
    var hovered: Bool = false
    var elevated: Bool = true

    func body(content: Content) -> some View {
        let p = SkeuoPalette(scheme)
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content.background(
            shape
                .fill(
                    LinearGradient(colors: [p.raisedTop, p.raisedBottom], startPoint: .top, endPoint: .bottom)
                        .shadow(.inner(color: p.topHighlight, radius: 0.5, y: 0.75))
                )
                .overlay(
                    shape.strokeBorder(
                        hovered ? p.accent.opacity(0.55) : p.stroke,
                        lineWidth: hovered ? 1 : 0.75
                    )
                )
                .shadow(
                    color: p.dropShadow,
                    radius: elevated ? (hovered ? 7 : 4) : 0,
                    x: 0, y: elevated ? (hovered ? 3.5 : 2) : 0
                )
        )
    }
}

// MARK: - Recessed well (engraved)

struct SkeuoWell: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var cornerRadius: CGFloat = 8

    func body(content: Content) -> some View {
        let p = SkeuoPalette(scheme)
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content.background(
            shape
                .fill(
                    LinearGradient(colors: [p.wellTop, p.wellBottom], startPoint: .top, endPoint: .bottom)
                        .shadow(.inner(color: p.innerShadow, radius: 3, y: 1.5))
                )
                .overlay(
                    // bottom "lip" catches the light
                    shape.strokeBorder(p.topHighlight.opacity(0.6), lineWidth: 0.75)
                        .mask(LinearGradient(colors: [.clear, .black], startPoint: .center, endPoint: .bottom))
                )
                .overlay(shape.strokeBorder(p.stroke.opacity(0.6), lineWidth: 0.5))
        )
    }
}

// MARK: - Button styles

struct SkeuoIconButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var scheme
    var size: CGFloat = 26

    func makeBody(configuration: Configuration) -> some View {
        let p = SkeuoPalette(scheme)
        let pressed = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
        configuration.label
            .frame(width: size, height: size - 2)
            .background(
                shape
                    .fill(
                        LinearGradient(
                            colors: pressed ? [p.raisedBottom, p.raisedTop] : [p.raisedTop, p.raisedBottom],
                            startPoint: .top, endPoint: .bottom
                        )
                        .shadow(.inner(
                            color: pressed ? p.innerShadow : p.topHighlight,
                            radius: pressed ? 2 : 0.5,
                            y: pressed ? 1.5 : 0.75
                        ))
                    )
                    .overlay(shape.strokeBorder(p.stroke, lineWidth: 0.75))
                    .shadow(color: p.dropShadow, radius: pressed ? 0 : 2, y: pressed ? 0 : 1)
            )
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.08), value: pressed)
    }
}

struct SkeuoProminentButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var scheme

    func makeBody(configuration: Configuration) -> some View {
        let p = SkeuoPalette(scheme)
        let pressed = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(p.isDark ? Color(hex: 0x3A2A06) : .white)
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(
                shape
                    .fill(
                        LinearGradient(
                            colors: pressed ? [p.accentBottom, p.accentTop] : [p.accentTop, p.accentBottom],
                            startPoint: .top, endPoint: .bottom
                        )
                        .shadow(.inner(color: .white.opacity(pressed ? 0 : 0.45), radius: 0.5, y: 0.75))
                    )
                    .overlay(shape.strokeBorder(p.accentBottom.opacity(0.8), lineWidth: 0.75))
                    .shadow(color: p.accent.opacity(pressed ? 0.1 : 0.35), radius: pressed ? 1 : 4, y: pressed ? 0 : 2)
            )
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.08), value: pressed)
    }
}

// MARK: - Convenience

extension View {
    func skeuoWindow() -> some View { modifier(SkeuoWindow()) }
    func skeuoCard(cornerRadius: CGFloat = 10, hovered: Bool = false, elevated: Bool = true) -> some View {
        modifier(SkeuoCard(cornerRadius: cornerRadius, hovered: hovered, elevated: elevated))
    }
    func skeuoWell(cornerRadius: CGFloat = 8) -> some View { modifier(SkeuoWell(cornerRadius: cornerRadius)) }

    // Subtle engraved text shadow for headings on raised surfaces
    func skeuoEngraved(_ scheme: ColorScheme) -> some View {
        shadow(color: scheme == .dark ? .black.opacity(0.6) : .white.opacity(0.7),
               radius: 0, x: 0, y: scheme == .dark ? -0.75 : 0.75)
    }
}
