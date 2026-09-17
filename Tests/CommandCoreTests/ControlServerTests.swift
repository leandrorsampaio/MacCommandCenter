import Foundation
import Testing

@testable import CommandCore

@MainActor
private final class EchoCommand: CommandHandling {
    var stateDidChange: (() -> Void)?
    private var active: String?

    let descriptor = CommandDescriptor(
        id: "keep-awake",
        title: "Keep Awake",
        summary: "",
        systemImage: "circle",
        kind: .mode,
        group: "Power",
        options: [CommandOption(id: "display-off", title: "Display Off", systemImage: "moon")]
    )

    var state: CommandState { CommandState(activeOptionID: active, detail: active ?? "off") }

    func handle(_ request: CommandRequest) throws {
        switch request {
        case .activate(let id), .toggle(let id): active = id
        case .deactivate: active = nil
        }
    }
}

/// Serialised: these bind a real socket, so they cannot run in parallel with each other.
@MainActor
@Suite(.serialized)
struct ControlServerTests {

    /// A fresh port per test. A fixed one collided with sockets left over from the
    /// previous `swift test` process, which made this suite intermittently fail.
    private func freePort() -> UInt16 {
        UInt16.random(in: 20000...60000)
    }

    private func makeServer(port: UInt16) -> (CommandCenter, ControlServer) {
        let center = CommandCenter()
        center.register(EchoCommand())
        return (center, ControlServer(center: center, port: port))
    }

    private func get(
        _ path: String,
        port: UInt16,
        clientHeader: Bool = true,
        origin: String? = nil
    ) async throws -> (Int, String) {
        let url = URL(string: "http://127.0.0.1:\(port)\(path)")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        if clientHeader {
            request.setValue("1", forHTTPHeaderField: ControlServer.clientHeaderName)
        }
        if let origin {
            request.setValue(origin, forHTTPHeaderField: "Origin")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return (status, String(data: data, encoding: .utf8) ?? "")
    }

    /// Polls rather than sleeping a fixed amount: NWListener becomes ready asynchronously.
    private func waitUntilRunning(_ server: ControlServer) async throws {
        // Generous: a cold binary on a CI runner takes noticeably longer to bind than a
        // warm local one, and a slow bind is not a failure.
        for _ in 0..<100 {
            if server.isRunning { return }
            try await Task.sleep(for: .milliseconds(100))
        }
        Issue.record("server never became ready: \(server.lastError ?? "no error reported")")
    }

    @Test func servesStateAndPerformsCommands() async throws {
        let port = freePort()
        let (center, server) = makeServer(port: port)
        server.start()
        defer { server.stop() }
        try await waitUntilRunning(server)

        let (statusCode, body) = try await get("/v1/state", port: port)
        #expect(statusCode == 200)
        #expect(body.contains("keep-awake"))

        let (activateStatus, _) = try await get(
            "/v1/commands/keep-awake/activate?option=display-off", port: port)
        #expect(activateStatus == 200)
        #expect(center.state(for: "keep-awake").activeOptionID == "display-off")

        let (offStatus, _) = try await get("/v1/commands/keep-awake/deactivate", port: port)
        #expect(offStatus == 200)
        #expect(center.state(for: "keep-awake").isActive == false)
    }

    /// A web page can reach loopback with a simple cross-origin request, so anything
    /// that changes state has to require something a browser cannot send.
    @Test func mutationsRequireTheClientHeaderAndNoOrigin() async throws {
        let port = freePort()
        let (center, server) = makeServer(port: port)
        server.start()
        defer { server.stop() }
        try await waitUntilRunning(server)

        let route = "/v1/commands/keep-awake/activate?option=display-off"

        let (noHeader, _) = try await get(route, port: port, clientHeader: false)
        #expect(noHeader == 403)
        #expect(center.state(for: "keep-awake").isActive == false)

        let (withOrigin, _) = try await get(route, port: port, origin: "https://evil.example")
        #expect(withOrigin == 403)
        #expect(center.state(for: "keep-awake").isActive == false)

        // Reading stays open: it changes nothing.
        let (readOnly, _) = try await get("/v1/state", port: port, clientHeader: false)
        #expect(readOnly == 200)
    }

    @Test func reportsUnknownRoutesAndOptions() async throws {
        let port = freePort()
        let (_, server) = makeServer(port: port)
        server.start()
        defer { server.stop() }
        try await waitUntilRunning(server)

        let (missingRoute, _) = try await get("/v1/nope", port: port)
        #expect(missingRoute == 404)

        let (missingOption, body) = try await get("/v1/commands/keep-awake/activate", port: port)
        #expect(missingOption == 400)
        #expect(body.contains("option"))
    }

    /// Guards the connection cap: sessions used to be kept alive only by their own
    /// receive closure, so a leak would silently fill the table and stop the server
    /// answering after a while.
    @Test func keepsAnsweringAfterManyConnections() async throws {
        let port = freePort()
        let (_, server) = makeServer(port: port)
        server.start()
        defer { server.stop() }
        try await waitUntilRunning(server)

        for _ in 0..<40 {
            let (status, _) = try await get("/v1/state", port: port)
            #expect(status == 200)
        }
    }

    @Test func stoppingReleasesThePort() async throws {
        let port = freePort()
        let (_, first) = makeServer(port: port)
        first.start()
        try await waitUntilRunning(first)
        first.stop()

        // Cancellation is asynchronous, so rebinding the same port immediately races it.
        for _ in 0..<50 where first.isRunning {
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(!first.isRunning)

        let (_, second) = makeServer(port: port)
        second.start()
        defer { second.stop() }
        try await waitUntilRunning(second)

        #expect(second.isRunning)
    }
}
