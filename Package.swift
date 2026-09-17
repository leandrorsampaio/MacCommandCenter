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
        .executable(name: "MacCommandCenter", targets: ["MacCommandCenterApp"]),
        .executable(name: "mcc", targets: ["mcc"]),
    ],
    targets: [
        .target(name: "AppSupport", swiftSettings: settings),
        .target(name: "CommandCore", swiftSettings: settings),
        .target(name: "SkinKit", dependencies: ["AppSupport"], swiftSettings: settings),
        .target(name: "ConfigKit", dependencies: ["AppSupport", "CommandCore"], swiftSettings: settings),
        .executableTarget(
            name: "MacCommandCenterApp",
            dependencies: ["CommandCore", "SkinKit", "ConfigKit"],
            swiftSettings: settings
        ),
        .executableTarget(name: "mcc", dependencies: ["CommandCore"], swiftSettings: settings),

        .testTarget(name: "AppSupportTests", dependencies: ["AppSupport"], swiftSettings: settings),
        .testTarget(name: "CommandCoreTests", dependencies: ["CommandCore"], swiftSettings: settings),
        .testTarget(name: "SkinKitTests", dependencies: ["SkinKit"], swiftSettings: settings),
        .testTarget(name: "ConfigKitTests", dependencies: ["ConfigKit", "CommandCore"], swiftSettings: settings),
    ]
)
