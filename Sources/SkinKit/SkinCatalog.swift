import AppKit
import AppSupport
import Observation
import SwiftUI

/// Finds, loads and watches skins.
///
/// Skins come from two places: the ones shipped inside the app bundle, and the ones a
/// user drops into `~/Library/Application Support/MacCommandCenter/Skins`. The user
/// folder is watched, so saving a `skin.json` re-skins the panel live — that is the whole
/// point of the format.
@MainActor
@Observable
public final class SkinCatalog {

    public private(set) var skins: [Skin] = [.classic]
    /// Human-readable load failures, surfaced in the UI so skin authors see their typos.
    public private(set) var problems: [String] = []

    public var selectedID: String {
        didSet { UserDefaults.standard.set(selectedID, forKey: Self.defaultsKey) }
    }

    public var current: Skin {
        skins.first { $0.id == selectedID } ?? skins.first ?? .classic
    }

    private static let defaultsKey = "selectedSkinID"

    @ObservationIgnored private let watcher = DirectoryWatcher()

    public init() {
        selectedID = UserDefaults.standard.string(forKey: Self.defaultsKey) ?? Skin.classic.id
        installAuthoringKitIfNeeded()
        reload()
        watcher.start(watching: AppPaths.skins) { [weak self] in
            self?.reload()
        }
    }

    // MARK: - Locations

    public static var userSkinsDirectory: URL { AppPaths.skins }

    private static var bundledSkinsDirectory: URL? {
        Bundle.main.resourceURL?.appendingPathComponent("Skins", isDirectory: true)
    }

    // MARK: - Loading

    struct LoadFailure: Error { let message: String }

    public func reload() {
        var loaded: [Skin] = [.classic]
        var failures: [String] = []

        for (directory, isBuiltIn) in [
            (Self.bundledSkinsDirectory, true), (Self.userSkinsDirectory, false),
        ] {
            guard let directory else { continue }
            for manifestURL in Self.manifestURLs(in: directory) {
                switch Self.loadSkin(at: manifestURL, isBuiltIn: isBuiltIn) {
                case .success(let skin):
                    // A later skin with the same id replaces an earlier one, so a user
                    // skin can override a bundled one by reusing its id.
                    loaded.removeAll { $0.id == skin.id }
                    loaded.append(skin)
                case .failure(let failure):
                    failures.append(failure.message)
                }
            }
        }

        skins = loaded.sorted { lhs, rhs in
            if lhs.isBuiltIn != rhs.isBuiltIn { return lhs.isBuiltIn && !rhs.isBuiltIn }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        problems = failures

        if !skins.contains(where: { $0.id == selectedID }) {
            selectedID = skins.first?.id ?? Skin.classic.id
        }
    }

    /// Accepts `Name.mccskin/skin.json`, `Name/skin.json` and a bare `Name.json`.
    nonisolated private static func manifestURLs(in directory: URL) -> [URL] {
        let fileManager = FileManager.default
        guard
            let entries = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        else { return [] }

        var results: [URL] = []
        for entry in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            // Resolve first: a symlink reports isDirectory == false and would be skipped,
            // quietly ignoring a folder someone linked in on purpose.
            let resolved = entry.resolvingSymlinksInPath()
            let isDirectory =
                (try? resolved.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDirectory {
                let manifest = entry.appendingPathComponent("skin.json")
                if fileManager.fileExists(atPath: manifest.path) { results.append(manifest) }
            } else if entry.pathExtension.lowercased() == "json" {
                results.append(entry)
            }
        }
        return results
    }

    nonisolated private static func loadSkin(
        at url: URL, isBuiltIn: Bool
    ) -> Result<Skin, LoadFailure> {
        let name =
            url.lastPathComponent == "skin.json"
            ? url.deletingLastPathComponent().deletingPathExtension().lastPathComponent
            : url.deletingPathExtension().lastPathComponent

        guard let data = try? Data(contentsOf: url) else {
            return .failure(LoadFailure(message: "\(name): could not be read."))
        }

        do {
            let manifest = try JSONDecoder().decode(SkinManifest.self, from: data)
            let folder =
                url.lastPathComponent == "skin.json" ? url.deletingLastPathComponent() : nil
            let identifier =
                manifest.id ?? name.lowercased().replacingOccurrences(of: " ", with: "-")
            var skin = Skin(
                manifest: manifest,
                base: .classic,
                id: identifier,
                folderURL: folder,
                isBuiltIn: isBuiltIn
            )
            skin.sourceURL = folder ?? url
            return .success(skin)
        } catch let error as DecodingError {
            return .failure(LoadFailure(message: "\(name): \(Self.describe(error))"))
        } catch {
            return .failure(LoadFailure(message: "\(name): \(error.localizedDescription)"))
        }
    }

    nonisolated private static func describe(_ error: DecodingError) -> String {
        switch error {
        case .typeMismatch(_, let context), .valueNotFound(_, let context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return path.isEmpty ? context.debugDescription : "'\(path)' has the wrong type."
        case .keyNotFound(let key, _):
            return "missing '\(key.stringValue)'."
        case .dataCorrupted(let context):
            return context.debugDescription
        @unknown default:
            return "could not be parsed."
        }
    }

    // MARK: - Importing

    /// Copies a skin chosen by the user into the app's own folder. Under the sandbox this
    /// is the only way in, and it is friendlier than naming a container path.
    public func importSkin(from source: URL) throws {
        try AppPaths.importItem(from: source, into: AppPaths.skins)
        reload()
    }

    public func delete(_ skin: Skin) throws {
        // `folderURL` is nil for a bare `.json`, which used to make Delete a no-op.
        guard !skin.isBuiltIn, let target = skin.folderURL ?? skin.sourceURL else { return }
        try FileManager.default.trashItem(at: target, resultingItemURL: nil)
        reload()
    }

    // MARK: - Authoring

    public func revealUserSkinsFolder() {
        NSWorkspace.shared.selectFile(
            nil, inFileViewerRootedAtPath: AppPaths.ensure(AppPaths.skins).path)
    }

    /// On first run, seeds the skins folder with a README and a complete example, so
    /// anyone who opens it has a working starting point rather than an empty directory.
    public func installAuthoringKitIfNeeded() {
        let directory = AppPaths.skins
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: directory.path) else { return }

        AppPaths.ensure(directory)

        let readme = directory.appendingPathComponent("README.md")
        try? SkinAuthoring.readme.data(using: .utf8)?.write(to: readme)

        let example = directory.appendingPathComponent("Example.mccskin", isDirectory: true)
        try? fileManager.createDirectory(at: example, withIntermediateDirectories: true)
        try? SkinAuthoring.exampleManifest.data(using: .utf8)?
            .write(to: example.appendingPathComponent("skin.json"))
    }
}
