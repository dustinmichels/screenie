import AppKit
import Observation

/// App-wide state. Owns the screenshot list and unseen flag (see plan sections 4–5).
@Observable
final class ScreenshotStore {
    /// True when the newest screenshot was created after `lastSeenDate`. Derived, so it also
    /// clears if that screenshot disappears; set `lastSeenDate` to clear it.
    private(set) var hasUnseen = false

    /// Creation date of the newest screenshot the user has seen, persisted in `UserDefaults` so
    /// screenshots taken while the app wasn't running still show the dot after launch. Raising it
    /// (e.g. to the newest screenshot's `createdAt` when the popover opens) clears `hasUnseen`.
    var lastSeenDate: Date {
        didSet {
            UserDefaults.standard.set(lastSeenDate, forKey: Self.lastSeenDateKey)
            updateUnseen()
        }
    }

    /// Folder macOS currently saves screenshots to. Changing it replaces the watcher.
    private(set) var folderURL: URL {
        didSet { startWatching() }
    }

    /// Screenshots in `folderURL`, newest first. Thumbnails of items that leave the list
    /// (deleted, moved, renamed, or pushed past the cap) are dropped from `thumbnails`.
    private(set) var screenshots: [Screenshot] = [] {
        didSet {
            let current = Set(screenshots.map(\.url))
            for shot in oldValue where !current.contains(shot.url) { thumbnails.remove(shot.url) }
            updateUnseen()
        }
    }

    /// True while `folderURL` can't be read (privacy prompt denied, or no POSIX permission).
    /// The popover's empty state explains how to allow access; `refreshFolder()` retries.
    private(set) var isFolderAccessDenied = false

    /// Thumbnails for `screenshots`, shared by all thumbnail views.
    @ObservationIgnored let thumbnails = ThumbnailCache()

    @ObservationIgnored private var activeObserver: NSObjectProtocol?
    @ObservationIgnored private var watcher: ScreenshotWatcher?

    private static let lastSeenDateKey = "lastSeenDate"

    init() {
        // First launch: treat everything already on disk as seen.
        let defaults = UserDefaults.standard
        if let saved = defaults.object(forKey: Self.lastSeenDateKey) as? Date {
            lastSeenDate = saved
        } else {
            let now = Date()
            defaults.set(now, forKey: Self.lastSeenDateKey)
            lastSeenDate = now
        }
        folderURL = ScreenshotLocation.url()
        startWatching()
        activeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.refreshFolder() }
    }

    deinit {
        if let activeObserver { NotificationCenter.default.removeObserver(activeObserver) }
    }

    /// Re-reads the screenshot location; the user may change it in ⌘⇧5 → Options.
    /// Only assigns on change so observers of `folderURL` fire only on a real move. An unchanged
    /// folder that couldn't be read is retried, in case access was granted meanwhile.
    func refreshFolder() {
        let url = ScreenshotLocation.url()
        if url != folderURL { folderURL = url } else { watcher?.retryAccess() }
    }

    /// Clears the dot: marks everything currently listed as seen. Uses the newest listed date
    /// rather than `Date()`, so a screenshot still in Spotlight/scan lag isn't silently marked
    /// seen. Only ever raises `lastSeenDate`.
    func markSeen() {
        if let newest = screenshots.first?.createdAt, newest > lastSeenDate { lastSeenDate = newest }
    }

    /// Moves the screenshot to the Trash and drops it from the list right away, without
    /// waiting for the folder scan or Spotlight to notice. Throws if the move fails (the list
    /// is then left as is).
    func trash(_ shot: Screenshot) throws {
        try FileManager.default.trashItem(at: shot.url, resultingItemURL: nil)
        watcher?.remove(shot.url)
    }

    /// Replaces the watcher with a fresh one for `folderURL`. The old watcher is stopped and
    /// released first (its callbacks hold only weak references, so nothing late reaches the
    /// store), and the list is cleared, since an empty new folder never publishes.
    private func startWatching() {
        watcher?.stop()
        watcher = nil
        screenshots = []
        isFolderAccessDenied = false
        let watcher = ScreenshotWatcher(folder: folderURL)
        watcher.onChange = { [weak self] items in self?.screenshots = items }
        watcher.onAccessChange = { [weak self] denied in self?.isFolderAccessDenied = denied }
        self.watcher = watcher
        watcher.start()
    }

    private func updateUnseen() {
        let unseen = (screenshots.first?.createdAt ?? .distantPast) > lastSeenDate
        if unseen != hasUnseen { hasUnseen = unseen }
    }
}
