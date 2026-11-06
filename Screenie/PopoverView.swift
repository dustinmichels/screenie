import SwiftUI

/// Popover content: a grid of the newest screenshots (plan section 7).
struct PopoverView: View {
    let store: ScreenshotStore

    /// Whether the popover window is showing. `MenuBarExtra` fires `onAppear`/`onDisappear`
    /// on every open/close. The grid only exists while open: the window outlives a close and
    /// doesn't update while hidden, and cells of screenshots that left the list while it was
    /// hidden were never torn down on reopen, leaking each one with its thumbnail.
    @State private var isOpen = false

    /// Newest screenshot at the time the popover was opened from the dot; cleared on close.
    @State private var highlighted: Screenshot.ID?

    private static let columns = [GridItem](
        repeating: GridItem(.fixed(Thumbnail.pointSize), spacing: 12), count: 2
    )

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if store.screenshots.isEmpty {
                    emptyState
                } else if isOpen {
                    // Built fresh on every open, so it starts scrolled to the top.
                    ScrollView {
                        // `screenshots` is already sorted newest first.
                        LazyVGrid(columns: Self.columns, spacing: 12) {
                            ForEach(store.screenshots) { shot in
                                ScreenshotCell(
                                    shot: shot, store: store,
                                    isHighlighted: shot.id == highlighted
                                )
                            }
                        }
                        .padding(12)
                    }
                }
            }
            .frame(maxHeight: .infinity)
            Divider()
            footer
        }
        .frame(width: 360, height: 480)
        .onAppear {
            isOpen = true
            store.refreshFolder()
            // Opened from the dot: highlight the newest screenshot (the grid starts at the top).
            if store.hasUnseen, let newest = store.screenshots.first { highlighted = newest.id }
            store.markSeen()
        }
        .onDisappear {
            isOpen = false
            highlighted = nil
        }
        // The window outlives a close, so only screenshots arriving while it's open count as seen.
        .onChange(of: store.screenshots.first?.createdAt) {
            if isOpen { store.markSeen() }
        }
    }

    /// App-level controls. `LSUIElement` apps have no app menu, so Quit lives here.
    private var footer: some View {
        HStack {
            LaunchAtLoginToggle()
            Spacer()
            Button("Quit Screenie") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    /// Shown until the watched folder contains a screenshot; names the folder so a wrong
    /// ⌘⇧5 → Options → Save to location is easy to spot. If the folder can't be read (the
    /// Desktop/Documents/Downloads privacy prompt was denied), says so and links to the setting.
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: store.isFolderAccessDenied ? "lock" : "camera.viewfinder")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text(store.isFolderAccessDenied ? "Can't read the screenshot folder" : "No screenshots yet")
                .font(.headline)
            Text((store.folderURL.path as NSString).abbreviatingWithTildeInPath)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
            if store.isFolderAccessDenied {
                Text("Allow Screenie in System Settings → Privacy & Security → Files and Folders.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Privacy Settings") { NSWorkspace.shared.open(Self.filesAndFoldersSettings) }
                    .controlSize(.small)
                    .padding(.top, 4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private static let filesAndFoldersSettings = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders"
    )!
}

/// One grid item: the thumbnail, fitted into a fixed-size cell, with its age underneath.
/// Actions: double-click opens, hover shows copy/reveal/trash buttons, right-click menu has all four.
private struct ScreenshotCell: View {
    let shot: Screenshot
    let store: ScreenshotStore
    let isHighlighted: Bool

    @State private var isHovering = false

    /// Briefly true after a successful copy, so the copy button can confirm it.
    @State private var didCopy = false

    var body: some View {
        VStack(spacing: 4) {
            ThumbnailView(url: shot.url, cache: store.thumbnails)
                .frame(width: Thumbnail.pointSize, height: Thumbnail.pointSize * 0.625)
                .overlay(alignment: .topTrailing) {
                    if isHovering { hoverButtons.padding(4) }
                }
            // Refreshes on minute boundaries, and only while the cell is on screen.
            TimelineView(.everyMinute) { context in
                Text(Self.age(of: shot.createdAt, now: context.date))
                    .font(.caption)
                    .foregroundStyle(isHighlighted ? Color.accentColor : .secondary)
            }
        }
        // Drawn in the grid's 12 pt gutter so the cell layout doesn't shift.
        .background {
            if isHighlighted {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.12))
                    .strokeBorder(Color.accentColor, lineWidth: 2)
                    .padding(-5)
            }
        }
        .help(shot.url.lastPathComponent)
        // Hit-test the whole cell, not just the drawn thumbnail and text.
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture(count: 2) { ScreenshotActions.open(shot.url) }
        // Drag out as a file; the provider reads the file only when a drop target asks.
        .onDrag { NSItemProvider(contentsOf: shot.url) ?? NSItemProvider() }
        .contextMenu {
            Button("Open") { ScreenshotActions.open(shot.url) }
            Button("Show in Finder") { ScreenshotActions.revealInFinder(shot.url) }
            Button("Copy Image") { copy() }
            Divider()
            Button("Move to Trash") { trash() }
        }
    }

    private var hoverButtons: some View {
        HStack(spacing: 2) {
            iconButton(didCopy ? "checkmark" : "doc.on.doc", help: "Copy Image", action: copy)
            iconButton("folder", help: "Show in Finder") { ScreenshotActions.revealInFinder(shot.url) }
            iconButton("trash", help: "Move to Trash", action: trash)
        }
        .padding(2)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
    }

    private func iconButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .frame(width: 20, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(help)
    }

    private func copy() {
        guard ScreenshotActions.copyImage(shot.url) else { return NSSound.beep() }
        didCopy = true
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            didCopy = false
        }
    }

    private func trash() {
        do { try store.trash(shot) } catch { NSSound.beep() }
    }

    private static let ageFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .short
        return formatter
    }()

    /// "2 min. ago", "yesterday". Clamped so clock skew never yields "in 3 sec.".
    static func age(of date: Date, now: Date) -> String {
        ageFormatter.localizedString(for: min(date, now), relativeTo: now)
    }
}
