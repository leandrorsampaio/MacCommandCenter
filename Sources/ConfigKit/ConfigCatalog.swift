import AppKit
import AppSupport
import Observation

/// Finds, loads and watches configs — the behaviour half of the app, mirroring
/// `SkinCatalog` on the appearance side.
@MainActor
@Observable
public final class ConfigCatalog {

    public private(set) var configs: [AppConfig] = [.standard]
    /// Human-readable load failures, shown in Settings so an author sees their typo.
    public private(set) var problems: [String] = []

    public var selectedID: String {
        didSet { UserDefaults.standard.set(selectedID, forKey: Self.defaultsKey) }
    }

    public var current: AppConfig {
        configs.first { $0.id == selectedID } ?? configs.first ?? .standard
    }

    private static let defaultsKey = "selectedConfigID"

    @ObservationIgnored private let watcher = DirectoryWatcher()

    public init() {
        selectedID = UserDefaults.standard.string(forKey: Self.defaultsKey) ?? AppConfig.standard.id
        installStarterConfigIfNeeded()
        reload()
        watcher.start(watching: AppPaths.configs) { [weak self] in
            self?.reload()
        }
    }

    // MARK: - Loading

    public func reload() {
        var loaded: [AppConfig] = [.standard]
        var failures: [String] = []

        let sources: [(URL?, Bool)] = [
            (Bundle.main.resourceURL?.appendingPathComponent("Configs", isDirectory: true), true),
            (AppPaths.configs, false),
        ]

        for (directory, isBuiltIn) in sources {
            guard let directory else { continue }
            for manifest in Self.manifestURLs(in: directory) {
                do {
                    let config = try Self.load(at: manifest, isBuiltIn: isBuiltIn)
                    failures.append(contentsOf: Self.duplicateIDProblems(in: config))
                    // A user config reusing a built-in id replaces it.
                    loaded.removeAll { $0.id == config.id }
                    loaded.append(config)
                } catch {
                    failures.append(
                        "\(manifest.deletingLastPathComponent().lastPathComponent): \(error.localizedDescription)"
                    )
                }
            }
        }

        configs = loaded.sorted { lhs, rhs in
            if lhs.isBuiltIn != rhs.isBuiltIn { return lhs.isBuiltIn && !rhs.isBuiltIn }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        problems = failures

        if !configs.contains(where: { $0.id == selectedID }) {
            selectedID = configs.first?.id ?? AppConfig.standard.id
        }
    }

    /// Accepts `Name.mccconfig/config.json`, `Name/config.json` and a bare `Name.json`.
    nonisolated static func manifestURLs(in directory: URL) -> [URL] {
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
                let manifest = entry.appendingPathComponent("config.json")
                if fileManager.fileExists(atPath: manifest.path) { results.append(manifest) }
            } else if entry.pathExtension.lowercased() == "json" {
                results.append(entry)
            }
        }
        return results
    }

    /// Ids key the registry, so a repeat silently replaces the earlier one and its button
    /// simply stops responding. Cheap to detect, baffling to debug.
    nonisolated static func duplicateIDProblems(in config: AppConfig) -> [String] {
        var problems: [String] = []
        var seenCommands: Set<String> = []

        for command in config.allCommands {
            if !seenCommands.insert(command.id).inserted {
                problems.append(
                    "\(config.name): two commands share the id '\(command.id)'. Only the last is used."
                )
            }

            var seenOptions: Set<String> = []
            for option in command.options where !seenOptions.insert(option.id).inserted {
                problems.append(
                    "\(config.name): command '\(command.id)' has two buttons with the id '\(option.id)'."
                )
            }
        }
        return problems
    }

    nonisolated static func load(at url: URL, isBuiltIn: Bool) throws -> AppConfig {
        let data = try Data(contentsOf: url)
        let isPackage = url.lastPathComponent == "config.json"
        let fallbackID = (isPackage ? url.deletingLastPathComponent() : url)
            .deletingPathExtension()
            .lastPathComponent
        var config = try ConfigCodec.decode(
            data,
            fallbackID: fallbackID,
            folderURL: isPackage ? url.deletingLastPathComponent() : nil,
            isBuiltIn: isBuiltIn
        )
        config.sourceURL = isPackage ? url.deletingLastPathComponent() : url
        return config
    }

    // MARK: - Writing

    /// Saves an edited config back to its folder. Built-in configs are never written to;
    /// the editor duplicates them first.
    public func save(_ config: AppConfig) throws {
        guard !config.isBuiltIn else { return }
        let folder =
            config.folderURL
            ?? AppPaths.configs
            .appendingPathComponent("\(config.name).mccconfig", isDirectory: true)
        AppPaths.ensure(folder)
        let data = try ConfigCodec.encode(config)
        try data.write(to: folder.appendingPathComponent("config.json"), options: .atomic)
        reload()
    }

    /// Copies a config into the user folder under a new id, so built-ins can be a
    /// starting point without being edited in place.
    @discardableResult
    public func duplicate(_ config: AppConfig) throws -> AppConfig {
        let baseName = config.name + " Copy"
        var name = baseName
        var suffix = 2
        while configs.contains(where: { $0.name == name }) {
            name = "\(baseName) \(suffix)"
            suffix += 1
        }

        var copy = config
        copy.name = name
        copy.id = Self.identifier(from: name)
        copy.isBuiltIn = false
        copy.folderURL = AppPaths.configs.appendingPathComponent(
            "\(name).mccconfig", isDirectory: true)
        try save(copy)
        return copy
    }

    public func delete(_ config: AppConfig) throws {
        // `folderURL` is nil for a bare `.json`, which used to make Delete a no-op.
        guard !config.isBuiltIn, let target = config.folderURL ?? config.sourceURL else { return }
        try FileManager.default.trashItem(at: target, resultingItemURL: nil)
        reload()
    }

    nonisolated static func identifier(from name: String) -> String {
        let slug = name.lowercased()
            .map { $0.isLetter || $0.isNumber ? String($0) : "-" }
            .joined()
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
        return slug.isEmpty ? UUID().uuidString : slug
    }

    // MARK: - Importing

    /// Copies a `.mccconfig` folder or `.json` file chosen by the user into the app's
    /// own folder. This is how importing works under the sandbox, where the app cannot
    /// read arbitrary locations on its own.
    public func importConfig(from source: URL) throws {
        try AppPaths.importItem(from: source, into: AppPaths.configs)
        reload()
    }

    public func revealFolder() {
        NSWorkspace.shared.selectFile(
            nil, inFileViewerRootedAtPath: AppPaths.ensure(AppPaths.configs).path)
    }

    // MARK: - Authoring

    private func installStarterConfigIfNeeded() {
        let directory = AppPaths.configs
        guard !FileManager.default.fileExists(atPath: directory.path) else { return }
        AppPaths.ensure(directory)
        try? ConfigAuthoring.readme.data(using: .utf8)?
            .write(to: directory.appendingPathComponent("README.md"))
    }
}
