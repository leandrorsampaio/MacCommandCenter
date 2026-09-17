import Foundation

/// Calls back when anything in a directory changes, with edits collapsed into one event.
///
/// Used by both catalogs so saving a file re-skins or re-configures the open window. An
/// editor writes in bursts, hence the debounce.
@MainActor
public final class DirectoryWatcher {

    private var source: DispatchSourceFileSystemObject?
    private var pending: DispatchWorkItem?
    private let debounce: TimeInterval

    public init(debounce: TimeInterval = 0.3) {
        self.debounce = debounce
    }

    deinit {
        source?.cancel()
    }

    public func start(watching url: URL, onChange: @escaping @MainActor () -> Void) {
        stop()
        AppPaths.ensure(url)

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
                self.pending?.cancel()
                let item = DispatchWorkItem { MainActor.assumeIsolated { onChange() } }
                self.pending = item
                DispatchQueue.main.asyncAfter(deadline: .now() + debounce, execute: item)
            }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        self.source = source
    }

    public func stop() {
        pending?.cancel()
        pending = nil
        source?.cancel()
        source = nil
    }
}
