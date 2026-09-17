import AppKit
import Carbon.HIToolbox

/// A system-wide keyboard shortcut.
///
/// Uses Carbon's `RegisterEventHotKey` rather than `NSEvent.addGlobalMonitorForEvents`
/// deliberately: the Carbon API needs no Accessibility permission, so the shortcut works
/// the moment the app launches instead of after a trip through System Settings.
@MainActor
final class GlobalHotKey {

    struct Shortcut {
        let keyCode: UInt32
        let carbonModifiers: UInt32
        let display: String

        /// Command-Shift-K.
        static let `default` = Shortcut(
            keyCode: UInt32(kVK_ANSI_K),
            carbonModifiers: UInt32(cmdKey | shiftKey),
            display: "\u{2318}\u{21E7}K"
        )
    }

    let shortcut: Shortcut

    /// The C event handler cannot capture context, so callbacks live here. Reached from
    /// the Carbon callback and from `deinit`, neither of which is main-actor isolated, so
    /// it is guarded rather than actor-bound.
    private final class Registry: @unchecked Sendable {
        private let lock = NSLock()
        private var handlers: [UInt32: @Sendable () -> Void] = [:]
        private var nextID: UInt32 = 1
        private var eventHandler: EventHandlerRef?

        func add(_ handler: @escaping @Sendable () -> Void) -> UInt32 {
            lock.lock()
            defer { lock.unlock() }
            let id = nextID
            nextID += 1
            handlers[id] = handler
            return id
        }

        func remove(_ id: UInt32) {
            lock.lock()
            defer { lock.unlock() }
            handlers[id] = nil
        }

        func handler(for id: UInt32) -> (@Sendable () -> Void)? {
            lock.lock()
            defer { lock.unlock() }
            return handlers[id]
        }

        /// Returns true the first time, so the shared Carbon handler is installed once.
        func claimEventHandlerInstall() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            return eventHandler == nil
        }

        func storeEventHandler(_ ref: EventHandlerRef?) {
            lock.lock()
            defer { lock.unlock() }
            eventHandler = ref
        }
    }

    nonisolated private static let registry = Registry()

    private let id: UInt32
    private var hotKeyRef: EventHotKeyRef?

    init?(shortcut: Shortcut, onFire: @escaping @MainActor () -> Void) {
        self.shortcut = shortcut
        // Carbon delivers hot keys on the main thread, but hopping explicitly keeps the
        // main-actor requirement visible instead of assumed.
        self.id = Self.registry.add {
            DispatchQueue.main.async { MainActor.assumeIsolated { onFire() } }
        }

        Self.installSharedEventHandlerIfNeeded()

        let hotKeyID = EventHotKeyID(signature: OSType(0x4D434358), id: id)  // 'MCCX'
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr else {
            Self.registry.remove(id)
            return nil
        }
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        GlobalHotKey.registry.remove(id)
    }

    private static func installSharedEventHandlerIfNeeded() {
        guard registry.claimEventHandlerInstall() else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        var installed: EventHandlerRef?

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ -> OSStatus in
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    UInt32(kEventParamDirectObject),
                    UInt32(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else { return status }

                let firedID = hotKeyID.id
                GlobalHotKey.registry.handler(for: firedID)?()
                return noErr
            },
            1,
            &eventType,
            nil,
            &installed
        )
        registry.storeEventHandler(installed)
    }
}
