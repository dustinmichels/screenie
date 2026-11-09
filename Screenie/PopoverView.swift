import SwiftUI

/// Popover content: a grid of the newest screenshots (plan section 7).
struct PopoverView: View {
    let store: ScreenshotStore
    let updater: UpdateChecker

    /// Whether the popover window is showing. `MenuBarExtra` fires `onAppear`/`onDisappear`
    /// on every open/close. The grid only exists while open: the window outlives a close and
    /// doesn't update while hidden, and cells of screenshots that left the list while it was
    /// hidden were never torn down on reopen, leaking each one with its thumbnail.
    @State private var isOpen = false

    /// Newest screenshot at the time the popover was opened from the dot; cleared on close.
    @State private var highlighted: Screenshot.ID?

    /// Screenshot waiting on the Move to Trash confirmation; non-nil shows the dialog.
    @State private var pendingTrash: Screenshot?

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
                                    isHighlighted: shot.id == highlighted,
                                    requestTrash: { pendingTrash = shot }
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
        // Return confirms (default action); Escape cancels.
        .confirmationDialog(
            "Move to Trash?",
            isPresented: Binding(get: { pendingTrash != nil }, set: { if !$0 { pendingTrash = nil } }),
            presenting: pendingTrash
        ) { shot in
            Button("Move to Trash") {
                do { try store.trash(shot) } catch { NSSound.beep() }
            }
            .keyboardShortcut(.defaultAction)
            Button("Cancel", role: .cancel) {}
        } message: { shot in
            Text("\u{201C}\(shot.url.lastPathComponent)\u{201D} will be moved to the Trash.")
        }
        .onAppear {
            isOpen = true
            store.refreshFolder()
            // Opened from the dot: highlight the newest screenshot (the grid starts at the top).
            if store.hasUnseen, let newest = store.screenshots.first { highlighted = newest.id }
            store.markSeen()
            Task { await updater.checkIfDue() }
        }
        .onDisappear {
            isOpen = false
            highlighted = nil
            pendingTrash = nil
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
            Button("Check for Updates\u{2026}") { Task { await updater.checkNow() } }
                .disabled(updater.isBusy)
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
/// Actions: double-click opens; hover shows copy/share/trash buttons and a centered reveal-in-Finder
/// button, and while the pointer is on one of them the age line names its action; right-click menu
/// has all of them except Share, plus Open.
private struct ScreenshotCell: View {
    let shot: Screenshot
    let store: ScreenshotStore
    let isHighlighted: Bool
    /// Asks `PopoverView` to confirm, then trash, this screenshot.
    let requestTrash: () -> Void

    @State private var isHovering = false

    /// True while the share picker opened from the hover button is up. Keeps the hover buttons
    /// alive after the pointer moves onto the menu: removing its anchor view closes the menu.
    @State private var isSharing = false

    /// Briefly true after a successful copy, so the copy button can confirm it.
    @State private var didCopy = false

    /// Hover button under the pointer; its title replaces the age line. Shown in-view rather than
    /// with `.help`: AppKit tooltips only appear while the app is active, and an `LSUIElement` app
    /// usually isn't while the popover is open.
    @State private var hoveredAction: HoverAction?

    /// AppKit view the share picker anchors to.
    @State private var shareButtonAnchor = AnchorBox()

    var body: some View {
        VStack(spacing: 4) {
            ThumbnailView(url: shot.url, cache: store.thumbnails)
                .frame(width: Thumbnail.pointSize, height: Thumbnail.pointSize * 0.625)
                .overlay(alignment: .topTrailing) {
                    if isHovering || isSharing { hoverButtons.padding(4) }
                }
                .overlay {
                    if isHovering || isSharing { revealButton }
                }
            if let hoveredAction {
                // Tinted like the hovered button's fill, so the two read as a pair.
                Text(hoveredAction.title(didCopy: didCopy))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(hoveredAction.tint)
                    // Negative padding grows the pill past the text without changing the row height.
                    .background {
                        Capsule().fill(hoveredAction.tint.opacity(0.12)).padding(.horizontal, -6).padding(.vertical, -1)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
            } else {
                // Refreshes on minute boundaries, and only while the cell is on screen.
                TimelineView(.everyMinute) { context in
                    Text(Self.age(of: shot.createdAt, now: context.date))
                        .font(.caption)
                        .foregroundStyle(isHighlighted ? Color.accentColor : .secondary)
                }
            }
        }
        .animation(.easeOut(duration: 0.12), value: hoveredAction)
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
        // Hover buttons are removed with the cell's hover, which may skip their own exit callback.
        .onHover { isHovering = $0; if !$0 { hoveredAction = nil } }
        .onTapGesture(count: 2) { ScreenshotActions.open(shot.url) }
        // Drag out as a file; the provider reads the file only when a drop target asks.
        .onDrag { NSItemProvider(contentsOf: shot.url) ?? NSItemProvider() }
        .grabPointer()
        .contextMenu {
            Button("Open") { ScreenshotActions.open(shot.url) }
            Button("Show in Finder") { ScreenshotActions.revealInFinder(shot.url) }
            Button("Copy Image") { copy() }
            Divider()
            Button("Move to Trash…", action: requestTrash)
        }
    }

    private var hoverButtons: some View {
        HStack(spacing: 2) {
            iconButton(didCopy ? "checkmark" : "doc.on.doc", action: .copy, perform: copy)
            iconButton("square.and.arrow.up", action: .share, perform: share)
            .background(AnchorView(box: shareButtonAnchor))
            iconButton("trash", action: .trash, perform: requestTrash)
        }
        .padding(2)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
    }

    private var revealButton: some View {
        Button { ScreenshotActions.revealInFinder(shot.url) } label: {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 36, height: 36)
        }
        .buttonStyle(
            HoverFillButtonStyle(shape: Circle(), tint: HoverAction.reveal.tint, rest: AnyShapeStyle(.regularMaterial))
        )
        .describedOnHover(as: .reveal, in: $hoveredAction)
    }

    private func iconButton(_ symbol: String, action: HoverAction, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .frame(width: 20, height: 18)
        }
        // Inner radius of the 6 pt container minus its 2 pt padding.
        .buttonStyle(HoverFillButtonStyle(shape: RoundedRectangle(cornerRadius: 4), tint: action.tint))
        .describedOnHover(as: action, in: $hoveredAction)
    }

    private func copy() {
        guard ScreenshotActions.copyImage(shot.url) else { return NSSound.beep() }
        didCopy = true
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            didCopy = false
        }
    }

    private func share() {
        guard let view = shareButtonAnchor.view, view.window != nil else { return NSSound.beep() }
        isSharing = true
        ScreenshotActions.share(shot.url, from: view) { isSharing = false }
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

/// The cell's hover buttons, for naming the one under the pointer.
private enum HoverAction {
    case reveal, copy, share, trash

    func title(didCopy: Bool) -> String {
        switch self {
        case .reveal: "Show in Finder"
        case .copy: didCopy ? "Copied" : "Copy Image"
        case .share: "Share"
        case .trash: "Move to Trash"
        }
    }

    /// Fill of the button while hovered, and of its label.
    var tint: Color { self == .trash ? .red : .accentColor }
}

private extension View {
    /// Sets `hovered` to `action` while the pointer is over this view, and labels it for VoiceOver.
    func describedOnHover(as action: HoverAction, in hovered: Binding<HoverAction?>) -> some View {
        accessibilityLabel(action.title(didCopy: false))
            .onHover { inside in
                if inside {
                    hovered.wrappedValue = action
                } else if hovered.wrappedValue == action {
                    hovered.wrappedValue = nil
                }
            }
    }
}

/// Holds the `NSView` behind an `AnchorView`, for presenting AppKit UI relative to a SwiftUI view.
private final class AnchorBox {
    weak var view: NSView?
}

/// Invisible view that publishes its `NSView` to `box`.
private struct AnchorView: NSViewRepresentable {
    let box: AnchorBox

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        box.view = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        box.view = nsView
    }
}

/// Icon button that fills with `tint` and turns its icon white while hovered, so it reads as
/// clickable over the thumbnail. Shows the arrow pointer inside a `grabPointer()` cell.
private struct HoverFillButtonStyle<S: Shape>: ButtonStyle {
    let shape: S
    var tint: Color = .accentColor
    /// Background while not hovered.
    var rest = AnyShapeStyle(Color.clear)

    func makeBody(configuration: Configuration) -> some View {
        Fill(configuration: configuration, style: self)
    }

    private struct Fill: View {
        let configuration: ButtonStyleConfiguration
        let style: HoverFillButtonStyle
        @State private var isHovering = false

        var body: some View {
            configuration.label
                .foregroundStyle(isHovering ? Color.white : Color.primary)
                .background(isHovering ? AnyShapeStyle(style.tint) : style.rest, in: style.shape)
                .opacity(configuration.isPressed ? 0.7 : 1)
                .contentShape(style.shape)
                .onHover { isHovering = $0 }
                .animation(.easeOut(duration: 0.12), value: isHovering)
                .arrowPointer()
        }
    }
}

/// Open hand while hovering and closed hand while the mouse is down, signalling the view can be
/// dragged. Once a drag session starts, AppKit shows its own drag cursor.
private struct GrabPointer: ViewModifier {
    @GestureState private var isPressed = false

    func body(content: Content) -> some View {
        Group {
            if #available(macOS 15, *) {
                content.pointerStyle(isPressed ? .grabActive : .grabIdle)
            } else {
                // macOS 14 has no `pointerStyle`; set the cursor directly, buttons included.
                content
                    .onContinuousHover { phase in
                        switch phase {
                        case .active: (isPressed ? NSCursor.closedHand : .openHand).set()
                        case .ended: NSCursor.arrow.set()
                        }
                    }
                    .onChange(of: isPressed) { (isPressed ? NSCursor.closedHand : .openHand).set() }
            }
        }
        // Simultaneous, so `onDrag`, double-click, and buttons still work. The drag session
        // cancels this gesture when it starts, which resets `isPressed`.
        .simultaneousGesture(
            DragGesture(minimumDistance: 0).updating($isPressed) { _, pressed, _ in pressed = true }
        )
    }
}

private extension View {
    func grabPointer() -> some View { modifier(GrabPointer()) }

    /// Restores the standard arrow inside a `grabPointer()` view (macOS 15+).
    @ViewBuilder func arrowPointer() -> some View {
        if #available(macOS 15, *) {
            pointerStyle(.default)
        } else {
            self
        }
    }
}
