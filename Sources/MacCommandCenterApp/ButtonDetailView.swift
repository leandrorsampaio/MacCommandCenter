import ConfigKit
import SwiftUI

/// The form for one button: what it says, and what it does.
struct ButtonDetailView: View {

    @Binding var option: ConfigOption
    let supportsShell: Bool

    var body: some View {
        Section("Selected button") {
            TextField("Title", text: $option.title)
            TextField("Subtitle", text: $option.subtitle)

            HStack {
                TextField("Icon", text: $option.icon)
                iconPreview
            }

            Picker("Does", selection: kindBinding) {
                ForEach(ActionKind.allCases) { kind in
                    Text(kind.label).tag(kind)
                }
            }

            actionFields
        }
    }

    private var iconPreview: some View {
        Group {
            if NSImage(systemSymbolName: option.icon, accessibilityDescription: nil) != nil {
                Image(systemName: option.icon)
                    .frame(width: 22)
                    .accessibilityLabel("Preview of \(option.icon)")
            } else {
                Image(systemName: "questionmark.square.dashed")
                    .foregroundStyle(.tertiary)
                    .frame(width: 22)
                    .help("No SF Symbol with that name")
                    .accessibilityLabel("No SF Symbol named \(option.icon)")
            }
        }
    }

    @ViewBuilder
    private var actionFields: some View {
        switch option.action {
        case .keepAwake(let mode):
            Picker(
                "Mode",
                selection: Binding(
                    get: { mode },
                    set: { option.action = .keepAwake(mode: $0) }
                )
            ) {
                ForEach(KeepAwakeMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }

        case .openURL(let url):
            TextField(
                "URL",
                text: Binding(
                    get: { url.absoluteString },
                    set: { option.action = .openURL(URL(string: $0) ?? url) }
                ))

        case .shell(let shell):
            VStack(alignment: .leading, spacing: 8) {
                TextField(
                    "Command",
                    text: Binding(
                        get: { shell.command },
                        set: {
                            option.action = .shell(
                                ShellAction(
                                    command: $0, timeout: shell.timeout, detached: shell.detached))
                        }
                    ), axis: .vertical
                )
                .lineLimit(1...4)
                .font(.system(.body, design: .monospaced))

                HStack {
                    Toggle(
                        "Fire and forget",
                        isOn: Binding(
                            get: { shell.detached },
                            set: {
                                option.action = .shell(
                                    ShellAction(
                                        command: shell.command, timeout: shell.timeout, detached: $0
                                    ))
                            }
                        ))
                    Spacer()
                    Stepper(
                        "Timeout \(Int(shell.timeout))s",
                        value: Binding(
                            get: { shell.timeout },
                            set: {
                                option.action = .shell(
                                    ShellAction(
                                        command: shell.command, timeout: $0,
                                        detached: shell.detached))
                            }
                        ),
                        in: 1...600,
                        step: 5
                    )
                    .disabled(shell.detached)
                }

                Label(
                    supportsShell
                        ? "Runs through /bin/zsh -lc. The first press asks you to approve this exact command."
                        : "This build is sandboxed, so this button will explain itself instead of running. The command is kept.",
                    systemImage: supportsShell ? "info.circle" : "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(supportsShell ? Color.secondary : Color.orange)
            }

        case .unavailable(let reason, _):
            Label(reason, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    // MARK: - Action kind

    private var kindBinding: Binding<ActionKind> {
        Binding(
            get: { ActionKind(option.action) },
            set: { option.action = $0.defaultAction(replacing: option.action) }
        )
    }
}

enum ActionKind: String, CaseIterable, Identifiable {
    case keepAwake
    case openURL
    case shell

    var id: String { rawValue }

    var label: String {
        switch self {
        case .keepAwake: return "Keep the Mac awake"
        case .openURL: return "Open a URL, file or app"
        case .shell: return "Run a command"
        }
    }

    init(_ action: ActionSpec) {
        switch action {
        case .keepAwake: self = .keepAwake
        case .openURL: self = .openURL
        case .shell, .unavailable: self = .shell
        }
    }

    /// Keeps whatever payload carries over, so flipping kinds by accident is recoverable.
    func defaultAction(replacing current: ActionSpec) -> ActionSpec {
        switch self {
        case .keepAwake:
            if case .keepAwake = current { return current }
            return .keepAwake(mode: .systemOnly)
        case .openURL:
            if case .openURL = current { return current }
            return .openURL(URL(string: "https://example.com")!)
        case .shell:
            if case .shell = current { return current }
            return .shell(ShellAction(command: ""))
        }
    }
}
