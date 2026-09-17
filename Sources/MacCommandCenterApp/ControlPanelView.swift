import AppKit
import CommandCore
import SkinKit
import SwiftUI

/// The instrument panel itself: a readout and the buttons the active config defines.
///
/// Settings deliberately live in a separate, unskinned window. A skin should not have to
/// style a preferences form, and a preferences form should not have to survive a skin.
struct ControlPanelView: View {

    let model: AppModel

    /// Measured natural height of the contents. Used to decide whether scrolling is
    /// needed at all, rather than wrapping everything in a scroll view that would then
    /// have to be sized by hand.
    @State private var contentHeight: CGFloat = 0

    private var skin: Skin { model.skins.current }

    private var showsTitlebar: Bool { skin.metrics.titlebarHeight > 0 }

    var body: some View {
        VStack(spacing: 0) {
            if showsTitlebar {
                SkinTitlebar(
                    title: model.configs.current.name,
                    onSettings: { model.requestSettings?() },
                    onClose: { model.requestClose?() }
                )
                .background(WindowDragHandle())
            }

            // A config with many commands used to run off the bottom of the screen with
            // no way to reach the buttons: the window was clamped to the display and the
            // rest was simply clipped.
            if contentHeight > maximumContentHeight {
                ScrollView(.vertical) {
                    measuredContent
                }
                .frame(height: maximumContentHeight)
            } else {
                measuredContent
            }

            // A skin may set `titlebarHeight: 0` — the shipped Midnight does — which
            // leaves no close or settings control anywhere. Give it one.
            if !showsTitlebar {
                chromelessControls
            }
        }
        .frame(width: skin.metrics.width)
        .skinSurface(skin.colors.panel, bevel: .raised)
        .skin(skin)
        .onPreferenceChange(ContentHeightKey.self) { height in
            contentHeight = height
        }
    }

    // MARK: - Contents

    private var measuredContent: some View {
        VStack(alignment: .leading, spacing: skin.metrics.spacing) {
            readout

            ForEach(model.center.groups, id: \.self) { group in
                SkinSectionLabel(group)
                ForEach(model.center.descriptors(in: group)) { descriptor in
                    CommandSectionView(
                        model: model,
                        descriptor: descriptor,
                        shortcutOffset: shortcutOffset(for: descriptor)
                    )
                }
            }

            if model.center.descriptors.isEmpty {
                Text(skin.label("This config has no buttons."))
                    .font(skin.bodyFont)
                    .foregroundStyle(skin.colors.textDim.color)
            }

            if let error = model.center.lastError {
                Text(error)
                    .font(skin.bodyFont)
                    .foregroundStyle(skin.colors.readoutInk.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(skin.metrics.padding)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: ContentHeightKey.self, value: proxy.size.height)
            }
        )
    }

    /// Leaves room for the menu bar and a margin, so the panel always fits the display it
    /// opens on.
    private var maximumContentHeight: CGFloat {
        let available = NSScreen.main?.visibleFrame.height ?? 800
        return max(240, available - 120)
    }

    private var chromelessControls: some View {
        HStack(spacing: 6) {
            Spacer()
            PanelChromeButton(glyph: "\u{2699}", label: "Settings") { model.requestSettings?() }
            PanelChromeButton(glyph: "\u{2715}", label: "Close panel") { model.requestClose?() }
        }
        .padding(.horizontal, skin.metrics.padding)
        .padding(.bottom, skin.metrics.padding)
        .background(WindowDragHandle())
    }

    /// Digit shortcuts are numbered across the whole panel, not per command: two
    /// commands each starting at 1 meant only one of them ever responded.
    private func shortcutOffset(for descriptor: CommandDescriptor) -> Int {
        var offset = 0
        for other in model.center.descriptors {
            if other.id == descriptor.id { break }
            offset += other.options.count
        }
        return offset
    }

    // MARK: - Readout

    private var readout: some View {
        ReadoutView(
            primary: skin.label(readoutPrimary),
            secondary: skin.label(model.powerSource.rawValue),
            isActive: model.center.isAnythingActive,
            since: activeSince
        )
    }

    /// When something is latched, the readout runs a clock from here. Only that clock
    /// ticks now; the whole readout used to sit on a 1 Hz timeline.
    private var activeSince: Date? {
        model.center.activeCommands.first.flatMap { model.center.state(for: $0.id).since }
    }

    private var readoutPrimary: String {
        guard let active = model.center.activeCommands.first else {
            return model.center.descriptors.first.map { descriptor in
                model.center.state(for: descriptor.id).detail
            } ?? "Ready"
        }
        let state = model.center.state(for: active.id)
        return active.options.first { $0.id == state.activeOptionID }?.title ?? active.title
    }
}

private struct ContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// A small skinned square, used for the controls a titlebar-less skin would otherwise
/// leave the panel without.
private struct PanelChromeButton: View {

    let glyph: String
    let label: String
    let action: () -> Void

    @Environment(\.skin) private var skin

    var body: some View {
        Button(action: action) {
            Text(glyph)
                .font(skin.bodyFont)
                .foregroundStyle(skin.colors.buttonText.color)
                .frame(width: 18, height: 18)
                .skinSurface(skin.colors.buttonFace, bevel: .raised)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(label)
    }
}
