import Foundation
import Testing

@testable import CommandCore

struct HTTPRequestParsingTests {

    private func request(_ text: String) -> HTTPRequest? {
        HTTPSession.parse(Data(text.utf8))
    }

    @Test func parsesMethodAndPath() throws {
        let parsed = try #require(request("GET /v1/state HTTP/1.1\r\nHost: x\r\n\r\n"))
        #expect(parsed.method == "GET")
        #expect(parsed.path == "/v1/state")
        #expect(parsed.query.isEmpty)
    }

    @Test func parsesQueryParameters() throws {
        let parsed = try #require(
            request("POST /v1/commands/a/activate?option=display-off HTTP/1.1\r\n\r\n"))
        #expect(parsed.query["option"] == "display-off")
    }

    @Test func decodesPercentEscapes() throws {
        let parsed = try #require(request("GET /v1/x?option=a%20b HTTP/1.1\r\n\r\n"))
        #expect(parsed.query["option"] == "a b")
    }

    @Test func returnsNilUntilHeadersAreComplete() {
        #expect(request("GET /v1/state HTTP/1.1\r\nHost: x") == nil)
    }

    /// A declared body that has not arrived yet must not be parsed as complete.
    @Test func waitsForTheDeclaredBody() throws {
        #expect(request("POST /x HTTP/1.1\r\nContent-Length: 10\r\n\r\nshort") == nil)

        let parsed = try #require(request("POST /x HTTP/1.1\r\nContent-Length: 5\r\n\r\nhello"))
        #expect(String(data: parsed.body, encoding: .utf8) == "hello")
    }

    @Test func headerNamesAreCaseInsensitive() throws {
        let parsed = try #require(request("POST /x HTTP/1.1\r\ncontent-length: 2\r\n\r\nhi"))
        #expect(parsed.body.count == 2)
    }
}
