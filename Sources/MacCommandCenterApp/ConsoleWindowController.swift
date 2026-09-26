import AppKit
import ConsoleKit
import ConsoleRuntime
import PK4Skin
import SwiftUI

/// The PK-4 console's window.
///
/// The desk is one fixed drawing, so the window's content is locked to its aspect ratio and
/// never narrower than 1280 points; full screen on a second display is its intended home.
/// Closing the window closes only the window: the console goes on counting behind it,
/// unless Settings says otherwise. See `ConsoleHost`.
@MainActor
final class ConsoleWindowController: NSObject, NSWindowDelegate {

    private let model: AppModel
    private var window: NSWindow?
    private var sound: PK4Sound?
    private var director: PK4Director?
    private let log: ConsoleLogWindowController
    private let view = ConsoleViewState()
    private var trace: ConsoleTrace?

    init(model: AppModel) {
        self.model = model
        log = ConsoleLogWindowController(model: model)
        super.init()
    }

    var isOpen: Bool { window != nil }

    func show() {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        PK4Type.register()
        model.consoleHost.windowDidOpen()
        guard let console = model.consoleHost.console else { return }
        let sound = PK4Sound()
        self.sound = sound
        model.applyConsoleSoundSettings(to: sound)

        let director = PK4Director(sound: sound)
        director.announce = { words in
            // An alarm is announced as it is raised, so a VoiceOver user hears it.
            NSAccessibility.post(
                element: NSApp.mainWindow as Any, notification: .announcementRequested,
                userInfo: [
                    .announcement: words, .priority: NSAccessibilityPriorityLevel.high.rawValue,
                ])
        }
        director.openLog = { [weak self] in self?.log.show() }
        director.hear(console.model.snapshot)
        self.director = director
        if ProcessInfo.processInfo.environment["PK4_TRACE"] == "1" {
            trace = ConsoleTrace(folder: console.directory)
        }
        follow()

        let root = ConsoleRoot(model: model, sound: sound, view: view, trace: trace)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1600, height: 1152),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        let hosting = NSHostingView(rootView: root)
        // The window's size is the aspect lock's business; SwiftUI pushing sizes back into
        // it would only give the two something to argue about.
        hosting.sizingOptions = []
        window.contentView = hosting
        window.title = "PK-4 Console"
        let ratio = PK4ConsoleScreen.aspectRatio
        window.contentAspectRatio = NSSize(width: ratio.width, height: ratio.height)
        window.contentMinSize = NSSize(width: 1280, height: 1280 * ratio.height / ratio.width)
        window.collectionBehavior = [.fullScreenPrimary]
        window.backgroundColor = NSColor(
            red: 0x1A / 255, green: 0x1C / 255, blue: 0x1B / 255, alpha: 1)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setFrameAutosaveName("PK4Console")
        if !window.setFrameUsingName("PK4Console") { window.center() }

        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        // Nothing is focused until Tab is pressed: a ring on PRT the moment the window
        // opens looks like a fault.
        window.makeFirstResponder(nil)
    }

    func close() {
        window?.close()
    }

    /// The relays, the buzzer and the log window follow the model, not the view: a hidden
    /// console still sounds its alarms. Whichever console the host holds — switching to
    /// the scripted day swaps it.
    private func follow() {
        withObservationTracking {
            _ = model.consoleHost.console?.model.snapshot
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self, self.window != nil else { return }
                if let console = self.model.consoleHost.console {
                    self.director?.hear(console.model.snapshot)
                }
                self.trace?.snapshotChanged()
                self.follow()
            }
        }
    }

    /// A console nobody can see draws nothing: in another Space, minimised, or behind a
    /// full-screen app it costs no layout at all.
    func windowDidChangeOcclusionState(_ notification: Notification) {
        guard let window else { return }
        view.visible = window.occlusionState.contains(.visible)
    }

    func windowWillClose(_ notification: Notification) {
        sound?.stop()
        sound = nil
        director = nil
        trace = nil
        log.close()
        window = nil
        model.consoleHost.windowDidClose()
    }
}

@MainActor
@Observable
final class ConsoleViewState {
    var visible = true
}

/// Counts what the console does, every ten seconds, into `trace.log` beside its other
/// files. Only with `PK4_TRACE=1` in the environment: it exists to find out why a quiet
/// console is not quiet.
@MainActor
final class ConsoleTrace {
    private let url: URL
    private var snapshots = 0
    private var draws = 0
    private var timer: Timer?

    init(folder: URL) {
        url = folder.appendingPathComponent("trace.log")
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.flush() }
        }
    }

    func snapshotChanged() { snapshots += 1 }
    func drew() { draws += 1 }

    private func flush() {
        let line = "\(Date()) snapshots \(snapshots) draws \(draws)\n"
        snapshots = 0
        draws = 0
        if let handle = try? FileHandle(forWritingTo: url) {
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(line.utf8))
            try? handle.close()
        } else {
            FileManager.default.createFile(atPath: url.path, contents: Data(line.utf8))
        }
    }
}

/// Reads the console's snapshot, so the desk redraws when it changes and only then.
private struct ConsoleRoot: View {
    let model: AppModel
    let sound: PK4Sound
    let view: ConsoleViewState
    let trace: ConsoleTrace?

    var body: some View {
        let _ = trace?.drew()
        if let console = model.consoleHost.console, view.visible {
            PK4ConsoleScreen(
                snapshot: console.model.snapshot,
                send: { console.send($0) },
                sound: sound,
                lampCodes: model.consoleLampCodes)
        } else {
            Color(red: 0x1A / 255, green: 0x1C / 255, blue: 0x1B / 255)
        }
    }
}

/// The text log PRINT TEXT writes to, in an ordinary window: the console itself has no
/// way to show a string.
@MainActor
final class ConsoleLogWindowController: NSObject, NSWindowDelegate {

    private let model: AppModel
    private var window: NSWindow?
    private let text = LogText()

    init(model: AppModel) {
        self.model = model
        super.init()
    }

    func show() {
        text.value = model.consoleHost.console?.log.readText(lastCharacters: 200_000) ?? ""
        if let window {
            window.orderFront(nil)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
            styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered,
            defer: false)
        window.contentView = NSHostingView(rootView: LogView(text: text))
        window.title = "PK-4 Text Log"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setFrameAutosaveName("PK4TextLog")
        if !window.setFrameUsingName("PK4TextLog") { window.center() }
        self.window = window
        window.orderFront(nil)
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }

    @MainActor
    @Observable
    final class LogText {
        var value = ""
    }

    private struct LogView: View {
        let text: LogText

        var body: some View {
            ScrollViewReader { scroller in
                ScrollView {
                    Text(text.value.isEmpty ? "Nothing printed yet." : text.value)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                    Color.clear.frame(height: 1).id("end")
                }
                .onAppear { scroller.scrollTo("end", anchor: .bottom) }
                .onChange(of: text.value) { _, _ in scroller.scrollTo("end", anchor: .bottom) }
            }
        }
    }
}
