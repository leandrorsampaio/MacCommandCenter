import Foundation
import Network
import Observation

/// A deliberately tiny HTTP server bound to 127.0.0.1.
///
/// This is the seam for everything that isn't the menu bar: the `mcc` CLI today, and a
/// Stream Deck, a macro pad, Shortcuts, or a hand-built ESP32 button box later. Anything
/// that can make a local HTTP request can drive every registered command.
@MainActor
@Observable
public final class ControlServer {

    public nonisolated static let defaultPort: UInt16 = 8787

    /// Required on anything that changes state. See the guard in `respond`.
    public nonisolated static let clientHeaderName = "X-MCC-Client"
    nonisolated static let clientHeader = "x-mcc-client"

    public private(set) var isRunning = false
    public private(set) var lastError: String?
    public let port: UInt16

    @ObservationIgnored private var listener: NWListener?
    @ObservationIgnored private var sessions: [ObjectIdentifier: HTTPSession] = [:]

    /// A loopback control API needs no more than a handful at once; the cap keeps a
    /// misbehaving local client from opening sockets without limit.
    private static let maximumConcurrentConnections = 16
    // Held strongly: a server outliving its registry has nothing to serve, and
    // `CommandCenter` never refers back, so there is no cycle.
    @ObservationIgnored private let center: CommandCenter
    @ObservationIgnored private let signals: SignalCenter?

    public init(
        center: CommandCenter,
        signals: SignalCenter? = nil,
        port: UInt16 = ControlServer.defaultPort
    ) {
        self.center = center
        self.signals = signals
        self.port = port
    }

    // MARK: - Lifecycle

    public func start() {
        guard listener == nil else { return }
        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            // Loopback only: never reachable from the network.
            parameters.requiredLocalEndpoint = .hostPort(
                host: .ipv4(.loopback),
                port: NWEndpoint.Port(rawValue: port)!)

            let listener = try NWListener(using: parameters)
            listener.stateUpdateHandler = { state in
                MainActor.assumeIsolated {
                    switch state {
                    case .ready:
                        self.isRunning = true
                        self.lastError = nil
                    case .failed(let error):
                        self.isRunning = false
                        self.lastError = error.localizedDescription
                        self.stop()
                    case .cancelled:
                        self.isRunning = false
                    default:
                        break
                    }
                }
            }
            listener.newConnectionHandler = { connection in
                MainActor.assumeIsolated { self.accept(connection) }
            }
            listener.start(queue: .main)
            self.listener = listener
        } catch {
            lastError = error.localizedDescription
            isRunning = false
        }
    }

    public func stop() {
        for session in sessions.values {
            session.cancel()
        }
        sessions.removeAll()
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    public func setEnabled(_ enabled: Bool) {
        enabled ? start() : stop()
    }

    // MARK: - Connection handling

    private func accept(_ connection: NWConnection) {
        guard sessions.count < Self.maximumConcurrentConnections else {
            connection.cancel()
            return
        }

        let session = HTTPSession(connection: connection) { request in
            MainActor.assumeIsolated { self.respond(to: request) }
        }
        sessions[ObjectIdentifier(session)] = session
        session.onFinish = { [weak self] finished in
            MainActor.assumeIsolated { self?.sessions[ObjectIdentifier(finished)] = nil }
        }
        session.start()
    }

    // MARK: - Routing

    private func respond(to request: HTTPRequest) -> HTTPResponse {
        let segments = request.pathSegments

        switch segments {
        case []:
            return .text(Self.usageText(port: port))

        case ["v1", "state"], ["v1", "commands"]:
            return .json(stateSnapshot())

        case ["v1", "signals"]:
            guard let signals else { return .failure("Signals are not available.", status: 404) }
            return .json(signals.snapshot())

        // A hook reporting an event the file system cannot show: an agent finishing, or
        // Claude Code waiting on an answer. Same header guard as a command, because it
        // changes what the panel says.
        case let parts where parts.count == 3 && parts[0] == "v1" && parts[1] == "signals":
            guard let signals else { return .failure("Signals are not available.", status: 404) }
            guard let guardFailure = Self.mutationGuard(request) else {
                let id = parts[2]
                let query = request.query
                if query["clear"] == "1" {
                    signals.clear(id: id)
                } else {
                    signals.push(
                        id: id,
                        label: query["label"],
                        fraction: query["fraction"].flatMap(Double.init),
                        text: query["text"],
                        // Anything that reports at all is on unless it says otherwise:
                        // a hook firing is itself the event.
                        isActive: query["active"].map { $0 != "0" && $0 != "false" } ?? true,
                        ttl: query["ttl"].flatMap(Double.init)
                    )
                }
                return .json(signals.snapshot())
            }
            return guardFailure

        case let parts where parts.count == 4 && parts[0] == "v1" && parts[1] == "commands":
            let id = CommandID(parts[2])
            let verb = parts[3]
            let option = request.query["option"] ?? request.query["mode"]

            // A browser can send a cross-origin GET or simple POST to loopback without
            // CORS stopping the request — only the response is hidden. It cannot set a
            // custom header without a preflight, and no preflight is answered here, so
            // this keeps a web page from driving the API while costing a script or a
            // firmware client one extra line.
            if let failure = Self.mutationGuard(request) { return failure }

            let commandRequest: CommandRequest
            switch verb {
            case "activate":
                guard let option else {
                    return .failure("Missing '?option=' parameter.", status: 400)
                }
                commandRequest = .activate(optionID: option)
            case "toggle":
                guard let option else {
                    return .failure("Missing '?option=' parameter.", status: 400)
                }
                commandRequest = .toggle(optionID: option)
            case "deactivate", "off":
                commandRequest = .deactivate
            default:
                return .failure(
                    "Unknown verb '\(verb)'. Use activate, toggle or deactivate.", status: 404)
            }

            do {
                try center.perform(commandRequest, on: id)
                return .json(stateSnapshot())
            } catch {
                return .failure(error.localizedDescription, status: 400)
            }

        default:
            return .failure("No route for \(request.method) \(request.path).", status: 404)
        }
    }

    private func stateSnapshot() -> CommandSnapshot {
        var snapshot = center.snapshot()
        if let signals, !signals.signals.isEmpty { snapshot.signals = signals.snapshot() }
        return snapshot
    }

    /// A browser can send a cross-origin GET or simple POST to loopback without CORS
    /// stopping the request — only the response is hidden. It cannot set a custom header
    /// without a preflight, and no preflight is answered here, so this keeps a web page
    /// from driving the API while costing a script or a firmware client one extra line.
    private static func mutationGuard(_ request: HTTPRequest) -> HTTPResponse? {
        guard request.headers[clientHeader] != nil, request.headers["origin"] == nil else {
            return .failure(
                "Mutating requests must send the \(clientHeaderName) header and no Origin.",
                status: 403
            )
        }
        return nil
    }

    private static func usageText(port: UInt16) -> String {
        """
        Mac Command Center — local control API (127.0.0.1:\(port))

          GET  /v1/state
          GET  /v1/commands
          ANY  /v1/commands/{id}/activate?option={optionID}
          ANY  /v1/commands/{id}/toggle?option={optionID}
          ANY  /v1/commands/{id}/deactivate
          GET  /v1/signals
          ANY  /v1/signals/{id}?text=...&fraction=...&active=1&ttl=60

        Example:
          curl "http://127.0.0.1:\(port)/v1/commands/keep-awake/activate?option=display-off"

        """
    }
}
