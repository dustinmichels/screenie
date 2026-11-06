import Foundation

/// Where macOS saves screenshots, as configured in ⌘⇧5 → Options → Save to.
enum ScreenshotLocation {
    static let defaultsDomain = "com.apple.screencapture"
    static let locationKey = "location"

    /// Raw `location` value from the screencapture defaults domain, or nil when unset/empty.
    static func configuredPath() -> String? {
        guard let path = UserDefaults(suiteName: defaultsDomain)?.string(forKey: locationKey),
              !path.isEmpty else { return nil }
        return path
    }

    /// Configured path, falling back to `~/Desktop` (the macOS default) when the key is unset.
    static func path() -> String {
        configuredPath() ?? "~/Desktop"
    }

    /// Screenshot folder as an absolute, standardized, symlink-resolved directory URL.
    static func url() -> URL {
        let expanded = (path() as NSString).expandingTildeInPath
        return URL(fileURLWithPath: expanded, isDirectory: true)
            .standardizedFileURL
            .resolvingSymlinksInPath()
    }
}
