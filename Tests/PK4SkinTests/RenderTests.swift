import AppKit
import FakeSources
import Foundation
import SwiftUI
import Testing

@testable import ConsoleKit
@testable import PK4Skin
@testable import TelemetryKit

/// Renders the desk to PNG, to look at. Off unless a folder is given:
///
///     PK4_RENDER=/tmp/pk4 swift test --filter RenderTests
@MainActor
@Suite(.enabled(if: ProcessInfo.processInfo.environment["PK4_RENDER"] != nil))
struct RenderTests {

    static var folder: URL {
        URL(fileURLWithPath: ProcessInfo.processInfo.environment["PK4_RENDER"] ?? "/tmp")
    }

    /// The scripted day up to `hours`, through the real model.
    static func snapshot(atHour hours: Double, selector: Int = 1) -> ConsoleSnapshot {
        let clock = ManualClock()
        let model = ConsoleModel(clock: clock, store: MemoryConsoleStore(), log: MemoryConsoleLog())
        var day = FakeDay(start: clock.now)
        while day.elapsed < hours * 3600 {
            let readings = day.step()
            clock.now = day.now
            model.ingest(readings)
            model.advance()
        }
        for _ in 1..<selector { model.send(.selectorStep(1)) }
        clock.advance(by: 1)
        model.advance()
        return model.snapshot
    }

    static func render<V: View>(
        _ view: V, to name: String, scale: CGFloat, night: Bool = false
    ) throws {
        PK4Type.register()
        let content =
            view
            .environment(\.pk4, PK4Palette(night: night))
            .environment(\.colorScheme, night ? .dark : .light)
        let renderer = ImageRenderer(content: content)
        renderer.scale = scale
        let image = try #require(renderer.nsImage)
        let tiff = try #require(image.tiffRepresentation)
        let png = try #require(
            NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try png.write(to: folder.appendingPathComponent(name))
    }

    @Test func theDeskAtNineOhFive() throws {
        let snap = Self.snapshot(atHour: 1.1)
        let desk = PK4Desk(snapshot: snap).frame(width: 2500, height: 1800)
        try Self.render(desk, to: "desk-day.png", scale: 0.5)
        try Self.render(desk, to: "desk-night.png", scale: 0.5, night: true)
        try Self.render(desk, to: "desk-full.png", scale: 1)
    }

    @Test func theOtherStatesAndFinishes() throws {
        let clock = ManualClock()
        let model = ConsoleModel(clock: clock, store: MemoryConsoleStore(), log: MemoryConsoleLog())
        var day = FakeDay(start: clock.now)
        while day.elapsed < 1.1 * 3600 {
            let readings = day.step()
            clock.now = day.now
            model.ingest(readings)
            model.advance()
        }
        model.send(.press(PK4.lampTest))
        try Self.render(
            PK4Desk(snapshot: model.snapshot).frame(width: 2500, height: 1800), to: "lamp-test.png",
            scale: 0.4)
        model.send(.release(PK4.lampTest))

        model.setFinish(.graphite)
        try Self.render(
            PK4Desk(snapshot: model.snapshot).environment(\.pk4Finish, .graphite).frame(
                width: 2500, height: 1800), to: "graphite.png", scale: 0.4, night: true)
        model.setFinish(.ivory)
        try Self.render(
            PK4Desk(snapshot: model.snapshot).environment(\.pk4Finish, .ivory).frame(
                width: 2500, height: 1800), to: "ivory.png", scale: 0.4)

        model.send(.mains(false))
        try Self.render(
            PK4Desk(snapshot: model.snapshot).frame(width: 2500, height: 1800), to: "mains-off.png",
            scale: 0.4)
    }
}
