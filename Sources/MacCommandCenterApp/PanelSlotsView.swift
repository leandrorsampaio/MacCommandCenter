import CommandCore
import SkinKit
import SwiftUI

/// Renders a panel from the slots a skin declared.
///
/// The skin says what goes where; this decides what each part is fed. Nothing a skin
/// writes is executed — it picks from a fixed vocabulary, and every value shown comes from
/// the command registry or the system.
struct PanelSlotsView: View {

    let model: AppModel
    let rows: [SkinSlot]

    /// Which option is mechanically held down. Separate from what the registry reports,
    /// because a key latches the instant it is pressed while the lamps wait on the
    /// command actually running — which is what `indicatorDelay` is for.
    @State private var latched: [CommandID: String] = [:]

    @Environment(\.skin) private var skin

    var body: some View {
        VStack(alignment: .leading, spacing: skin.metrics.spacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, slot in
                view(for: slot)
            }
        }
        .onAppear(perform: syncLatches)
        .onChange(of: model.center.states) { _, _ in syncLatches() }
    }

    /// Type-erased because `.row` recurses: an opaque return type cannot be defined in
    /// terms of itself. The nesting here is a handful of slots deep at most.
    private func view(for slot: SkinSlot) -> AnyView {
        AnyView(body(for: slot))
    }

    @ViewBuilder
    private func body(for slot: SkinSlot) -> some View {
        switch slot {
        case .nameplate(let title, let subtitle):
            SkinNameplate(
                title: title ?? model.configs.current.name,
                subtitle: subtitle ?? ""
            )

        case .annunciator:
            SkinAnnunciator(cells: annunciatorCells)

        case .readout(let style):
            switch style {
            case .lcd:
                ReadoutView(
                    primary: skin.label(modeLine),
                    secondary: skin.label(model.powerSource.rawValue),
                    isActive: model.center.isAnythingActive,
                    since: activeSince
                )
            case .nixie:
                SkinModule(caption: "Indicators", trailing: "SKALA") {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        SkinNixie(
                            caption: "Uptime",
                            value: uptime,
                            secondCaption: "Mode",
                            secondValue: modeLine,
                            isActive: model.center.isAnythingActive
                        )
                    }
                }
            }

        case .gauge(let source, let width):
            switch source {
            case .battery:
                SkinModule(caption: "Battery", trailing: "%") {
                    SkinGauge(value: model.powerStatus.charge ?? 1, caption: "")
                }
                .frame(width: width.map { CGFloat($0) })
            }

        case .commands(let style, let columns):
            commands(style: style, columns: columns)

        case .lamps(let style):
            SkinLampRow(lamps: lamps, style: style)

        case .controls(let labels):
            controls(labels)

        case .spacer:
            Spacer(minLength: 0)

        case .row(let children):
            // Side-by-side modules share a height, so the row does not step.
            HStack(alignment: .top, spacing: skin.metrics.spacing) {
                ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                    view(for: child).frame(maxHeight: .infinity)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Commands

    @ViewBuilder
    private func commands(style: CommandStyle, columns: Int) -> some View {
        switch style {
        case .tile:
            VStack(alignment: .leading, spacing: skin.metrics.spacing) {
                ForEach(model.center.descriptors) { descriptor in
                    CommandSectionView(
                        model: model,
                        descriptor: descriptor,
                        shortcutOffset: shortcutOffset(for: descriptor)
                    )
                }
            }
        case .key:
            let entries = keyEntries
            let perRow = columns > 0 ? columns : max(1, entries.count)
            VStack(spacing: skin.metrics.spacing) {
                ForEach(Array(stride(from: 0, to: entries.count, by: perRow)), id: \.self) {
                    start in
                    let slice = Array(entries[start..<min(start + perRow, entries.count)])
                    HStack(spacing: skin.metrics.spacing) {
                        ForEach(slice) { entry in
                            keyButton(entry).frame(maxHeight: .infinity)
                        }
                        // Hold the empty columns open: a lone key in the final row should
                        // stay a key rather than stretching into a bar.
                        ForEach(Array(0..<max(0, perRow - slice.count)), id: \.self) { _ in
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private struct KeyEntry: Identifiable {
        let id: String
        let command: CommandID
        let option: CommandOption
        let shortcut: Int
    }

    private var keyEntries: [KeyEntry] {
        var entries: [KeyEntry] = []
        var shortcut = 1
        for descriptor in model.center.descriptors {
            for option in descriptor.options {
                entries.append(
                    KeyEntry(
                        id: descriptor.id.rawValue + "." + option.id,
                        command: descriptor.id,
                        option: option,
                        shortcut: shortcut
                    )
                )
                shortcut += 1
            }
        }
        return entries
    }

    private func keyButton(_ entry: KeyEntry) -> some View {
        let isLatched = latched[entry.command] == entry.option.id

        return Button {
            press(entry)
        } label: {
            keyLabel(entry.option.title, note: entry.option.subtitle)
        }
        .buttonStyle(SkinKeyButtonStyle(isLatched: isLatched, role: keyRole(entry.option.role)))
        .disabled(!entry.option.isEnabled)
        .opacity(entry.option.isEnabled ? 1 : 0.5)
        .keyboardShortcut(digit(entry.shortcut), modifiers: [])
        .accessibilityAddTraits(isLatched ? [.isSelected] : [])
        .help(entry.option.subtitle)
    }

    /// A command's meaning, expressed as visual emphasis. The two vocabularies are
    /// deliberately separate: SkinKit has no idea what a command is.
    private func keyRole(_ role: CommandRole) -> SkinKeyRole {
        switch role {
        case .normal: .normal
        case .caution: .caution
        case .danger: .danger
        }
    }

    /// The key falls the moment it is struck; the command follows after the skin's delay.
    private func press(_ entry: KeyEntry) {
        if skin.chrome.keyClick { KeyClick.play(file: skin.keySoundURL) }

        let wasLatched = latched[entry.command] == entry.option.id
        latched[entry.command] = wasLatched ? nil : entry.option.id

        let delay = skin.metrics.indicatorDelay
        let perform = {
            model.center.tryPerform(.toggle(optionID: entry.option.id), on: entry.command)
            syncLatches()
        }

        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { perform() }
        } else {
            perform()
        }
    }

    /// Keeps the mechanical state honest: whatever the registry actually did wins.
    private func syncLatches() {
        var current: [CommandID: String] = [:]
        for descriptor in model.center.descriptors {
            if let option = model.center.state(for: descriptor.id).activeOptionID {
                current[descriptor.id] = option
            }
        }
        latched = current
    }

    private func digit(_ number: Int) -> KeyEquivalent {
        guard (1...9).contains(number), let character = "\(number)".first else { return .clear }
        return KeyEquivalent(character)
    }

    // MARK: - Controls

    private func controls(_ labels: ControlLabels) -> some View {
        HStack(spacing: skin.metrics.spacing) {
            Button {
                if skin.chrome.keyClick { KeyClick.play(file: skin.keySoundURL) }
                model.floatsOnTop.toggle()
            } label: {
                keyLabel(labels.onTop ?? "Always on top", note: labels.onTopNote)
            }
            .buttonStyle(SkinKeyButtonStyle(isLatched: model.floatsOnTop))
            .accessibilityAddTraits(model.floatsOnTop ? [.isSelected] : [])
            .frame(maxHeight: .infinity)

            Button {
                if skin.chrome.keyClick { KeyClick.play(file: skin.keySoundURL, pitch: 420) }
                model.requestClose?()
            } label: {
                keyLabel(labels.close ?? "Close", note: labels.closeNote ?? "close panel")
            }
            .buttonStyle(SkinKeyButtonStyle())
            .frame(maxHeight: .infinity)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// A key legend with its note underneath, the shape every key on the panel uses.
    private func keyLabel(_ title: String, note: String?) -> some View {
        VStack(spacing: 4) {
            Text(skin.label(title))
                .font(skin.legendTitleFont)
            if let note, !note.isEmpty {
                Text(note)
                    .font(skin.legendNoteFont)
                    .opacity(0.62)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Derived content

    /// The instruments are labelled in English even when the keys are not: a readout,
    /// an annunciator cell and a lamp are all short legends, and mixing languages across
    /// one panel reads as a mistake rather than a flourish.
    ///
    /// A bilingual string is written "Режим сна · Sleep mode", so the English is the part
    /// after the separator. A single-language string is used as it stands.
    private func legend(_ text: String) -> String {
        let parts = text.split(separator: "·", maxSplits: 1).map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        return parts.count > 1 ? parts[1] : (parts.first ?? text)
    }

    private var annunciatorCells: [SkinAnnunciator.Cell] {
        var cells = model.center.descriptors.map { descriptor in
            SkinAnnunciator.Cell(
                id: descriptor.id.rawValue,
                label: legend(descriptor.title),
                isLit: model.center.state(for: descriptor.id).isActive
            )
        }
        cells.append(
            SkinAnnunciator.Cell(
                id: "mains", label: "Mains", isLit: model.powerStatus.source == .ac))
        cells.append(
            SkinAnnunciator.Cell(id: "ontop", label: "On top", isLit: model.floatsOnTop))
        return cells
    }

    private var lamps: [SkinLampRow.Lamp] {
        var lamps = model.center.descriptors.map { descriptor in
            SkinLampRow.Lamp(
                id: descriptor.id.rawValue,
                label: legend(descriptor.title),
                isLit: model.center.state(for: descriptor.id).isActive
            )
        }
        lamps.append(
            SkinLampRow.Lamp(
                id: "battery",
                label: "Battery",
                isLit: (model.powerStatus.charge ?? 1) > 0.2
            ))
        return lamps
    }

    private var activeSince: Date? {
        model.center.activeCommands.first.flatMap { model.center.state(for: $0.id).since }
    }

    private var uptime: String {
        guard let since = activeSince else { return "00:00:00" }
        let total = max(0, Int(Date().timeIntervalSince(since)))
        return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    private var modeLine: String {
        guard let active = model.center.activeCommands.first else { return "Sleep allowed" }
        let state = model.center.state(for: active.id)
        guard let option = active.options.first(where: { $0.id == state.activeOptionID }) else {
            return legend(active.title)
        }
        // The subtitle is the English explanation; its first clause is the mode.
        let note =
            option.subtitle.split(separator: "·", maxSplits: 1).first
            .map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        return note.isEmpty ? legend(option.title) : note
    }

    private func shortcutOffset(for descriptor: CommandDescriptor) -> Int {
        var offset = 0
        for other in model.center.descriptors {
            if other.id == descriptor.id { break }
            offset += other.options.count
        }
        return offset
    }
}
