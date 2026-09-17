import Foundation
import IOKit.ps
import IOKit.pwr_mgt

/// The two ways we can hold the Mac awake.
///
/// Both are *idle* assertions, which the power manager honours on battery as well as on
/// AC power — unlike `caffeinate -s`, which macOS only respects while plugged in.
public enum SleepAssertionKind: String, Codable, Sendable, CaseIterable {
    /// Mac stays awake and the display stays lit (also blocks the screen saver / idle lock).
    case systemAndDisplay
    /// Mac stays awake but the display is free to turn off.
    case systemOnly

    /// The raw IOKit assertion type string.
    var ioKitType: String {
        switch self {
        case .systemAndDisplay: return "PreventUserIdleDisplaySleep"
        case .systemOnly: return "PreventUserIdleSystemSleep"
        }
    }
}

/// Thin RAII wrapper around an IOKit power assertion.
///
/// The assertion is owned by this process, so it disappears automatically if the app
/// quits or crashes — the Mac can never get stuck awake.
public final class SleepAssertion {

    private var assertionID: IOPMAssertionID = IOPMAssertionID(0)
    public private(set) var held: SleepAssertionKind?

    public init() {}

    deinit {
        if held != nil {
            IOPMAssertionRelease(assertionID)
        }
    }

    /// Takes (or swaps to) an assertion of the given kind. Idempotent.
    public func hold(_ kind: SleepAssertionKind, reason: String) throws {
        if held == kind { return }
        release()

        var newID = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(
            kind.ioKitType as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &newID
        )

        guard result == kIOReturnSuccess else {
            throw CommandError.failed(
                "Could not take the power assertion (IOKit error 0x\(String(format: "%08x", result)))."
            )
        }

        assertionID = newID
        held = kind
    }

    public func release() {
        guard held != nil else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = IOPMAssertionID(0)
        held = nil
    }
}

/// Where the Mac is currently drawing power. Shown in the UI because "does this work on
/// battery?" is the first thing anyone asks about a keep-awake tool.
public enum PowerSource: String, Sendable {
    case ac = "Plugged in"
    case battery = "On battery"
    case unknown = "Unknown power source"

    public static var current: PowerSource {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        else { return .unknown }

        for source in sources {
            guard
                let info = IOPSGetPowerSourceDescription(blob, source)?
                    .takeUnretainedValue() as? [String: Any],
                let state = info[kIOPSPowerSourceStateKey] as? String
            else { continue }
            return state == kIOPSACPowerValue ? .ac : .battery
        }
        return .unknown
    }
}
