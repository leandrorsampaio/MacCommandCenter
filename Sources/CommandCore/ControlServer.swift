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
    @ObservationIgnored private var connections: Set<ObjectIdentifier> = []
    // Held strongly: a server outliving its registry has nothing to serve, and
    // `CommandCenter` never refers back, so there is no cycle.
    @ObservationIgnored private let center: CommandCenter

    public init(center: CommandCenter, port: UInt16 = ControlServer.defaultPort) {
        self.center = center
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
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    public func setEnabled(_ enabled: Bool) {
        enabled ? start() : stop()
    }

    // MARK: - Connection handling

    private func accept(_ connection: NWConnection) {
        let session = HTTPSession(connection: connection) { request in
            MainActor.assumeIsolated { self.respond(to: request) }
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
            return .json(center.snapshot())

        case let parts where parts.count == 4 && parts[0] == "v1" && parts[1] == "commands":
            let id = CommandID(parts[2])
            let verb = parts[3]
            let option = request.query["option"] ?? request.query["mode"]

            // A browser can send a cross-origin GET or simple POST to loopback without
            // CORS stopping the request — only the response is hidden. It cannot set a
            // custom header without a preflight, and no preflight is answered here, so
            // this keeps a web page from driving the API while costing a script or a
            // firmware client one extra line.
            guard request.headers[Self.clientHeader] != nil, request.headers["origin"] == nil
            else {
                return .failure(
                    "Mutating requests must send the \(Self.clientHeaderName) header and no Origin.",
                    status: 403
                )
            }

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
                return .json(center.snapshot())
            } catch {
                return .failure(error.localizedDescription, status: 400)
            }

        default:
            return .failure("No route for \(request.method) \(request.path).", status: 404)
        }
    }

    private static func usageText(port: UInt16) -> String {
        """
        Mac Command Center — local control API (127.0.0.1:\(port))

          GET  /v1/state
          GET  /v1/commands
          ANY  /v1/commands/{id}/activate?option={optionID}
          ANY  /v1/commands/{id}/toggle?option={optionID}
          ANY  /v1/commands/{id}/deactivate

        Example:
          curl "http://127.0.0.1:\(port)/v1/commands/keep-awake/activate?option=display-off"

        """
    }
}
