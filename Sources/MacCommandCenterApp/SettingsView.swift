import AppSupport
import ConfigKit
import ConsoleKit
import SwiftUI

struct SettingsView: View {

    let model: AppModel

    var body: some View {
        TabView {
            GeneralSettingsView(model: model)
                .tabItem { Label("General", systemImage: "gearshape") }

            SkinsSettingsView(model: model)
                .tabItem { Label("Skins", systemImage: "paintbrush") }

            ConfigsSettingsView(model: model)
                .tabItem { Label("Configs", systemImage: "square.grid.2x2") }

            ConsoleSettingsView(model: model)
                .tabItem { Label("Console", systemImage: "rectangle.3.group") }

            AdvancedSettingsView(model: model)
                .tabItem { Label("Advanced", systemImage: "slider.horizontal.3") }
        }
        .frame(minWidth: 680, minHeight: 460)
    }
}

// MARK: - General

struct GeneralSettingsView: View {

    let model: AppModel

    var body: some View {
        Form {
            Section {
                if model.isLaunchAtLoginSupported {
                    Toggle(
                        "Open at login",
                        isOn: Binding(
                            get: { model.launchesAtLogin },
                            set: { model.launchesAtLogin = $0 }
                        ))
                    if let error = model.launchAtLoginError {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                } else {
                    LabeledContent("Open at login") {
                        Text("Move the app to Applications first.")
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(
                    "Keep the panel above other windows",
                    isOn: Binding(
                        get: { model.floatsOnTop },
                        set: { model.floatsOnTop = $0 }
                    ))
            } header: {
                Text("Startup and windows")
            }

            Section {
                LabeledContent("Open the panel") {
                    Text(model.isHotKeyRegistered ? model.hotKeyDisplay : "Shortcut unavailable")
                        .monospaced()
                }
                LabeledContent("Switch modes") {
                    Text("1, 2, 3 … while the panel has focus").foregroundStyle(.secondary)
                }
            } header: {
                Text("Keyboard")
            }

            Section {
                LabeledContent("Build") {
                    Text(model.buildChannel)
                }
                LabeledContent("Sandboxed") {
                    Text(AppPaths.isSandboxed ? "Yes" : "No")
                }
                LabeledContent("Shell actions") {
                    Text(model.supportsShellActions ? "Available" : "Not in this build")
                        .foregroundStyle(model.supportsShellActions ? .primary : .secondary)
                }
            } header: {
                Text("About this build")
            } footer: {
                if !model.supportsShellActions {
                    Text(
                        "The App Store build is sandboxed, so configs cannot run shell commands. The direct download build can."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Advanced

struct AdvancedSettingsView: View {

    let model: AppModel
    @State private var confirmingRevokeAll = false

    var body: some View {
        Form {
            Section {
                Toggle(
                    "Enable the local control API",
                    isOn: Binding(
                        get: { model.isControlServerEnabled },
                        set: { model.isControlServerEnabled = $0 }
                    ))
                if model.server.isRunning {
                    LabeledContent("Listening on") {
                        // String(port), not interpolation: SwiftUI would group the digits
                        // by locale and render the port as "8.787".
                        Text("127.0.0.1:" + String(model.server.port)).monospaced()
                    }
                }
                if let error = model.server.lastError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            } header: {
                Text("Control API")
            } footer: {
                Text(
                    "Lets the mcc command, a Stream Deck, Shortcuts or a hardware button box drive the same commands. Loopback only — never reachable from the network. Off unless you need it."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section {
                if model.runtime.consent.approved.isEmpty {
                    Text("No commands approved yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(
                        model.runtime.consent.approved.sorted(by: { $0.value < $1.value }),
                        id: \.key
                    ) { entry in
                        HStack(alignment: .top) {
                            Text(entry.value)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button("Revoke") {
                                model.runtime.consent.revoke(fingerprint: entry.key)
                            }
                            .controlSize(.small)
                        }
                    }
                    Button("Revoke all", role: .destructive) {
                        confirmingRevokeAll = true
                    }
                    .confirmationDialog(
                        "Revoke every approved command?",
                        isPresented: $confirmingRevokeAll,
                        titleVisibility: .visible
                    ) {
                        Button("Revoke All", role: .destructive) {
                            model.runtime.consent.revokeAll()
                        }
                    }
                }
            } header: {
                Text("Approved shell commands")
            } footer: {
                Text(
                    "A shell button does nothing until you approve the exact command it runs. Editing a command asks again."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent("Skins and configs") {
                    Button("Open Folder") {
                        NSWorkspace.shared.selectFile(
                            nil,
                            inFileViewerRootedAtPath: AppPaths.ensure(AppPaths.applicationSupport)
                                .path
                        )
                    }
                }
            } header: {
                Text("Files")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Console

/// The PK-4 console's preferences. The finish and the buzzer belong to the desk and are
/// kept in its memory, so they can be changed only while it is running; sound, volume and
/// lamp codes belong to whoever is looking.
struct ConsoleSettingsView: View {

    let model: AppModel

    private var host: ConsoleHost { model.consoleHost }

    var body: some View {
        Form {
            Section {
                if let console = host.console {
                    Picker(
                        "Panel finish",
                        selection: Binding(
                            get: { console.model.snapshot.finish },
                            set: { console.model.setFinish($0) })
                    ) {
                        Text("Grey-green enamel").tag(Finish.greyGreen)
                        Text("Ivory enamel").tag(Finish.ivory)
                        Text("Matte graphite").tag(Finish.graphite)
                    }
                    Toggle(
                        "Buzzer muted",
                        isOn: Binding(
                            get: { console.model.buzzerMuted },
                            set: { console.model.setBuzzerMuted($0) }))
                    Text("A muted buzzer never mutes the flash.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    LabeledContent("The console is not running") {
                        Button("Open PK-4 Console") { model.requestConsole?() }
                    }
                    Text(
                        "Its finish and buzzer are kept with the desk, and change while it runs."
                    )
                    .font(.caption).foregroundStyle(.secondary)
                }
            } header: {
                Text("Desk")
            }

            Section {
                Toggle(
                    "Keep the console running when its window is closed",
                    isOn: Binding(get: { host.keepRunning }, set: { host.keepRunning = $0 }))
                Toggle(
                    "Play a scripted day instead of reading Claude Code",
                    isOn: Binding(get: { host.demo }, set: { host.demo = $0 }))
            } header: {
                Text("Running")
            } footer: {
                Text(
                    "Running behind a closed window, the drum counters and hours in service keep counting; it costs a fraction of a percent of one core. The scripted day keeps its own totals and log, and its buttons reach nothing outside the desk but Keep Awake."
                )
                .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                LabeledContent("Last hook event") {
                    if let last = host.lastHookEvent {
                        Text(last, style: .relative) + Text(" ago")
                    } else {
                        Text("None since the app started").foregroundStyle(.secondary)
                    }
                }
                if !model.isControlServerEnabled {
                    Label(
                        "The control API is off, so hook events have nowhere to arrive. Turn it on under Advanced.",
                        systemImage: "exclamationmark.triangle"
                    )
                    .foregroundStyle(.orange)
                }
            } header: {
                Text("Claude Code hooks")
            } footer: {
                Text(
                    "WAITING, TURN DONE and AGENT DONE are lit by hooks and nothing else. Without them the console still sees every session and its numbers. Install them with scripts/install-claude-hooks.sh --install."
                )
                .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                Toggle(
                    "Sound",
                    isOn: Binding(get: { model.consoleSound }, set: { model.consoleSound = $0 }))
                Slider(
                    value: Binding(get: { model.consoleVolume }, set: { model.consoleVolume = $0 }),
                    in: 0...1
                ) {
                    Text("Volume")
                }
                .disabled(!model.consoleSound)
                Toggle(
                    "Show designators on lamp windows",
                    isOn: Binding(
                        get: { model.consoleLampCodes }, set: { model.consoleLampCodes = $0 }))
                Toggle(
                    "Open the console when the app starts",
                    isOn: Binding(
                        get: { model.openConsoleAtLaunch }, set: { model.openConsoleAtLaunch = $0 })
                )
            } header: {
                Text("Viewing")
            } footer: {
                Text(
                    "Night lighting follows the Mac's appearance. Reduce Motion and Increase Contrast are honoured."
                )
            }
        }
        .formStyle(.grouped)
    }
}
