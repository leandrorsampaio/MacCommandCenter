import Foundation
import Network

/// A parsed request. Only the parts a control API needs — this is not a web server.
public struct HTTPRequest: Sendable {
    public let method: String
    public let path: String
    /// The path split on `/` and *then* percent-decoded, so an id containing an escaped
    /// slash stays one segment instead of silently becoming two.
    public let pathSegments: [String]
    public let query: [String: String]
    public let headers: [String: String]
    public let body: Data
}

public struct HTTPResponse: Sendable {
    public var status: Int
    public var contentType: String
    public var body: Data

    public init(status: Int = 200, contentType: String = "application/json", body: Data = Data()) {
        self.status = status
        self.contentType = contentType
        self.body = body
    }

    public static func json<T: Encodable>(_ value: T, status: Int = 200) -> HTTPResponse {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data =
            (try? encoder.encode(value)) ?? Data(#"{"ok":false,"error":"encoding failed"}"#.utf8)
        return HTTPResponse(status: status, contentType: "application/json", body: data)
    }

    public static func text(_ string: String, status: Int = 200) -> HTTPResponse {
        HTTPResponse(
            status: status, contentType: "text/plain; charset=utf-8", body: Data(string.utf8))
    }

    public static func failure(_ message: String, status: Int) -> HTTPResponse {
        struct Failure: Encodable { let ok = false; let error: String }
        return .json(Failure(error: message), status: status)
    }

    var wireFormat: Data {
        let reason = HTTPURLResponse.localizedString(forStatusCode: status)
        var head = "HTTP/1.1 \(status) \(reason)\r\n"
        head += "Content-Type: \(contentType)\r\n"
        head += "Content-Length: \(body.count)\r\n"
        head += "Cache-Control: no-store\r\n"
        head += "Connection: close\r\n\r\n"
        return Data(head.utf8) + body
    }
}

/// One request/response exchange over a single connection. Reads until the headers (and
/// any declared body) are complete, hands the request to `handler`, writes the reply and
/// closes.
final class HTTPSession {

    private let connection: NWConnection
    private let handler: @Sendable (HTTPRequest) -> HTTPResponse
    private var buffer = Data()
    private static let maximumRequestSize = 64 * 1024

    init(connection: NWConnection, handler: @escaping @Sendable (HTTPRequest) -> HTTPResponse) {
        self.connection = connection
        self.handler = handler
    }

    func start() {
        connection.start(queue: .main)
        receive()
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) {
            data, _, isComplete, error in
            if let data, !data.isEmpty {
                self.buffer.append(data)
            }

            if self.buffer.count > Self.maximumRequestSize {
                self.finish(with: .failure("Request too large.", status: 413))
                return
            }

            if let request = Self.parse(self.buffer) {
                self.finish(with: self.handler(request))
                return
            }

            if error != nil || isComplete {
                self.connection.cancel()
                return
            }

            self.receive()
        }
    }

    private func finish(with response: HTTPResponse) {
        connection.send(
            content: response.wireFormat,
            completion: .contentProcessed { _ in
                self.connection.cancel()
            })
    }

    // MARK: - Parsing

    private static let headerTerminator = Data("\r\n\r\n".utf8)

    /// Returns `nil` while the request is still incomplete.
    static func parse(_ data: Data) -> HTTPRequest? {
        guard let headerEnd = data.range(of: headerTerminator) else { return nil }

        let headerData = data[data.startIndex..<headerEnd.lowerBound]
        guard let headerText = String(data: headerData, encoding: .utf8) else { return nil }

        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }

        let parts = requestLine.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
        guard parts.count >= 2 else { return nil }

        let method = String(parts[0]).uppercased()
        let target = String(parts[1])

        var contentLength = 0
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            let pieces = line.split(separator: ":", maxSplits: 1)
            guard pieces.count == 2 else { continue }
            headers[pieces[0].trimmingCharacters(in: .whitespaces).lowercased()] =
                pieces[1].trimmingCharacters(in: .whitespaces)
            if pieces[0].trimmingCharacters(in: .whitespaces).lowercased() == "content-length" {
                // A negative value walked the body index off the front of the buffer and
                // trapped; an absurd one would wait forever. Both are just malformed.
                let declared = Int(pieces[1].trimmingCharacters(in: .whitespaces)) ?? 0
                contentLength = min(max(declared, 0), maximumRequestSize)
            }
        }

        let bodyStart = headerEnd.upperBound
        let available = data.distance(from: bodyStart, to: data.endIndex)
        guard available >= contentLength else { return nil }

        let body = Data(data[bodyStart..<data.index(bodyStart, offsetBy: contentLength)])

        let (path, segments, query) = splitTarget(target)
        return HTTPRequest(
            method: method,
            path: path,
            pathSegments: segments,
            query: query,
            headers: headers,
            body: body
        )
    }

    private static func splitTarget(
        _ target: String
    )
        -> (path: String, segments: [String], query: [String: String])
    {
        let rawPath: String
        let queryString: String
        if let separator = target.firstIndex(of: "?") {
            rawPath = String(target[target.startIndex..<separator])
            queryString = String(target[target.index(after: separator)...])
        } else {
            rawPath = target
            queryString = ""
        }

        // Segments are decoded individually. `+` means a literal plus in a path; only a
        // query value spells a space that way.
        let segments = rawPath.split(separator: "/").map {
            percentDecoded(String($0), plusIsSpace: false)
        }

        var query: [String: String] = [:]
        for pair in queryString.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1)
            guard let key = kv.first else { continue }
            query[percentDecoded(String(key), plusIsSpace: true)] =
                kv.count > 1 ? percentDecoded(String(kv[1]), plusIsSpace: true) : ""
        }

        return (percentDecoded(rawPath, plusIsSpace: false), segments, query)
    }

    private static func percentDecoded(_ string: String, plusIsSpace: Bool) -> String {
        let prepared = plusIsSpace ? string.replacingOccurrences(of: "+", with: " ") : string
        return prepared.removingPercentEncoding ?? prepared
    }
}
