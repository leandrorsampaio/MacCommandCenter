import SwiftUI

// MARK: - Indicator lamp

public struct LEDView: View {

    private let isOn: Bool
    @Environment(\.skin) private var skin

    public init(isOn: Bool) {
        self.isOn = isOn
    }

    public var body: some View {
        let size = skin.metrics.ledSize
        let fill = isOn ? skin.colors.ledOn : skin.colors.ledOff

        Circle()
            .fill(fill.color)
            .frame(width: size, height: size)
            .overlay(Circle().strokeBorder(skin.colors.panelShadow.opacity(0.75), lineWidth: 1))
            .shadow(
                color: (isOn && skin.effects.glow) ? skin.colors.ledOn.opacity(0.95) : .clear,
                radius: skin.metrics.glowRadius * 0.7
            )
            .accessibilityHidden(true)
    }
}

// MARK: - Spectrum bars

/// The little analyser in the corner of the readout. Purely decorative, driven by a
/// `TimelineView` so SwiftUI stops ticking it when the panel is not on screen.
public struct VisualizerView: View {

    private let isActive: Bool
    private let barCount: Int
    @Environment(\.skin) private var skin

    public init(isActive: Bool, barCount: Int = 7) {
        self.isActive = isActive
        self.barCount = barCount
    }

    public var body: some View {
        Group {
            if isActive {
                TimelineView(.periodic(from: .now, by: 0.11)) { context in
                    bars(at: context.date.timeIntervalSinceReferenceDate)
                }
            } else {
                bars(at: nil)
            }
        }
        .frame(height: 26)
        .accessibilityHidden(true)
    }

    private func bars(at time: TimeInterval?) -> some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                Rectangle()
                    .fill((isActive ? skin.colors.visualizerOn : skin.colors.visualizerOff).color)
                    .frame(width: 3, height: height(index: index, time: time))
            }
        }
    }

    private func height(index: Int, time: TimeInterval?) -> CGFloat {
        guard let time else { return 3 }
        // Two out-of-phase sines per bar: cheap, deterministic, and it never repeats
        // visibly the way a short random table does.
        let a = sin(time * 4.1 + Double(index) * 1.7)
        let b = sin(time * 2.3 + Double(index) * 0.6)
        let level = (a * 0.6 + b * 0.4 + 1) / 2
        return 3 + CGFloat(level) * 23
    }
}

// MARK: - LCD readout

public struct ReadoutView: View {

    private let primary: String
    private let secondary: String
    private let isActive: Bool
    private let since: Date?
    private let showsVisualizer: Bool

    @Environment(\.skin) private var skin

    /// `since`, when given, is rendered as a running clock ahead of `secondary`. It is
    /// the only part that ticks: putting the whole readout on a timeline redrew the
    /// scanline canvas and the bars once a second for nothing.
    public init(
        primary: String,
        secondary: String,
        isActive: Bool,
        since: Date? = nil,
        showsVisualizer: Bool = true
    ) {
        self.primary = primary
        self.secondary = secondary
        self.isActive = isActive
        self.since = since
        self.showsVisualizer = showsVisualizer
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(primary)
                    .font(skin.readoutFont)
                    .foregroundStyle(primaryInk.color)
                    .shadow(color: glow, radius: skin.metrics.glowRadius)
                secondaryLine
                    .font(skin.fonts.readout.font)
                    .foregroundStyle(secondaryInk.color)
                    .opacity(0.9)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            Spacer(minLength: 0)

            if showsVisualizer && skin.effects.visualizer {
                VisualizerView(isActive: isActive)
            }
        }
        .padding(skin.metrics.readoutPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .skinSurface(skin.colors.readoutBackground, bevel: .flat)
        .overlay {
            if skin.effects.scanlines {
                Canvas { context, size in
                    var y: CGFloat = 0
                    while y < size.height {
                        context.fill(
                            Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                            with: .color(.black.opacity(0.42))
                        )
                        y += 3
                    }
                }
                .allowsHitTesting(false)
            }
        }
        .bevel(.sunken)
        .clipShape(
            RoundedRectangle(cornerRadius: skin.metrics.cornerRadius, style: .continuous)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(primary). \(secondary)")
    }

    @ViewBuilder
    private var secondaryLine: some View {
        if let since {
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                Text(Self.elapsed(since: since) + "  " + secondary)
            }
        } else {
            Text(secondary)
        }
    }

    static func elapsed(since: Date) -> String {
        let total = max(0, Int(Date().timeIntervalSince(since)))
        return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    private var primaryInk: SkinRGBA {
        isActive ? skin.colors.readoutInk : skin.colors.readoutInkIdle
    }

    private var secondaryInk: SkinRGBA {
        isActive ? skin.colors.readoutInkDim : skin.colors.readoutInkIdle
    }

    private var glow: Color {
        (isActive && skin.effects.glow) ? skin.colors.readoutInk.opacity(0.55) : .clear
    }
}

// MARK: - Buttons

/// A beveled push button. Pressing inverts the bevel, which is the entire interaction
/// language of this era.
public struct SkinPushButtonStyle: ButtonStyle {

    private let isActive: Bool
    private let fillsWidth: Bool
    @Environment(\.skin) private var skin

    /// `fillsWidth` false keeps the button at its natural size, for use inline beside
    /// other content rather than as a full-width bar.
    public init(isActive: Bool = false, fillsWidth: Bool = true) {
        self.isActive = isActive
        self.fillsWidth = fillsWidth
    }

    public func makeBody(configuration: Configuration) -> some View {
        let pressedIn = configuration.isPressed || isActive

        configuration.label
            .font(skin.displayFont)
            .tracking(skin.metrics.tracking)
            .foregroundStyle(
                (isActive ? skin.colors.buttonTextActive : skin.colors.buttonText).color
            )
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .padding(.vertical, 8)
            .padding(.horizontal, fillsWidth ? 0 : 10)
            .skinSurface(
                pressedIn ? skin.colors.buttonFacePressed : skin.colors.buttonFace,
                bevel: pressedIn ? .sunken : .raised
            )
            .contentShape(Rectangle())
    }
}

// MARK: - Titlebar

public struct SkinTitlebar: View {

    private let title: String
    private let onSettings: (() -> Void)?
    private let onClose: () -> Void

    @Environment(\.skin) private var skin

    public init(
        title: String,
        onSettings: (() -> Void)? = nil,
        onClose: @escaping () -> Void
    ) {
        self.title = title
        self.onSettings = onSettings
        self.onClose = onClose
    }

    public var body: some View {
        if skin.metrics.titlebarHeight > 0 {
            HStack(spacing: 5) {
                box
                Text(skin.label(title))
                    .font(skin.displayFont)
                    .tracking(skin.metrics.tracking)
                    .foregroundStyle(skin.colors.titlebarText.color)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let onSettings {
                    Button(action: onSettings) { box }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Settings")
                        .help("Settings")
                }
                Button(action: onClose) { box }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close panel")
                    .help("Close")
            }
            .padding(.horizontal, 5)
            .frame(height: skin.metrics.titlebarHeight)
            .background(
                LinearGradient(
                    colors: [skin.colors.titlebarTop.color, skin.colors.titlebarBottom.color],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(skin.colors.panelShadow.color)
                    .frame(height: max(1, skin.metrics.bevel / 2))
            }
        }
    }

    private var box: some View {
        Rectangle()
            .fill(skin.colors.titlebarButtonFace.color)
            .frame(width: 9, height: 9)
            .bevel(.raised)
    }
}

// MARK: - Section heading

public struct SkinSectionLabel: View {

    private let text: String
    @Environment(\.skin) private var skin

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(skin.label("\u{25B8} " + text))
            .font(skin.displayFont)
            .tracking(skin.metrics.tracking)
            .foregroundStyle(skin.colors.sectionLabel.color)
    }
}
