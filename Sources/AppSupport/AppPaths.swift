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

    public enum ImportError: LocalizedError {
        case alreadyInPlace

        public var errorDescription: String? {
            switch self {
            case .alreadyInPlace: return "That item is already in this folder."
            }
        }
    }

    /// Copies a user-chosen file or folder into one of our folders.
    ///
    /// Staged first, then swapped: removing the destination up front meant a failed copy
    /// destroyed what was already there, and re-importing something already inside the
    /// folder deleted the very thing being imported.
    public static func importItem(from source: URL, into folder: URL) throws {
        let folder = ensure(folder)
        let destination = folder.appendingPathComponent(source.lastPathComponent)

        let resolvedSource = source.resolvingSymlinksInPath().standardizedFileURL
        guard resolvedSource != destination.resolvingSymlinksInPath().standardizedFileURL else {
            throw ImportError.alreadyInPlace
        }

        let fileManager = FileManager.default
        let staged = folder.appendingPathComponent(".importing-\(UUID().uuidString)")
        try fileManager.copyItem(at: source, to: staged)

        do {
            if fileManager.fileExists(atPath: destination.path) {
                _ = try fileManager.replaceItemAt(destination, withItemAt: staged)
            } else {
                try fileManager.moveItem(at: staged, to: destination)
            }
        } catch {
            try? fileManager.removeItem(at: staged)
            throw error
        }
    }

    @discardableResult
    public static func ensure(_ url: URL) -> URL {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
