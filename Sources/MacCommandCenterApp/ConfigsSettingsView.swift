import AppKit
import ConfigKit
import SwiftUI

/// Where buttons are renamed, reordered and re-pointed at different actions.
///
/// Edits work on a draft copy and are written only on Save, so the folder watcher cannot
/// reload a half-finished config out from under the editor.
struct ConfigsSettingsView: View {

    let model: AppModel

    @State private var draft = AppConfig.standard
    @State private var selection: ButtonPath?
    @State private var failure: String?
    /// Compared against, rather than a flag: a flag had to be cleared after SwiftUI
    /// delivered the change notification, which it never reliably was.
    @State private var baseline = AppConfig.standard

    private var isDirty: Bool { draft != baseline }

    var body: some View {
        HSplitView {
            configList
                .frame(minWidth: 200, idealWidth: 230, maxWidth: 300)
            editor
                .frame(minWidth: 420)
        }
        .onAppear(perform: loadDraft)
        .onChange(of: model.configs.selectedID) { _, _ in loadDraft() }
    }

    // MARK: - List

    private var configList: some View {
        VStack(spacing: 0) {
            List(
                selection: Binding(
                    get: { model.configs.selectedID },
                    set: { model.configs.selectedID = $0 ?? model.configs.selectedID }
                )
            ) {
                ForEach(model.configs.configs) { config in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(config.name).fontWeight(.medium)
                        HStack(spacing: 4) {
                            if config.isBuiltIn { Badge("Built in") }
                            if config.usesShellActions { Badge("Shell", tint: .orange) }
                            Text("\(config.allCommands.count) commands")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                    .tag(config.id)
                }
            }
            .listStyle(.inset)

            Divider()

            HStack(spacing: 6) {
                Button("Import…") { importConfig() }
                Button("Duplicate") { duplicate() }
                Menu {
                    Button("Reveal Folder") { model.configs.revealFolder() }
                    Button("Reload") { model.configs.reload() }
                    Divider()
                    Button("Delete", role: .destructive) { delete() }
                        .disabled(model.configs.current.isBuiltIn)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(10)
        }
    }

    // MARK: - Editor

    private var editor: some View {
        VStack(spacing: 0) {
            if draft.isBuiltIn {
                banner
            }

            Form {
                Section("Config") {
                    TextField("Name", text: $draft.name)
                    TextField("Author", text: $draft.author)
                    TextField("Notes", text: $draft.notes)
                }

                Section("Buttons") {
                    buttonTree
                    controls
                }

                if let path = selection, let option = binding(for: path) {
                    ButtonDetailView(option: option, supportsShell: model.supportsShellActions)
                }
            }
            .formStyle(.grouped)
            .disabled(draft.isBuiltIn)

            Divider()

            HStack {
                if let failure {
                    Text(failure).font(.caption).foregroundStyle(.red)
                } else if draft.isBuiltIn {
                    Text("Duplicate this config to edit it.")
                        .font(.caption).foregroundStyle(.secondary)
                } else if isDirty {
                    Text("Unsaved changes").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Revert") { loadDraft() }
                    .disabled(!isDirty)
                Button("Save") { save() }
                    .keyboardShortcut("s")
                    .disabled(draft.isBuiltIn || !isDirty)
            }
            .padding(12)
        }
    }

    private var banner: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
            Text("“\(draft.name)” ships with the app and cannot be edited.")
            Spacer()
            Button("Duplicate") { duplicate() }
                .controlSize(.small)
        }
        .font(.callout)
        .padding(10)
        .background(.quaternary)
    }

    private var buttonTree: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(draft.groups.enumerated()), id: \.element.id) { groupIndex, group in
                Text(group.title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, groupIndex == 0 ? 0 : 8)

                ForEach(Array(group.commands.enumerated()), id: \.element.id) {
                    commandIndex, command in
                    Label(command.title, systemImage: command.icon)
                        .font(.callout)
                        .padding(.leading, 6)
                        .padding(.top, 4)

                    ForEach(Array(command.options.enumerated()), id: \.element.id) {
                        optionIndex, option in
                        let path = ButtonPath(
                            group: groupIndex, command: commandIndex, option: optionIndex)
                        Button {
                            selection = path
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: option.icon)
                                    .frame(width: 16)
                                Text(option.title)
                                Spacer()
                                Text(Self.actionLabel(option.action))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 3)
                            .padding(.horizontal, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                selection == path ? Color.accentColor.opacity(0.18) : .clear,
                                in: RoundedRectangle(cornerRadius: 5)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 20)
                    }
                }
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 6) {
            Button("Add Group") { addGroup() }
            Button("Add Command") { addCommand() }
                .disabled(draft.groups.isEmpty)
            Button("Add Button") { addButton() }
                .disabled(selection == nil && draft.allCommands.isEmpty)

            Spacer()

            Button {
                move(-1)
            } label: {
                Image(systemName: "arrow.up")
            }
            .disabled(selection == nil)
            Button {
                move(1)
            } label: {
                Image(systemName: "arrow.down")
            }
            .disabled(selection == nil)
            Button(role: .destructive) {
                removeSelected()
            } label: {
                Image(systemName: "trash")
            }
            .disabled(selection == nil)
        }
        .controlSize(.small)
    }

    // MARK: - Draft handling

    private func loadDraft() {
        draft = model.configs.current
        baseline = draft
        selection = draft.groups.isEmpty ? nil : ButtonPath(group: 0, command: 0, option: 0)
        failure = nil
    }

    private func save() {
        do {
            try model.configs.save(draft)
            model.configs.selectedID = draft.id
            baseline = draft
            failure = nil
        } catch {
            failure = error.localizedDescription
        }
    }

    private func duplicate() {
        do {
            let copy = try model.configs.duplicate(model.configs.current)
            model.configs.selectedID = copy.id
            failure = nil
        } catch {
            failure = error.localizedDescription
        }
    }

    private func delete() {
        do {
            try model.configs.delete(model.configs.current)
            failure = nil
        } catch {
            failure = error.localizedDescription
        }
    }

    private func importConfig() {
        let panel = NSOpenPanel()
        panel.title = "Import Config"
        panel.prompt = "Import"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a .mccconfig folder or a config .json file."

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try model.configs.importConfig(from: url)
            failure = nil
        } catch {
            failure = error.localizedDescription
        }
    }

    // MARK: - Structure editing

    private func binding(for path: ButtonPath) -> Binding<ConfigOption>? {
        guard draft.groups.indices.contains(path.group),
            draft.groups[path.group].commands.indices.contains(path.command),
            draft.groups[path.group].commands[path.command].options.indices.contains(path.option)
        else { return nil }
        return $draft.groups[path.group].commands[path.command].options[path.option]
    }

    private func addGroup() {
        let id = "group-\(draft.groups.count + 1)"
        draft.groups.append(ConfigGroup(id: id, title: "New Group", commands: []))
    }

    private func addCommand() {
        let groupIndex = selection?.group ?? draft.groups.count - 1
        guard draft.groups.indices.contains(groupIndex) else { return }
        let command = ConfigCommand(
            id: "command-\(UUID().uuidString.prefix(6))",
            title: "New Command",
            icon: "square.grid.2x2",
            options: [newOption()]
        )
        draft.groups[groupIndex].commands.append(command)
        selection = ButtonPath(
            group: groupIndex,
            command: draft.groups[groupIndex].commands.count - 1,
            option: 0
        )
    }

    private func addButton() {
        guard let path = selection,
            draft.groups.indices.contains(path.group),
            draft.groups[path.group].commands.indices.contains(path.command)
        else { return }
        draft.groups[path.group].commands[path.command].options.append(newOption())
        selection = ButtonPath(
            group: path.group,
            command: path.command,
            option: draft.groups[path.group].commands[path.command].options.count - 1
        )
    }

    private func newOption() -> ConfigOption {
        ConfigOption(
            id: "button-\(UUID().uuidString.prefix(6))",
            title: "New Button",
            subtitle: "",
            icon: "circle",
            action: .keepAwake(mode: .systemOnly)
        )
    }

    private func removeSelected() {
        guard let path = selection,
            draft.groups.indices.contains(path.group),
            draft.groups[path.group].commands.indices.contains(path.command)
        else { return }

        var options = draft.groups[path.group].commands[path.command].options
        guard options.indices.contains(path.option) else { return }
        options.remove(at: path.option)

        if options.isEmpty {
            draft.groups[path.group].commands.remove(at: path.command)
            if draft.groups[path.group].commands.isEmpty {
                draft.groups.remove(at: path.group)
            }
            selection = nil
        } else {
            draft.groups[path.group].commands[path.command].options = options
            selection = ButtonPath(
                group: path.group,
                command: path.command,
                option: min(path.option, options.count - 1)
            )
        }
    }

    private func move(_ offset: Int) {
        guard let path = selection,
            draft.groups.indices.contains(path.group),
            draft.groups[path.group].commands.indices.contains(path.command)
        else { return }

        var options = draft.groups[path.group].commands[path.command].options
        let target = path.option + offset
        guard options.indices.contains(path.option), options.indices.contains(target) else {
            return
        }
        options.swapAt(path.option, target)
        draft.groups[path.group].commands[path.command].options = options
        selection = ButtonPath(group: path.group, command: path.command, option: target)
    }

    static func actionLabel(_ action: ActionSpec) -> String {
        switch action {
        case .keepAwake: return "Keep awake"
        case .openURL: return "Open URL"
        case .shell: return "Run command"
        case .unavailable: return "Unavailable"
        }
    }
}

struct ButtonPath: Hashable {
    let group: Int
    let command: Int
    let option: Int
}

private struct Badge: View {
    let text: String
    var tint: Color = .secondary

    init(_ text: String, tint: Color = .secondary) {
        self.text = text
        self.tint = tint
    }

    var body: some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(tint)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(tint.opacity(0.15), in: Capsule())
    }
}
