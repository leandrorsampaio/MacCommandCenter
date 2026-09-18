import Foundation

/// Something the panel *watches* rather than switches.
///
/// A command is a thing you press; a signal is a thing you read. Keeping them apart
/// matters: a command has an owner that can be asked to change state, a signal has a
/// source that reports it and nothing the panel can do about it.
///
/// One signal can drive a gauge, a readout line and a lamp at once — which of those a
/// skin binds to is the skin's business. A source fills in whichever fields it has.
public struct Signal: Codable, Sendable, Equatable, Identifiable {

    public let id: String
    /// What an instrument is captioned when the skin does not say.
    public var label: String
    /// 0…1, for a needle or a bar. `nil` when the reading has no magnitude.
    public var fraction: Double?
    /// The reading as a line of text, for a counter or a readout.
    public var text: String?
    /// Whether a lamp bound to this signal is lit. On a reading that means *alarm*, not
    /// *healthy*: a context gauge lights when the window is nearly full, the same way a
    /// panel lamp means "look at this" rather than "all is well".
    public var isActive: Bool
    public var updated: Date
    /// When a pushed signal stops being believed. A source that goes away should not
    /// leave a lamp on for the rest of the day.
    public var expires: Date?

    public init(
        id: String,
        label: String,
        fraction: Double? = nil,
        text: String? = nil,
        isActive: Bool = false,
        updated: Date = Date(),
        expires: Date? = nil
    ) {
        self.id = id
        self.label = label
        self.fraction = fraction.map { max(0, min(1, $0)) }
        self.text = text
        self.isActive = isActive
        self.updated = updated
        self.expires = expires
    }

    public func isFresh(at moment: Date = Date()) -> Bool {
        guard let expires else { return true }
        return moment < expires
    }

}

/// Something that reads signals off the machine.
///
/// `read()` runs off the main thread — a source that touches the file system must not
/// make the panel wait on a disk that is busy.
public protocol SignalSource: Sendable {
    var id: String { get }
    func read() -> [Signal]
}
