import CommandCore
import SkinKit
import SwiftUI

/// One command rendered as a row of beveled tiles, one per option, plus an off switch.
/// Generic over the descriptor, so a newly registered command needs no code here.
struct CommandSectionView: View {

    let model: AppModel
    let descriptor: CommandDescriptor
    /// How many options appear above this command in the panel, so digit keys stay unique.
    let shortcutOffset: Int

    @Environment(\.skin) private var skin

    private var state: CommandState { model.center.state(for: descriptor.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                ForEach(Array(descriptor.options.enumerated()), id: \.element.id) { index, option in
                    CommandTile(
                        option: option,
                        isActive: state.activeOptionID == option.id,
                        shortcutNumber: shortcutOffset + index + 1
                    ) {
                        model.center.tryPerform(.toggle(optionID: option.id), on: descriptor.id)
                    }
                    .disabled(!option.isEnabled)
                    .opacity(option.isEnabled ? 1 : 0.5)
                }
            }

            HStack(spacing: 7) {
                Text(skin.label(state.detail))
                    .font(skin.bodyFont)
                    .foregroundStyle(skin.colors.textDim.color)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if descriptor.kind == .mode {
                    Button(skin.label("Off")) {
                        model.center.tryPerform(.deactivate, on: descriptor.id)
                    }
                    .buttonStyle(SkinPushButtonStyle(isActive: false))
                    .disabled(!state.isActive)
                    .opacity(state.isActive ? 1 : 0.45)
                    .fixedSize()
                }
            }
        }
    }
}

private struct CommandTile: View {

    let option: CommandOption
    let isActive: Bool
    let shortcutNumber: Int
    let action: () -> Void

    @Environment(\.skin) private var skin

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Image(systemName: option.systemImage)
                        .font(.system(size: 15))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(titleColor)
                    Spacer(minLength: 0)
                    LEDView(isOn: isActive)
                }

                Spacer(minLength: 12)

                Text(skin.label(option.title))
                    .font(skin.displayFont)
                    .tracking(skin.metrics.tracking)
                    .foregroundStyle(titleColor)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 6)

                Text(option.subtitle)
                    .font(skin.bodyFont)
                    .foregroundStyle(subtitleColor)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 4)

                HStack {
                    Spacer()
                    Text("\(shortcutNumber)")
                        .font(skin.bodyFont)
                        .foregroundStyle(skin.colors.textDim.color)
                }
            }
            .multilineTextAlignment(.leading)
            .padding(9)
            .frame(maxWidth: .infinity, minHeight: skin.metrics.tileHeight, alignment: .topLeading)
            .background((isActive ? skin.colors.buttonFacePressed : skin.colors.buttonFace).color)
            .bevel(isActive ? .sunken : .raised)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Only the first nine get a digit: Character("10") is two grapheme clusters and
        // traps, and there is no sensible single-key shortcut past 9 anyway.
        .modifier(DigitShortcut(number: shortcutNumber))
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
        .help(isActive ? "Click to turn off" : option.subtitle)
    }

    private var titleColor: Color {
        (isActive ? skin.colors.buttonTextActive : skin.colors.buttonText).color
    }

    private var subtitleColor: Color {
        (isActive ? skin.colors.buttonSubtextActive : skin.colors.buttonSubtext).color
    }
}

/// Binds digit keys 1–9 to the first nine options, and nothing beyond that.
private struct DigitShortcut: ViewModifier {

    let number: Int

    func body(content: Content) -> some View {
        if (1...9).contains(number), let digit = "\(number)".first {
            content.keyboardShortcut(KeyEquivalent(digit), modifiers: [])
        } else {
            content
        }
    }
}
