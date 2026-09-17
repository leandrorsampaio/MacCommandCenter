import AppKit

// Plain AppKit entry point rather than a SwiftUI `App`.
//
// `MenuBarExtra` cannot be opened programmatically, which the global hotkey needs, and it
// draws system chrome that a custom panel skin would have to fight. Owning the
// NSStatusItem directly gives us both.

let application = NSApplication.shared

// Top-level code is nonisolated; the delegate is main-actor bound. It is held by this
// global so NSApplication's unowned `delegate` reference stays valid.
let delegate = MainActor.assumeIsolated { AppDelegate() }

application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
