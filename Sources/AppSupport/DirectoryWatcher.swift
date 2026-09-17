import Foundation

/// Calls back when anything in a directory changes, with edits collapsed into one event.
///
/// Two mechanisms, because neither is sufficient alone. A vnode source on the directory
/// reacts instantly, but only to *entry* changes — adding, removing or renaming a file.
/// An editor that writes into an existing file in place never touches the directory, so
/// that source stays silent; a cheap content fingerprint, polled, catches those.
@MainActor
public final class DirectoryWatcher {

    private var source: DispatchSourceFileSystemObject?
    private var pending: DispatchWorkItem?
    private var pollTimer: Timer?
    private var lastFingerprint = ""

    private let debounce: TimeInterval
    private let pollInterval: TimeInterval

    public init(debounce: TimeInterval = 0.3, pollInterval: TimeInterval = 2) {
        self.debounce = debounce
        self.pollInterval = pollInterval
    }

    deinit {
        source?.cancel()
        pollTimer?.invalidate()
    }

    public func start(watching url: URL, onChange: @escaping @MainActor () -> Void) {
        stop()
        AppPaths.ensure(url)
        lastFingerprint = Self.fingerprint(of: url)

        startVnodeSource(url: url, onChange: onChange)

        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) {
            [weak self] _ in
            MainActor.assumeIsolated {
                self?.notifyIfChanged(url: url, onChange: onChange)
            }
        }
    }

    public func stop() {
        pending?.cancel()
        pending = nil
        source?.cancel()
        source = nil
        pollTimer?.invalidate()
        pollTimer = nil
    }

    // MARK: - Mechanisms

    private func startVnodeSource(url: URL, onChange: @escaping @MainActor () -> Void) {
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .rename, .delete, .attrib],
            queue: .main
        )
        let debounce = self.debounce
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                // Editors save in bursts; collapse them into one check.
                self.pending?.cancel()
                let item = DispatchWorkItem {
                    MainActor.assumeIsolated { self.notifyIfChanged(url: url, onChange: onChange) }
                }
                self.pending = item
                DispatchQueue.main.asyncAfter(deadline: .now() + debounce, execute: item)
            }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        self.source = source
    }

    /// Both mechanisms funnel through here, so an unchanged directory never triggers a
    /// reload no matter how many times the OS reports activity.
    private func notifyIfChanged(url: URL, onChange: @MainActor () -> Void) {
        let current = Self.fingerprint(of: url)
        guard current != lastFingerprint else { return }
        lastFingerprint = current
        onChange()
    }

    /// Name, size and modification date of every file one level down — enough to notice
    /// an in-place save, cheap enough to run every couple of seconds on a small folder.
    nonisolated static func fingerprint(of url: URL) -> String {
        let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
        let fileManager = FileManager.default

        func entries(of directory: URL, depth: Int) -> [String] {
            guard depth >= 0,
                let contents = try? fileManager.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: keys,
                    options: [.skipsHiddenFiles]
                )
            else { return [] }

            return contents.flatMap { entry -> [String] in
                let values = try? entry.resourceValues(forKeys: Set(keys))
                if values?.isDirectory == true {
                    return entries(of: entry, depth: depth - 1)
                }
                let size = values?.fileSize ?? 0
                let stamp = values?.contentModificationDate?.timeIntervalSince1970 ?? 0
                return ["\(entry.path):\(size):\(stamp)"]
            }
        }

        return entries(of: url, depth: 1).sorted().joined(separator: "|")
    }
}
