import AppKit
import Observation

/// Asks GitHub for the latest release and offers to install it if it's newer. There's no
/// in-place updater: Download fetches the release's disk image, opens it, and quits, so the user
/// can drag the new app over the old one in Applications.
///
/// Automatic checks run at launch and whenever the popover opens, but at most once a day counted
/// from the last check that reached GitHub, so no timer is needed. They stay silent unless a newer
/// version exists. "Check for Updates…" also reports being up to date and failures.
@MainActor
@Observable
final class UpdateChecker {
    /// True while checking, showing the update prompt, or downloading; disables the footer button.
    private(set) var isBusy = false

    @ObservationIgnored private var lastCheckDate: Date?

    private static let latestReleaseURL =
        URL(string: "https://api.github.com/repos/dustinmichels/screenie/releases/latest")!
    private static let checkInterval: TimeInterval = 24 * 60 * 60
    nonisolated private static let diskImageName = "Screenie.dmg"

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    init() {
        Task { await checkIfDue() }
    }

    /// Automatic check: skipped if GitHub was reached within the last day.
    func checkIfDue() async {
        if let lastCheckDate, Date().timeIntervalSince(lastCheckDate) < Self.checkInterval { return }
        await check(userInitiated: false)
    }

    /// "Check for Updates…": always checks, and says so when there's nothing new or it failed.
    func checkNow() async {
        await check(userInitiated: true)
    }

    private func check(userInitiated: Bool) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }

        let release: Release
        do {
            release = try await Self.fetchLatestRelease()
        } catch {
            if userInitiated {
                Self.showMessage("Couldn\u{2019}t check for updates", error.localizedDescription)
            }
            return
        }
        lastCheckDate = Date()

        guard Self.isVersion(release.version, newerThan: Self.currentVersion) else {
            if userInitiated {
                Self.showMessage(
                    "Screenie is up to date",
                    "Version \(Self.currentVersion) is the newest version."
                )
            }
            return
        }
        switch Self.askToUpdate(release) {
        case .alertFirstButtonReturn: await download(release)
        case .alertThirdButtonReturn: NSWorkspace.shared.open(release.htmlURL)
        default: break
        }
    }

    /// Downloads the release's disk image to a temporary folder, opens it, and quits so the app
    /// in Applications can be replaced. Falls back to the release page if that fails.
    private func download(_ release: Release) async {
        guard let url = release.diskImageURL else {
            NSWorkspace.shared.open(release.htmlURL)
            return
        }
        do {
            let (downloaded, response) = try await URLSession.shared.download(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            let folder = FileManager.default.temporaryDirectory
                .appending(path: "Screenie update", directoryHint: .isDirectory)
            try? FileManager.default.removeItem(at: folder)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let diskImage = folder.appending(path: "Screenie \(release.version).dmg")
            try FileManager.default.moveItem(at: downloaded, to: diskImage)
            guard NSWorkspace.shared.open(diskImage) else { throw CocoaError(.fileReadUnknown) }
            NSApp.terminate(nil)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn\u{2019}t download Screenie \(release.version)"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "Open Release Page")
            alert.addButton(withTitle: "Cancel")
            if Self.run(alert) == .alertFirstButtonReturn { NSWorkspace.shared.open(release.htmlURL) }
        }
    }

    /// Buttons: Download (Return), Later (Escape), Release Notes.
    private static func askToUpdate(_ release: Release) -> NSApplication.ModalResponse {
        let alert = NSAlert()
        alert.messageText = "Screenie \(release.version) is available"
        alert.informativeText = """
            You have version \(currentVersion). Download opens the new version\u{2019}s disk image \
            and quits Screenie. Drag Screenie onto Applications, choose Replace, then open it again.
            """
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Later").keyEquivalent = "\u{1b}"
        alert.addButton(withTitle: "Release Notes")
        return run(alert)
    }

    private static func showMessage(_ message: String, _ information: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = information
        run(alert)
    }

    /// `LSUIElement` apps aren't active by default; activate so the alert comes up in front.
    @discardableResult
    private static func run(_ alert: NSAlert) -> NSApplication.ModalResponse {
        NSApp.activate()
        return alert.runModal()
    }

    private static func fetchLatestRelease() async throws -> Release {
        var request = URLRequest(url: latestReleaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(Release.self, from: data)
    }

    /// Compares dotted versions part by part as numbers ("0.10.0" is newer than "0.9.1");
    /// missing parts count as 0.
    static func isVersion(_ version: String, newerThan other: String) -> Bool {
        let a = version.split(separator: ".").map { Int($0) ?? 0 }
        let b = other.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    /// The fields of GitHub's release JSON that are used. `/releases/latest` skips drafts and
    /// prereleases.
    private struct Release: Decodable {
        let tagName: String
        let htmlURL: URL
        let assets: [Asset]

        struct Asset: Decodable {
            let name: String
            let browserDownloadURL: URL

            enum CodingKeys: String, CodingKey {
                case name
                case browserDownloadURL = "browser_download_url"
            }
        }

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
            case assets
        }

        /// Tags are `v<MARKETING_VERSION>` (see scripts/release.sh).
        var version: String { tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName }

        var diskImageURL: URL? {
            assets.first { $0.name == UpdateChecker.diskImageName }?.browserDownloadURL
        }
    }
}
