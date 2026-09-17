import AppKit
import CommandCore
import Foundation

// `mcc` — a thin client for the running Mac Command Center app.
//
// This exists so anything that can run a shell command can drive the same commands the
// menu bar shows: Shortcuts, Raycast, a Stream Deck, a key on a macro pad, or the
// firmware of a hand-built button box hitting the HTTP API directly.

// This binary lives inside the app bundle, so `Bundle.main` is the app itself — the
// identifier stays correct even when the bundle id changes at build time.
let bundleIdentifier =
    ProcessInfo.processInfo.environment["MCC_BUNDLE_ID"]
    ?? Bundle.main.bundleIdentifier
    ?? "com.leandrorossisampaio.MacCommandCenter"
let port =
    UInt16(ProcessInfo.processInfo.environment["MCC_PORT"] ?? "") ?? ControlServer.defaultPort

/// Everything unreserved in RFC 3986, and nothing else — so `/`, `+` and `%` all escape.
let pathSegmentAllowed = CharacterSet(
    charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

// MARK: - Transport

struct Reply {
    let status: Int
    let data: Data
}

func send(_ method: String, _ path: String) -> Reply? {
    guard let url = URL(string: "http://127.0.0.1:\(port)\(path)") else { return nil }
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.timeoutInterval = 3
    request.setValue("1", forHTTPHeaderField: ControlServer.clientHeaderName)

    var reply: Reply?
    let semaphore = DispatchSemaphore(value: 0)
    URLSession.shared.dataTask(with: request) { data, response, _ in
        if let http = response as? HTTPURLResponse {
            reply = Reply(status: http.statusCode, data: data ?? Data())
        }
        semaphore.signal()
    }.resume()
    _ = semaphore.wait(timeout: .now() + 6)
    return reply
}

/// Sends a request; if the app isn't running, launches it and retries.
func sendOrLaunch(_ method: String, _ path: String) -> Reply {
    if let reply = send(method, path) { return reply }

    // Only launch when nothing is running. `open` on a running instance toggles the
    // panel onto the screen, which is a surprising side effect of a failed status call.
    let alreadyRunning =
        !NSRunningApplication
        .runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty
    if alreadyRunning {
        fail(
            """
            Mac Command Center is running, but its control API is off.

            Turn it on in Settings > Advanced > Enable the local control API.
            """)
    }

    FileHandle.standardError.write(Data("Mac Command Center isn't running — launching it…\n".utf8))
    let launcher = Process()
    launcher.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    launcher.arguments = ["-g", "-b", bundleIdentifier]
    try? launcher.run()
    launcher.waitUntilExit()

    for _ in 0..<20 {
        if let reply = send(method, path) { return reply }
        Thread.sleep(forTimeInterval: 0.25)
    }

    fail(
        """
        Could not reach the app on 127.0.0.1:\(port).

        The control API is off by default. Turn it on in
        Settings > Advanced > Enable the local control API.
        """)
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func decode(_ reply: Reply) -> CommandSnapshot {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    if let snapshot = try? decoder.decode(CommandSnapshot.self, from: reply.data) {
        return snapshot
    }
    struct Failure: Decodable { let error: String }
    if let failure = try? decoder.decode(Failure.self, from: reply.data) {
        fail("Error: \(failure.error)")
    }
    fail("Unexpected reply from the app (HTTP \(reply.status)).")
}

// MARK: - Output

func printStatus(_ snapshot: CommandSnapshot) {
    for entry in snapshot.commands {
        let marker = entry.state.isActive ? "●" : "○"
        let active =
            entry.state.activeOptionID.map { id -> String in
                entry.descriptor.options.first { $0.id == id }?.title ?? id
            } ?? "off"
        print(
            "\(marker) \(entry.descriptor.title.padding(toLength: 16, withPad: " ", startingAt: 0)) \(active)"
        )
        print("  \(entry.state.detail)")
    }
    if let error = snapshot.error {
        print("! \(error)")
    }
}

func printList(_ snapshot: CommandSnapshot) {
    for entry in snapshot.commands {
        print("\(entry.descriptor.id)  — \(entry.descriptor.summary)")
        for option in entry.descriptor.options {
            let marker = entry.state.activeOptionID == option.id ? "*" : " "
            print(
                "  \(marker) \(option.id.padding(toLength: 14, withPad: " ", startingAt: 0)) \(option.title)"
            )
        }
    }
}

let usage = """
    mcc — Mac Command Center

      mcc                              show what's currently on
      mcc list                         list every command and its options
      mcc on <command> <option>        turn an option on
      mcc off <command>                turn a command off
      mcc toggle <command> <option>    flip an option

    Shortcut for the keep-awake command:

      mcc awake display-on             stay awake, screen stays lit
      mcc awake display-off            stay awake, screen may sleep
      mcc awake off                    back to normal sleep settings

    Environment:
      MCC_PORT   control API port (default \(ControlServer.defaultPort))
    """

// MARK: - Argument handling

let arguments = Array(CommandLine.arguments.dropFirst())

func invoke(command: String, verb: String, option: String?) -> Never {
    // A config may name a command in any language, and that name reaches us verbatim.
    // `.urlPathAllowed` leaves `/` and `+` alone, which the server would then read as a
    // separator and a space, so the set is narrowed here.
    let escaped =
        command.addingPercentEncoding(withAllowedCharacters: pathSegmentAllowed) ?? command
    var path = "/v1/commands/\(escaped)/\(verb)"
    if let option,
        let escaped = option.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
    {
        path += "?option=\(escaped)"
    }
    let reply = sendOrLaunch("POST", path)
    let snapshot = decode(reply)
    printStatus(snapshot)
    exit(reply.status == 200 ? 0 : 1)
}

switch arguments.first {
case nil, "status":
    printStatus(decode(sendOrLaunch("GET", "/v1/state")))

case "list":
    printList(decode(sendOrLaunch("GET", "/v1/state")))

case "help", "-h", "--help":
    print(usage)

case "awake":
    let mode = arguments.count > 1 ? arguments[1] : "display-off"
    if mode == "off" {
        invoke(command: "keep-awake", verb: "deactivate", option: nil)
    } else {
        invoke(command: "keep-awake", verb: "activate", option: mode)
    }

case "on", "toggle":
    guard arguments.count >= 3 else { fail(usage) }
    let verb = arguments[0] == "on" ? "activate" : "toggle"
    invoke(command: arguments[1], verb: verb, option: arguments[2])

case "off":
    guard arguments.count >= 2 else { fail(usage) }
    invoke(command: arguments[1], verb: "deactivate", option: nil)

default:
    fail(usage)
}
