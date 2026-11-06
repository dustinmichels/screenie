import Foundation
import UniformTypeIdentifiers

/// Finds screenshots in one folder.
///
/// Primary source is Spotlight (`NSMetadataQuery` on `kMDItemIsScreenCapture`). Because
/// Spotlight may be disabled or lag seconds behind a new file, a kqueue `DispatchSource` on
/// the folder also rescans its direct children on every entry add/remove/rename, keeping
/// files that carry the `kMDItemIsScreenCapture` xattr. Both sources are merged; the scan is
/// authoritative for direct children, the query adds anything deeper. Neither costs CPU idle.
/// Screen recordings are left out (see `isRecording`).
///
/// Main-thread only: `NSMetadataQuery` runs on the run loop it was started from.
final class ScreenshotWatcher {
    let folder: URL

    /// Maximum number of items kept; only the newest are read from each source.
    let limit: Int

    /// Called on the main thread with the newest `limit` items, newest first, whenever the
    /// merged list changes.
    var onChange: (([Screenshot]) -> Void)?

    private(set) var items: [Screenshot] = []

    /// True while the folder can't be listed for lack of permission: a denied (or not yet
    /// answered) Desktop/Documents/Downloads privacy prompt, or POSIX permissions.
    private(set) var isAccessDenied = false

    /// Called on the main thread when `isAccessDenied` changes.
    var onAccessChange: ((Bool) -> Void)?

    private let query = NSMetadataQuery()
    /// `folder.path` plus a trailing slash, for the in-scope check on query results.
    private let folderPrefix: String
    private var observers: [NSObjectProtocol] = []
    private var folderSource: DispatchSourceFileSystemObject?
    private var followUpScan: DispatchWorkItem?
    private var queryItems: [Screenshot] = []
    private var scanItems: [Screenshot] = []

    private static let screenCaptureXattr = "com.apple.metadata:kMDItemIsScreenCapture"

    init(folder: URL, limit: Int = 50) {
        self.folder = folder
        self.limit = limit
        folderPrefix = folder.path.hasSuffix("/") ? folder.path : folder.path + "/"
        query.predicate = NSPredicate(format: "kMDItemIsScreenCapture == 1")
        query.searchScopes = [folder]
        query.sortDescriptors = [NSSortDescriptor(key: "kMDItemContentCreationDate", ascending: false)]

        // The query keeps its results sorted and current, so both notifications rebuild
        // from it; the update's added/removed/changed userInfo is not needed.
        for name in [Notification.Name.NSMetadataQueryDidFinishGathering, .NSMetadataQueryDidUpdate] {
            observers.append(NotificationCenter.default.addObserver(
                forName: name, object: query, queue: .main
            ) { [weak self] _ in self?.reloadQuery() })
        }
    }

    deinit {
        stop()
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    func start() {
        query.start()
        watchFolder()
        rescanFolder()
    }

    func stop() {
        query.stop()
        folderSource?.cancel()
        folderSource = nil
        followUpScan?.cancel()
        followUpScan = nil
    }

    /// Drops `url` from both sources and publishes now, for files the app itself removed;
    /// the directory event or Spotlight update that follows then changes nothing.
    func remove(_ url: URL) {
        queryItems.removeAll { $0.url.path == url.path }
        scanItems.removeAll { $0.url.path == url.path }
        publish()
    }

    /// Retries a folder that couldn't be read, e.g. after the user allowed access in System
    /// Settings. No-op while access works.
    func retryAccess() {
        guard isAccessDenied else { return }
        watchFolder()
        rescanFolder()
    }

    // MARK: Spotlight

    private func reloadQuery() {
        query.disableUpdates()
        defer { query.enableUpdates() }

        // Read lazily so skipped dot-files don't eat into the limit. Spotlight ignores a scope
        // it can't read (privacy denial, missing folder) and searches the whole disk instead,
        // so results outside `folder` are dropped.
        queryItems = Array((0..<query.resultCount).lazy.compactMap { index -> Screenshot? in
            guard let result = self.query.result(at: index) as? NSMetadataItem,
                  let path = result.value(forAttribute: NSMetadataItemPathKey) as? String,
                  path.hasPrefix(self.folderPrefix)
            else { return nil }
            let url = URL(fileURLWithPath: path)
            guard !Self.isTemporary(url), !Self.isRecording(url) else { return nil }
            let createdAt = result.value(forAttribute: "kMDItemContentCreationDate") as? Date ?? .distantPast
            return Screenshot(url: url, createdAt: createdAt)
        }.prefix(limit))
        publish()
    }

    // MARK: Folder fallback

    private func watchFolder() {
        guard folderSource == nil else { return }
        let fd = open(folder.path, O_EVTONLY)
        guard fd >= 0 else { return }
        // `.write` on a directory fires when entries are added, removed, or renamed.
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: .write, queue: .main)
        source.setEventHandler { [weak self] in self?.folderDidChange() }
        source.setCancelHandler { close(fd) }
        source.resume()
        folderSource = source
    }

    /// Rescans now, then once more shortly after the last event: copy-style writers create the
    /// file before setting its xattrs, which fires no further directory event.
    private func folderDidChange() {
        rescanFolder()
        followUpScan?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.rescanFolder() }
        followUpScan = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: work)
    }

    private func rescanFolder() {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .creationDateKey]
        // The first listing of a TCC-protected folder (Desktop, Documents, Downloads) shows the
        // privacy prompt; a denial then fails with `fileReadNoPermission` (POSIX EPERM).
        let contents: [URL]
        do {
            contents = try FileManager.default.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: Array(keys), options: .skipsHiddenFiles
            )
            setAccessDenied(false)
        } catch {
            setAccessDenied((error as? CocoaError)?.code == .fileReadNoPermission)
            contents = []
        }
        let found = contents.compactMap { url -> Screenshot? in
            guard let values = try? url.resourceValues(forKeys: keys),
                  values.isRegularFile == true,
                  !Self.isRecording(url),
                  Self.isScreenCapture(url)
            else { return nil }
            return Screenshot(url: url, createdAt: values.creationDate ?? .distantPast)
        }
        scanItems = Array(found.sorted { $0.createdAt > $1.createdAt }.prefix(limit))
        publish()
    }

    private func setAccessDenied(_ denied: Bool) {
        guard denied != isAccessDenied else { return }
        isAccessDenied = denied
        onAccessChange?(denied)
    }

    /// macOS writes `.Screenshot …` first and renames it once the capture is finished.
    private static func isTemporary(_ url: URL) -> Bool {
        url.lastPathComponent.hasPrefix(".")
    }

    /// Screen recordings (`.mov` from ⌘⇧5) are deliberately not listed: thumbnails, copy, and the
    /// popover are built for still images. Decided by file extension, so it costs no file I/O.
    private static func isRecording(_ url: URL) -> Bool {
        UTType(filenameExtension: url.pathExtension)?.conforms(to: .audiovisualContent) ?? false
    }

    /// Reads the bplist-encoded boolean macOS stores in the `kMDItemIsScreenCapture` xattr.
    private static func isScreenCapture(_ url: URL) -> Bool {
        url.withUnsafeFileSystemRepresentation { path -> Bool in
            guard let path else { return false }
            let size = getxattr(path, screenCaptureXattr, nil, 0, 0, 0)
            guard size > 0 else { return false }
            var buffer = [UInt8](repeating: 0, count: size)
            guard getxattr(path, screenCaptureXattr, &buffer, size, 0, 0) == size else { return false }
            let value = try? PropertyListSerialization.propertyList(from: Data(buffer), format: nil)
            return value as? Bool == true
        }
    }

    // MARK: Merge

    private func publish() {
        // Prefer Spotlight's item (and its content creation date) where both sources agree.
        let fromQuery = Dictionary(queryItems.map { ($0.url.path, $0) }, uniquingKeysWith: { first, _ in first })
        var merged = scanItems.map { fromQuery[$0.url.path] ?? $0 }
        merged += queryItems.filter { $0.url.deletingLastPathComponent().path != folder.path }
        merged.sort { $0.createdAt > $1.createdAt }
        let items = Array(merged.prefix(limit))

        guard items != self.items else { return }
        self.items = items
        onChange?(items)
    }
}
