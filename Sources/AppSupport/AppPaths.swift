import Foundation

/// Where the app keeps user content.
///
/// Sandbox-aware by construction: `FileManager` already returns the container path when
/// the app is sandboxed, so the same code serves the App Store build and the direct one.
/// Only the path the user sees differs, which is why Settings offers an **Import…** button
/// rather than telling anyone to go find a folder.
public enum AppPaths {

    public static let folderName = "MacCommandCenter"

    public static var isSandboxed: Bool {
        ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }

    public static var applicationSupport: URL {
        let base =
            FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(
                "Library/Application Support")

        // Sandboxed containers are already app-specific; nesting again would be noise.
        return isSandboxed ? base : base.appendingPathComponent(folderName, isDirectory: true)
    }

    public static var skins: URL {
        applicationSupport.appendingPathComponent("Skins", isDirectory: true)
    }

    public static var configs: URL {
        applicationSupport.appendingPathComponent("Configs", isDirectory: true)
    }

    @discardableResult
    public static func ensure(_ url: URL) -> URL {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
