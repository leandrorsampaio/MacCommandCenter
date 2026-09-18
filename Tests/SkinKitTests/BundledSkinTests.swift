import Foundation
import Testing

@testable import SkinKit

/// The skins that ship with the app must load through the real decoder. A manifest that
/// fails to parse is dropped silently at runtime and the app falls back to Classic, which
/// looks like "the skin did nothing" rather than "the skin is broken".
@MainActor
struct BundledSkinTests {

    private var skinsDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // SkinKitTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("Skins", isDirectory: true)
    }

    @Test func everyBundledSkinParses() throws {
        let contents = try FileManager.default.contentsOfDirectory(
            at: skinsDirectory,
            includingPropertiesForKeys: nil
        )
        let manifests = contents
            .map { $0.appendingPathComponent("skin.json") }
            .filter { FileManager.default.fileExists(atPath: $0.path) }

        #expect(!manifests.isEmpty, "no bundled skins found at \(skinsDirectory.path)")

        for manifest in manifests {
            let name = manifest.deletingLastPathComponent().lastPathComponent
            let data = try Data(contentsOf: manifest)
            do {
                _ = try JSONDecoder().decode(SkinManifest.self, from: data)
            } catch {
                Issue.record("\(name) does not decode: \(error)")
            }
        }
    }

    /// Reactor Control is the worked example for layouts; if its layout stops parsing the
    /// app silently renders the default stack instead.
    @Test func reactorControlDeclaresAConsoleLayout() throws {
        let manifest = skinsDirectory
            .appendingPathComponent("Chernobyl.mccskin/skin.json")
        let data = try Data(contentsOf: manifest)
        let raw = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let layout = try #require(SkinLayout(json: raw["layout"]))

        func flatten(_ slots: [SkinSlot]) -> [SkinSlot] {
            slots.flatMap { slot -> [SkinSlot] in
                if case .row(let children) = slot { [slot] + flatten(children) } else { [slot] }
            }
        }
        let all = flatten(layout.rows)

        #expect(all.contains { if case .commands(.key, _) = $0 { true } else { false } })
        #expect(all.contains { if case .gauge = $0 { true } else { false } })
        #expect(all.contains { if case .controls = $0 { true } else { false } })
    }
}

struct NeedleJitterTests {

    /// The needle wander is a pure function of the tick, so it can be checked directly
    /// rather than by staring at screenshots.
    @Test func consecutiveTicksMostlyDiffer() {
        let values = (0..<200).map { SkinGauge.jitter(tick: $0) }
        let distinct = Set(values.map { Int($0 * 10_000) })

        #expect(distinct.count > 20, "only \(distinct.count) distinct values in 200 ticks")
    }

    @Test func staysWithinFivePointsOfFullScale() {
        for tick in 0..<500 {
            let value = SkinGauge.jitter(tick: tick)
            #expect(abs(value) <= 0.05 + 1e-9, "tick \(tick) produced \(value)")
        }
    }

    /// It should hold still a fair share of the time, or it reads as an animation.
    @Test func holdsStillSomeOfTheTime() {
        var holds = 0
        for tick in 1..<500 where SkinGauge.jitter(tick: tick) == SkinGauge.jitter(tick: tick - 1) {
            holds += 1
        }

        #expect(holds > 40, "only \(holds) holds in 500 ticks — too jumpy")
        #expect(holds < 300, "\(holds) holds in 500 ticks — barely moves")
    }
}
