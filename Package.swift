// swift-tools-version: 6.0
import PackageDescription

// The App Store build compiles without shell actions: the sandbox forbids them and
// review would reject them. Build it with `MCC_APP_STORE=1 swift build`.
let isAppStoreBuild = Context.environment["MCC_APP_STORE"] == "1"

var settings: [SwiftSetting] = [.swiftLanguageMode(.v5)]
if isAppStoreBuild {
    settings.append(.define("APP_STORE"))
}

let package = Package(
    name: "MacCommandCenter",
    platforms: [.macOS(.v14)],
    products: [
        // Shared plumbing: sandbox-aware paths, directory watching.
        .library(name: "AppSupport", targets: ["AppSupport"]),
        // Command registry and the actions commands can perform.
        .library(name: "CommandCore", targets: ["CommandCore"]),
        // Appearance: everything a skin can change.
        .library(name: "SkinKit", targets: ["SkinKit"]),
        // Behaviour: which buttons exist, what they say, what they do.
        .library(name: "ConfigKit", targets: ["ConfigKit"]),
        // What Claude Code and the Mac report, as typed readings. No UI, no instruments.
        .library(name: "TelemetryKit", targets: ["TelemetryKit"]),
        // The PK-4 console's rules: readings in, one value per instrument out. No UI.
        .library(name: "ConsoleKit", targets: ["ConsoleKit"]),
        // A scripted day of telemetry, so the console runs without Claude Code installed.
        .library(name: "FakeSources", targets: ["FakeSources"]),
        // The console's edge with the world: its files, its timer, its system commands.
        .library(name: "ConsoleRuntime", targets: ["ConsoleRuntime"]),
        // The PK-4 skin: the instruments, drawn to the design system, and their sounds.
        .library(name: "PK4Skin", targets: ["PK4Skin"]),
        .executable(name: "MacCommandCenter", targets: ["MacCommandCenterApp"]),
        .executable(name: "mcc", targets: ["mcc"]),
    ],
    targets: [
        .target(name: "AppSupport", swiftSettings: settings),
        .target(name: "CommandCore", swiftSettings: settings),
        .target(name: "SkinKit", dependencies: ["AppSupport"], swiftSettings: settings),
        .target(name: "ConfigKit", dependencies: ["AppSupport", "CommandCore"], swiftSettings: settings),
        .target(name: "TelemetryKit", swiftSettings: settings),
        .target(name: "ConsoleKit", dependencies: ["TelemetryKit"], swiftSettings: settings),
        .target(name: "FakeSources", dependencies: ["TelemetryKit"], swiftSettings: settings),
        .target(name: "PK4Skin", dependencies: ["ConsoleKit"], swiftSettings: settings),
        .target(
            name: "ConsoleRuntime",
            dependencies: ["ConsoleKit", "TelemetryKit", "AppSupport"],
            swiftSettings: settings
        ),
        .executableTarget(
            name: "MacCommandCenterApp",
            dependencies: [
                "CommandCore", "SkinKit", "ConfigKit", "TelemetryKit", "ConsoleKit",
                "ConsoleRuntime", "PK4Skin", "FakeSources",
            ],
            swiftSettings: settings
        ),
        .executableTarget(name: "mcc", dependencies: ["CommandCore"], swiftSettings: settings),

        .testTarget(name: "AppSupportTests", dependencies: ["AppSupport"], swiftSettings: settings),
        .testTarget(name: "CommandCoreTests", dependencies: ["CommandCore"], swiftSettings: settings),
        .testTarget(name: "SkinKitTests", dependencies: ["SkinKit"], swiftSettings: settings),
        .testTarget(name: "ConfigKitTests", dependencies: ["ConfigKit", "CommandCore"], swiftSettings: settings),
        .testTarget(name: "TelemetryKitTests", dependencies: ["TelemetryKit"], swiftSettings: settings),
        .testTarget(
            name: "PK4SkinTests",
            dependencies: ["PK4Skin", "ConsoleKit", "TelemetryKit", "FakeSources"],
            swiftSettings: settings
        ),
        .testTarget(
            name: "ConsoleRuntimeTests",
            dependencies: ["ConsoleRuntime", "ConsoleKit", "TelemetryKit"],
            swiftSettings: settings
        ),
        .testTarget(
            name: "ConsoleKitTests",
            dependencies: ["ConsoleKit", "TelemetryKit", "FakeSources", "CommandCore"],
            swiftSettings: settings
        ),
    ]
)
