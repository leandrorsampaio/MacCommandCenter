import Foundation
import Testing

@testable import AppSupport

/// Skins and configs are packages — `Foo.mccskin/skin.json` — and many editors save in
/// place rather than atomically. A vnode source on the parent directory sees neither, so
/// these guard the fingerprint backstop that does.
@MainActor
@Suite(.serialized)
struct DirectoryWatcherTests {

    private func makeTemporaryPackage() throws -> (root: URL, manifest: URL) {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("mcc-watch-\(UUID().uuidString)", isDirectory: true)
        let package = root.appendingPathComponent("Foo.mccskin", isDirectory: true)
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        let manifest = package.appendingPathComponent("skin.json")
        try Data(#"{"name":"Foo"}"#.utf8).write(to: manifest)
        return (root, manifest)
    }

    /// Waits for a change to be reported, polling rather than sleeping a fixed amount.
    private func awaitChange(
        _ fired: @escaping () -> Bool, within seconds: Double
    ) async throws -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if fired() { return true }
            try await Task.sleep(for: .milliseconds(150))
        }
        return fired()
    }

    @Test func noticesAnInPlaceEditInsideAPackage() async throws {
        let (root, manifest) = try makeTemporaryPackage()
        defer { try? FileManager.default.removeItem(at: root) }

        var changes = 0
        let watcher = DirectoryWatcher(debounce: 0.1, pollInterval: 0.4)
        watcher.start(watching: root) { changes += 1 }
        defer { watcher.stop() }

        // Write through an existing file handle: no rename, no directory entry change.
        let handle = try FileHandle(forWritingTo: manifest)
        try handle.truncate(atOffset: 0)
        try handle.write(contentsOf: Data(##"{"name":"Foo","colors":{"ledOn":"#FF0000"}}"##.utf8))
        try handle.close()

        #expect(try await awaitChange({ changes > 0 }, within: 4))
    }

    @Test func noticesAPackageBeingAdded() async throws {
        let (root, _) = try makeTemporaryPackage()
        defer { try? FileManager.default.removeItem(at: root) }

        var changes = 0
        let watcher = DirectoryWatcher(debounce: 0.1, pollInterval: 0.4)
        watcher.start(watching: root) { changes += 1 }
        defer { watcher.stop() }

        let added = root.appendingPathComponent("Bar.mccskin", isDirectory: true)
        try FileManager.default.createDirectory(at: added, withIntermediateDirectories: true)
        try Data(#"{"name":"Bar"}"#.utf8).write(to: added.appendingPathComponent("skin.json"))

        #expect(try await awaitChange({ changes > 0 }, within: 4))
    }

    /// An idle folder must never trigger a reload, or every tick rebuilds the registry.
    @Test func staysQuietWhenNothingChanges() async throws {
        let (root, _) = try makeTemporaryPackage()
        defer { try? FileManager.default.removeItem(at: root) }

        var changes = 0
        let watcher = DirectoryWatcher(debounce: 0.1, pollInterval: 0.3)
        watcher.start(watching: root) { changes += 1 }
        defer { watcher.stop() }

        try await Task.sleep(for: .seconds(1.5))

        #expect(changes == 0)
    }
}
