import CommandCore
import SkinKit
import SwiftUI

/// The instrument panel itself: a readout and the buttons the active config defines.
///
/// Settings deliberately live in a separate, unskinned window. A skin should not have to
/// style a preferences form, and a preferences form should not have to survive a skin.
struct ControlPanelView: View {

    let model: AppModel

    private var skin: Skin { model.skins.current }

    var body: some View {
        VStack(spacing: 0) {
            SkinTitlebar(
                title: model.configs.current.name,
                onSettings: { model.requestSettings?() },
                onClose: { model.requestClose?() }
            )
            .background(WindowDragHandle())

            VStack(alignment: .leading, spacing: skin.metrics.spacing) {
                readout

                ForEach(model.center.groups, id: \.self) { group in
                    SkinSectionLabel(group)
                    ForEach(model.center.descriptors(in: group)) { descriptor in
                        CommandSectionView(model: model, descriptor: descriptor)
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
        }
        .frame(width: skin.metrics.width)
        .background(skin.colors.panel.color)
        .bevel(.raised)
        .skin(skin)
    }

    // MARK: - Readout

    private var readout: some View {
        // Ticks once a second so the elapsed clock counts up; SwiftUI stops the timeline
        // when the window is off screen.
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            ReadoutView(
                primary: skin.label(readoutPrimary),
                secondary: skin.label(readoutSecondary),
                isActive: model.center.isAnythingActive
            )
        }
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

    private var readoutSecondary: String {
        guard let active = model.center.activeCommands.first else {
            return model.powerSource.rawValue
        }
        let state = model.center.state(for: active.id)
        let elapsed = state.since.map(Self.elapsed(since:)) ?? "--:--:--"
        return elapsed + "  \u{00B7}  " + model.powerSource.rawValue
    }

    private static func elapsed(since: Date) -> String {
        let total = max(0, Int(Date().timeIntervalSince(since)))
        return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }
}
