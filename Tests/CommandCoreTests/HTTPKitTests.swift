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

    /// An id containing an escaped slash must stay one segment, or its command becomes
    /// unreachable and the route silently matches something else.
    @Test func escapedSlashesStayInsideOneSegment() throws {
        let parsed = try #require(request("GET /v1/commands/a%2Fb/toggle HTTP/1.1\r\n\r\n"))
        #expect(parsed.pathSegments == ["v1", "commands", "a/b", "toggle"])
    }

    /// `+` is a literal plus in a path and a space only in a query value.
    @Test func plusMeansSpaceOnlyInQueryValues() throws {
        let parsed = try #require(
            request("GET /v1/commands/a+b/toggle?option=x+y HTTP/1.1\r\n\r\n"))
        #expect(parsed.pathSegments[2] == "a+b")
        #expect(parsed.query["option"] == "x y")
    }

    /// A negative length walked the body index off the front of the buffer and trapped.
    @Test func absurdContentLengthsAreClampedRatherThanTrapping() throws {
        let negative = try #require(request("POST /x HTTP/1.1\r\nContent-Length: -1\r\n\r\n"))
        #expect(negative.body.isEmpty)

        #expect(request("POST /x HTTP/1.1\r\nContent-Length: 99999999\r\n\r\n") == nil)
    }

    @Test func headersAreExposedLowercased() throws {
        let parsed = try #require(request("GET /x HTTP/1.1\r\nX-MCC-Client: 1\r\n\r\n"))
        #expect(parsed.headers["x-mcc-client"] == "1")
    }

    @Test func headerNamesAreCaseInsensitive() throws {
        let parsed = try #require(request("POST /x HTTP/1.1\r\ncontent-length: 2\r\n\r\nhi"))
        #expect(parsed.body.count == 2)
    }
}
