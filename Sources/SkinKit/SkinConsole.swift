import SwiftUI

// Parts a console skin composes its panel from. Each is driven entirely by skin tokens,
// so the same component renders as Soviet bakelite or as flat modern glass.

// MARK: - Engraved plate

/// The header plate, and the caption strip on a module.
public struct SkinPlate<Content: View>: View {

    private let content: Content
    @Environment(\.skin) private var skin

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(skin.colors.plate.color)
            .overlay(alignment: .top) {
                Rectangle().fill(.white.opacity(0.35)).frame(height: 1)
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(.black.opacity(0.3)).frame(height: 1)
            }
            .clipShape(
                RoundedRectangle(cornerRadius: skin.metrics.cornerRadius, style: .continuous))
    }
}

public struct SkinNameplate: View {

    private let title: String
    private let subtitle: String

    @Environment(\.skin) private var skin

    public init(title: String, subtitle: String) {
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        SkinPlate {
            VStack(alignment: .leading, spacing: 2) {
                Text(skin.label(title))
                    .font(skin.displayFont)
                    .tracking(skin.metrics.tracking)
                    .foregroundStyle(skin.colors.plateText.color)
                if !subtitle.isEmpty {
                    Text(skin.label(subtitle))
                        .font(skin.bodyFont)
                        .tracking(skin.metrics.tracking * 0.7)
                        .foregroundStyle(skin.colors.plateText.opacity(0.75))
                }
            }
        }
    }
}

/// A raised sub-panel with an engraved caption strip, the way instruments are bolted
/// onto a console rather than floating on it.
public struct SkinModule<Content: View>: View {

    private let caption: String
    private let trailing: String
    private let content: Content

    @Environment(\.skin) private var skin

    public init(caption: String, trailing: String = "", @ViewBuilder content: () -> Content) {
        self.caption = caption
        self.trailing = trailing
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(skin.label(caption))
                    .font(skin.displayFont)
                    .tracking(skin.metrics.tracking * 1.3)
                if !trailing.isEmpty {
                    Spacer(minLength: 6)
                    Text(trailing)
                        .font(skin.readoutFont)
                        .opacity(0.65)
                }
            }
            .foregroundStyle(skin.colors.plateText.color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(skin.colors.plate.color)
            .overlay(alignment: .bottom) {
                Rectangle().fill(skin.colors.panelShadow.opacity(0.7)).frame(height: 2)
            }

            content
                .padding(12)
                .frame(maxWidth: .infinity)
        }
        .background(
            LinearGradient(
                colors: [
                    skin.colors.panelHighlight.color,
                    skin.colors.panel.color,
                    skin.colors.panelShadow.opacity(0.55),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay {
            RoundedRectangle(cornerRadius: skin.metrics.cornerRadius + 2, style: .continuous)
                .strokeBorder(skin.colors.panelShadow.opacity(0.8), lineWidth: 2)
        }
        .clipShape(
            RoundedRectangle(cornerRadius: skin.metrics.cornerRadius + 2, style: .continuous)
        )
        .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
    }
}

// MARK: - Annunciator

/// One backlit legend cell per entry: dark until its condition is true.
public struct SkinAnnunciator: View {

    public struct Cell: Identifiable, Equatable {
        public let id: String
        public let label: String
        public let isLit: Bool

        public init(id: String, label: String, isLit: Bool) {
            self.id = id
            self.label = label
            self.isLit = isLit
        }
    }

    private let cells: [Cell]
    @Environment(\.skin) private var skin

    public init(cells: [Cell]) {
        self.cells = cells
    }

    public var body: some View {
        HStack(spacing: 7) {
            ForEach(cells) { cell in
                Text(skin.label(cell.label))
                    .font(skin.bodyFont)
                    .tracking(skin.metrics.tracking * 0.6)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.55)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 7)
                    .padding(.horizontal, 4)
                    // Equal widths whatever the legends say, so the row reads as a strip.
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .foregroundStyle(
                        cell.isLit ? skin.colors.readoutBackground.color : skin.colors.textDim.color
                    )
                    .background(cell.isLit ? skin.colors.ledOn.color : skin.colors.ledOff.color)
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: skin.metrics.cornerRadius, style: .continuous
                        )
                        .strokeBorder(skin.colors.panelShadow.color, lineWidth: 2)
                    }
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: skin.metrics.cornerRadius, style: .continuous)
                    )
                    .shadow(
                        color: cell.isLit && skin.effects.glow
                            ? skin.colors.ledOn.opacity(0.75) : .clear,
                        radius: skin.metrics.glowRadius
                    )
            }
        }
    }
}

// MARK: - Nixie

/// A large glowing counter with a caption, and a second line for the current mode.
public struct SkinNixie: View {

    private let caption: String
    private let value: String
    private let secondCaption: String
    private let secondValue: String
    private let isActive: Bool

    @Environment(\.skin) private var skin

    public init(
        caption: String,
        value: String,
        secondCaption: String,
        secondValue: String,
        isActive: Bool
    ) {
        self.caption = caption
        self.value = value
        self.secondCaption = secondCaption
        self.secondValue = secondValue
        self.isActive = isActive
    }

    public var body: some View {
        VStack(spacing: 9) {
            glass {
                Text(skin.label(caption))
                    .font(skin.bodyFont)
                    .tracking(skin.metrics.tracking)
                    .foregroundStyle(skin.colors.readoutInkIdle.color)
                Text(value)
                    .font(.custom(readoutFamily, fixedSize: skin.fonts.readout.size * 2.4))
                    .monospacedDigit()
                    .foregroundStyle(ink.color)
                    .shadow(color: glow, radius: skin.metrics.glowRadius)
                    .shadow(color: glow.opacity(0.5), radius: skin.metrics.glowRadius * 2.4)
            }
            glass {
                Text(skin.label(secondCaption))
                    .font(skin.bodyFont)
                    .tracking(skin.metrics.tracking)
                    .foregroundStyle(skin.colors.readoutInkIdle.color)
                Text(skin.label(secondValue))
                    .font(skin.readoutFont)
                    .foregroundStyle(ink.color)
                    .shadow(color: glow, radius: skin.metrics.glowRadius * 0.7)
            }
        }
    }

    private var readoutFamily: String {
        skin.fonts.readout.family ?? "Menlo"
    }

    private var ink: SkinRGBA {
        isActive ? skin.colors.readoutInk : skin.colors.readoutInkDim
    }

    private var glow: Color {
        skin.effects.glow ? skin.colors.readoutInk.opacity(0.7) : .clear
    }

    @ViewBuilder
    private func glass<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, skin.metrics.readoutPadding + 2)
        .padding(.vertical, skin.metrics.readoutPadding - 2)
        .background(skin.colors.readoutBackground.color)
        .overlay {
            RoundedRectangle(cornerRadius: skin.metrics.cornerRadius, style: .continuous)
                .strokeBorder(skin.colors.panelShadow.color, lineWidth: 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: skin.metrics.cornerRadius, style: .continuous))
    }
}

// MARK: - Gauge

/// An analogue dial. The needle is a separate rotated view so it animates; the face and
/// its printing are drawn once.
public struct SkinGauge: View {

    private let value: Double
    private let caption: String

    @Environment(\.skin) private var skin

    /// `value` is 0...1.
    public init(value: Double, caption: String) {
        self.value = min(1, max(0, value))
        self.caption = caption
    }

    private func angle(jitter: Double) -> Double {
        -150 + min(1, max(0, value + jitter)) * 120
    }

    /// Analogue wander, derived from the tick rather than stored.
    ///
    /// `@State` would be the obvious way to do this, but these views are type-erased to
    /// break a recursive layout, and erased state does not reliably survive a re-render —
    /// the needle simply sat still. A pure function of the tick cannot be lost.
    ///
    /// Roughly seven ticks in ten the value moves, by up to five points of full scale;
    /// the rest of the time it holds where it was, which is what makes it read as a
    /// needle rather than an animation.
    static func jitter(tick: Int) -> Double {
        var moment = tick
        var steps = 0
        while steps < 5 && scramble(moment) % 10 >= 7 {
            moment -= 1
            steps += 1
        }
        return (Double(scramble(moment) % 1000) / 1000 - 0.5) * 0.10
    }

    /// FNV-1a over the tick: cheap, and stable for a given tick.
    private static func scramble(_ value: Int) -> Int {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in withUnsafeBytes(of: Int64(value).littleEndian, Array.init) {
            hash ^= UInt64(byte)
            hash &*= 0x1000_0000_01b3
        }
        return Int(hash % 100_000)
    }

    public var body: some View {
        VStack(spacing: 6) {
            if skin.effects.flicker {
                TimelineView(.periodic(from: .now, by: 0.5)) { context in
                    let tick = Int(context.date.timeIntervalSinceReferenceDate * 2)
                    dial(angle: angle(jitter: Self.jitter(tick: tick)))
                }
            } else {
                dial(angle: angle(jitter: 0))
            }

            if !caption.isEmpty {
                Text(skin.label(caption))
                    .font(skin.bodyFont)
                    .tracking(skin.metrics.tracking)
                    .foregroundStyle(skin.colors.text.color)
            }
        }
    }

    private func dial(angle: Double) -> some View {
        Color.clear
            .aspectRatio(200.0 / 118.0, contentMode: .fit)
            .overlay { face }
            .overlay { needle(angle: angle) }
    }

    private var face: some View {
        Canvas { context, size in
            let centre = CGPoint(x: size.width / 2, y: size.height * 0.87)
            let radius = min(size.width * 0.42, size.height * 0.78)

            func point(_ fraction: Double, _ distance: Double) -> CGPoint {
                let radians = ((-150 + fraction * 120) * .pi) / 180
                return CGPoint(
                    x: centre.x + distance * cos(radians),
                    y: centre.y + distance * sin(radians)
                )
            }

            // Zone arcs: low is bad, then caution, then the working range.
            for (from, to, colour) in [
                (0.0, 0.2, SkinRGBA(hex: "#D2321F")!),
                (0.2, 0.4, SkinRGBA(hex: "#E0A020")!),
                (0.4, 1.0, SkinRGBA(hex: "#3AA15A")!),
            ] {
                var path = Path()
                path.addArc(
                    center: centre,
                    radius: radius,
                    startAngle: .degrees(-150 + from * 120),
                    endAngle: .degrees(-150 + to * 120),
                    clockwise: false
                )
                context.stroke(path, with: .color(colour.color), lineWidth: radius * 0.07)
            }

            for index in 0...10 {
                let major = index % 2 == 0
                var path = Path()
                path.move(to: point(Double(index) / 10, radius * 0.88))
                path.addLine(to: point(Double(index) / 10, radius * (major ? 0.68 : 0.76)))
                context.stroke(
                    path,
                    with: .color(skin.colors.gaugeInk.color),
                    lineWidth: major ? 2.5 : 1.5
                )
            }
        }
        .background(skin.colors.gaugeFace.color)
        .overlay {
            RoundedRectangle(cornerRadius: skin.metrics.cornerRadius + 4, style: .continuous)
                .strokeBorder(skin.colors.panelShadow.color, lineWidth: 4)
        }
        .clipShape(
            RoundedRectangle(cornerRadius: skin.metrics.cornerRadius + 4, style: .continuous))
    }

    private func needle(angle: Double) -> some View {
        GeometryReader { proxy in
            let centre = CGPoint(x: proxy.size.width / 2, y: proxy.size.height * 0.87)
            let length = min(proxy.size.width * 0.42, proxy.size.height * 0.78) * 0.95

            ZStack {
                Capsule()
                    .fill(skin.colors.needle.color)
                    .frame(width: 2.5, height: length)
                    .offset(y: -length / 2)
                    .rotationEffect(.degrees(angle + 90))
                Circle()
                    .fill(skin.colors.panelShadow.color)
                    .overlay(
                        Circle().strokeBorder(skin.colors.gaugeInk.opacity(0.6), lineWidth: 1.5)
                    )
                    .frame(width: 11, height: 11)
            }
            .position(centre)
            .animation(.interpolatingSpring(stiffness: 120, damping: 9), value: angle)
        }
    }
}

// MARK: - Lamps

public struct SkinLampRow: View {

    public struct Lamp: Identifiable, Equatable {
        public let id: String
        public let label: String
        public let isLit: Bool

        public init(id: String, label: String, isLit: Bool) {
            self.id = id
            self.label = label
            self.isLit = isLit
        }
    }

    private let lamps: [Lamp]
    @Environment(\.skin) private var skin

    public init(lamps: [Lamp]) {
        self.lamps = lamps
    }

    public var body: some View {
        HStack(spacing: 16) {
            ForEach(lamps) { lamp in
                VStack(spacing: 5) {
                    dome(isLit: lamp.isLit)
                    Text(skin.label(lamp.label))
                        .font(skin.bodyFont)
                        .tracking(skin.metrics.tracking * 0.5)
                        .foregroundStyle(skin.colors.text.color)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(.black.opacity(0.10))
        .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.18)).frame(height: 1) }
        .clipShape(RoundedRectangle(cornerRadius: skin.metrics.cornerRadius, style: .continuous))
    }

    /// Domed glass: a hot core off-centre, a bezel ring, and bloom only when lit.
    private func dome(isLit: Bool) -> some View {
        let size = skin.metrics.ledSize + 5
        return Circle()
            .fill(
                RadialGradient(
                    colors: isLit
                        ? [
                            .white.opacity(0.95), skin.colors.ledOn.color,
                            skin.colors.ledOn.opacity(0.45),
                        ]
                        : [
                            skin.colors.ledOff.opacity(0.85), skin.colors.ledOff.color,
                            .black.opacity(0.6),
                        ],
                    center: UnitPoint(x: 0.38, y: 0.3),
                    startRadius: 0,
                    endRadius: size * 0.75
                )
            )
            .overlay(Circle().strokeBorder(skin.colors.panelShadow.color, lineWidth: 2))
            .frame(width: size, height: size)
            .shadow(
                color: isLit && skin.effects.glow ? skin.colors.ledOn.opacity(0.9) : .clear,
                radius: skin.metrics.glowRadius
            )
    }
}

// MARK: - Relief key

/// A latching pushbutton. The cap never changes colour — it is a physical object — and it
/// stays down once latched, over-travelling slightly before it releases.
/// How much emphasis a key carries. This is a *visual* vocabulary: SkinKit does not know
/// what a command is, so the app maps a command's meaning onto one of these.
public enum SkinKeyRole: Sendable {
    case normal
    case caution
    case danger
}

public struct SkinKeyButtonStyle: ButtonStyle {

    private let isLatched: Bool
    private let role: SkinKeyRole

    @Environment(\.skin) private var skin

    public init(isLatched: Bool = false, role: SkinKeyRole = .normal) {
        self.isLatched = isLatched
        self.role = role
    }

    public func makeBody(configuration: Configuration) -> some View {
        let relief = skin.metrics.keyRelief
        let travel: Double =
            switch (isLatched, configuration.isPressed) {
            case (true, true): relief * 1.25
            case (true, false): relief * 0.8
            case (false, true): relief * 0.8
            case (false, false): 0
            }
        let standing = max(0, relief - travel)

        let face: SkinRGBA =
            switch role {
            case .normal: skin.colors.buttonFace
            case .caution: skin.colors.keyCaution
            case .danger: skin.colors.keyDanger
            }
        let ink = role == .normal ? skin.colors.buttonText : skin.colors.buttonTextActive
        let shape = RoundedRectangle(cornerRadius: skin.metrics.cornerRadius, style: .continuous)

        return configuration.label
            .font(skin.displayFont)
            .tracking(skin.metrics.tracking)
            .foregroundStyle(ink.color)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: skin.metrics.keyHeight)
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .background(
                LinearGradient(
                    colors: [face.opacity(1), face.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(alignment: .top) {
                Rectangle().fill(.white.opacity(0.30)).frame(height: 1)
            }
            // The cap is not flat: it shades into its own bottom edge.
            .overlay {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.34)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            }
            .overlay {
                // A sunk cap darkens from its top edge, the way a recessed key does.
                LinearGradient(
                    colors: [.black.opacity(travel > 0 ? 0.3 : 0), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
            }
            .clipShape(shape)
            // The wall the cap stands on, shortening as the key sinks.
            .background(shape.fill(skin.colors.keyWall.color).offset(y: standing))
            // The collar: a darker lip a little wider than the wall, which is what stops
            // the key looking printed on the panel.
            .background(
                shape
                    .fill(skin.colors.keyWall.opacity(0.85))
                    .padding(-2)
                    .offset(y: standing + 1)
            )
            .offset(y: travel)
            .shadow(color: .black.opacity(0.45), radius: 5, y: 3)
            .padding(.bottom, relief)
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.07), value: travel)
    }
}

// MARK: - Screws

/// Four corner screws, slot rotated so they look driven rather than stamped.
public struct SkinScrews: View {

    @Environment(\.skin) private var skin

    public init() {}

    public var body: some View {
        ZStack {
            screw.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            screw.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            screw.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            screw.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .padding(6)
        .allowsHitTesting(false)
    }

    private var screw: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [skin.colors.panelHighlight.color, skin.colors.panelShadow.color],
                    center: UnitPoint(x: 0.35, y: 0.35),
                    startRadius: 0,
                    endRadius: 7
                )
            )
            .overlay {
                Capsule()
                    .fill(.black.opacity(0.55))
                    .frame(width: 8, height: 2)
                    .rotationEffect(.degrees(30))
            }
            .frame(width: 10, height: 10)
    }
}
