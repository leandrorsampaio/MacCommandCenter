import SwiftUI

/// The 1997 bevel: a light edge on top and left, a dark edge on bottom and right.
/// Inverting the two is what "pressed in" means.
public enum BevelStyle: Sendable {
    case raised
    case sunken
    case flat
}

public struct BevelModifier: ViewModifier {

    let style: BevelStyle
    @Environment(\.skin) private var skin

    public func body(content: Content) -> some View {
        let width = skin.metrics.bevel
        let radius = skin.metrics.cornerRadius

        if style == .flat || width <= 0 {
            content
        } else if radius > 0 {
            // Rounded skins get a single lit-to-shadowed stroke; square corners are what
            // the four-edge treatment below is for.
            content.overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [light, dark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: width
                    )
            )
        } else {
            content
                .overlay(alignment: .top) { Rectangle().fill(light).frame(height: width) }
                .overlay(alignment: .leading) { Rectangle().fill(light).frame(width: width) }
                .overlay(alignment: .bottom) { Rectangle().fill(dark).frame(height: width) }
                .overlay(alignment: .trailing) { Rectangle().fill(dark).frame(width: width) }
        }
    }

    private var light: Color {
        (style == .sunken ? skin.colors.panelShadow : skin.colors.panelHighlight).color
    }

    private var dark: Color {
        (style == .sunken ? skin.colors.panelHighlight : skin.colors.panelShadow).color
    }
}

public extension View {
    func bevel(_ style: BevelStyle) -> some View {
        modifier(BevelModifier(style: style))
    }
}

/// Fills a view with a skin colour, clips it to the skin's corner radius and bevels it.
///
/// Every surface in the panel goes through this, so `cornerRadius` is honoured whether or
/// not the skin also draws bevels.
public struct SkinSurfaceModifier: ViewModifier {

    let color: SkinRGBA
    let style: BevelStyle

    @Environment(\.skin) private var skin

    public func body(content: Content) -> some View {
        content
            .background(color.color)
            .clipShape(
                RoundedRectangle(cornerRadius: skin.metrics.cornerRadius, style: .continuous)
            )
            .bevel(style)
    }
}

extension View {
    public func skinSurface(_ color: SkinRGBA, bevel style: BevelStyle) -> some View {
        modifier(SkinSurfaceModifier(color: color, style: style))
    }
}

/// Fine vertical grain plus a top-down vignette: what stops a large flat fill reading as
/// a rectangle rather than a sheet of painted metal.
public struct SkinTexture: View {

    @Environment(\.skin) private var skin

    public init() {}

    public var body: some View {
        Canvas { context, size in
            var x: CGFloat = 0
            while x < size.width {
                context.fill(
                    Path(CGRect(x: x, y: 0, width: 1, height: size.height)),
                    with: .color(.white.opacity(0.028))
                )
                context.fill(
                    Path(CGRect(x: x + 2, y: 0, width: 1, height: size.height)),
                    with: .color(.black.opacity(0.03))
                )
                x += 4
            }
        }
        .overlay {
            LinearGradient(
                colors: [.white.opacity(0.10), .clear, .black.opacity(0.16)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .allowsHitTesting(false)
    }
}
